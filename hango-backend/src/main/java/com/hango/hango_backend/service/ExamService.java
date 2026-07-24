package com.hango.hango_backend.service;

import com.hango.hango_backend.dto.ExamResponseDTO;
import com.hango.hango_backend.dto.ExamAttemptRequestDTO;
import com.hango.hango_backend.dto.ExamAttemptResponseDTO;
import com.hango.hango_backend.dto.LearnerExamQuestionDTO;
import com.hango.hango_backend.dto.LearnerQuestionGroupDTO;
import com.hango.hango_backend.dto.LearnerQuestionOptionDTO;
import com.hango.hango_backend.entity.Exam;
import com.hango.hango_backend.entity.ExamAttempt;
import com.hango.hango_backend.entity.User;
import com.hango.hango_backend.entity.Question;
import com.hango.hango_backend.entity.QuestionOption;
import com.hango.hango_backend.repository.ExamAttemptRepository;
import com.hango.hango_backend.repository.ExamQuestionRepository;
import com.hango.hango_backend.repository.ExamRepository;
import com.hango.hango_backend.repository.UserRepository;
import com.hango.hango_backend.repository.QuestionRepository;
import com.fasterxml.jackson.databind.ObjectMapper;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.time.LocalDateTime;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.stream.Collectors;

@Service
@RequiredArgsConstructor
public class ExamService {

    private final ExamRepository examRepository;
    private final ExamQuestionRepository examQuestionRepository;
    private final ExamAttemptRepository examAttemptRepository;
    private final UserRepository userRepository;
    private final QuestionRepository questionRepository;
    private final ObjectMapper objectMapper = new ObjectMapper();

    public List<ExamResponseDTO> getAllExams(String status) {
        List<Exam> exams;
        if (status != null && !status.isEmpty() && !status.equalsIgnoreCase("All")) {
            exams = examRepository.findByDeletedAtIsNullAndStatus(status).stream()
                    .filter(e -> "PUBLISHED".equalsIgnoreCase(e.getStatus()))
                    .collect(Collectors.toList());
        } else {
            exams = examRepository.findByDeletedAtIsNullAndStatus("PUBLISHED");
        }

        return exams.stream().map(this::mapToDTO).collect(Collectors.toList());
    }

    private ExamResponseDTO mapToDTO(Exam exam) {
        int questionCount = examQuestionRepository.countByIdExamId(exam.getId());

        String learnerCountStr = "0";
        Long count = examAttemptRepository.countDistinctStudentsByExamId(exam.getId());
        if (count != null && count > 0) {
            learnerCountStr = count.toString();
        }

        return ExamResponseDTO.builder()
                .id(exam.getId())
                .title(exam.getTitle())
                .description(exam.getDescription())
                .status(exam.getStatus())
                .creatorName(exam.getCreatedBy() != null ? exam.getCreatedBy().getFullName() : "Unknown")
                .questionCount(questionCount)
                .durationMinutes(exam.getDurationMinutes())
                .rating(0.0)
                .learnerCountFormatted(learnerCountStr)
                .thumbnailUrl(exam.getThumbnailUrl())
                .rejectionReason(exam.getRejectionReason())
                .build();
    }

    public List<ExamAttemptResponseDTO> getMyExamAttempts(Long userId) {
        List<ExamAttempt> attempts = examAttemptRepository.findByStudentIdOrderByStartedAtDesc(userId);
        return mapToAttemptDTOList(attempts);
    }

    public List<ExamAttemptResponseDTO> getExamAttempts(Long examId, Long userId) {
        List<ExamAttempt> attempts = examAttemptRepository.findByExamIdAndStudentIdOrderByStartedAtDesc(examId, userId);
        return mapToAttemptDTOList(attempts);
    }

    private List<ExamAttemptResponseDTO> mapToAttemptDTOList(List<ExamAttempt> attempts) {
        return attempts.stream().map(attempt -> {
            int attemptNumber = examAttemptRepository.countByExamIdAndStudentIdAndStartedAtLessThanEqual(
                    attempt.getExam().getId(), attempt.getStudent().getId(), attempt.getStartedAt());
            return mapToAttemptDTO(attempt, attemptNumber);
        }).collect(Collectors.toList());
    }

    @Transactional
    public ExamAttemptResponseDTO saveExamAttempt(Long examId, Long userId, ExamAttemptRequestDTO request) {
        Exam exam = examRepository.findById(examId)
                .orElseThrow(() -> new RuntimeException("Exam not found"));

        User student = userRepository.findById(userId)
                .orElseThrow(() -> new RuntimeException("User not found"));

        int nextAttemptNumber = examAttemptRepository.countByExamIdAndStudentId(examId, userId) + 1;

        List<Question> examQuestions = questionRepository.findByExamIdOrderByQuestionOrder(examId);

        String answersJson = null;
        BigDecimal calculatedScore = BigDecimal.ZERO;
        try {
            if (request.getAnswers() != null) {
                List<Map<String, Object>> enrichedAnswers = enrichAnswers(request.getAnswers(), examQuestions);
                answersJson = objectMapper.writeValueAsString(enrichedAnswers);
                
                long correctCount = enrichedAnswers.stream()
                        .filter(a -> Boolean.TRUE.equals(a.get("isCorrect")))
                        .count();
                        
                if (examQuestions.size() > 0) {
                    calculatedScore = BigDecimal.valueOf(10.0 * correctCount / examQuestions.size());
                    calculatedScore = calculatedScore.setScale(2, RoundingMode.HALF_UP);
                }
            }
        } catch (Exception e) {
            answersJson = "{}";
        }

        ExamAttempt attempt = new ExamAttempt();
        attempt.setExam(exam);
        attempt.setStudent(student);
        attempt.setScore(calculatedScore);
        attempt.setAnswersJson(answersJson);
        attempt.setStartedAt(LocalDateTime.now().minusMinutes(exam.getDurationMinutes()));
        attempt.setSubmittedAt(LocalDateTime.now());

        ExamAttempt saved = examAttemptRepository.save(attempt);
        return mapToAttemptDTO(saved, nextAttemptNumber);
    }

    private List<Map<String, Object>> enrichAnswers(Map<String, Object> rawAnswers, List<Question> examQuestions) {
        return rawAnswers.entrySet().stream()
                .sorted((left, right) -> {
                    int leftKey = parseQuestionNumber(left.getKey());
                    int rightKey = parseQuestionNumber(right.getKey());
                    return Integer.compare(leftKey, rightKey);
                })
                .map(entry -> toAnswerRecord(entry.getKey(), entry.getValue(), examQuestions))
                .toList();
    }

    @SuppressWarnings("unchecked")
    private Map<String, Object> toAnswerRecord(String questionNumber, Object rawValue, List<Question> examQuestions) {
        Map<String, Object> record = new LinkedHashMap<>();
        int qIndex = parseQuestionNumber(questionNumber);
        record.put("questionId", Long.valueOf(qIndex));
        
        Question question = null;
        if (qIndex >= 0 && qIndex < examQuestions.size()) {
            question = examQuestions.get(qIndex);
        }

        String userAnswerText = null;
        boolean isCorrect = false;

        if (rawValue instanceof Map<?, ?> rawMap) {
            Object selected = rawMap.get("selectedOption");
            userAnswerText = selected == null ? null : selected.toString();
        } else {
            userAnswerText = rawValue == null ? null : rawValue.toString();
        }
        
        Integer correctOptIndex = null;
        if (question != null && userAnswerText != null) {
            try {
                int selectedOptIndex = Integer.parseInt(userAnswerText);
                List<QuestionOption> options = question.getOptions();
                if (selectedOptIndex >= 0 && selectedOptIndex < options.size()) {
                    isCorrect = Boolean.TRUE.equals(options.get(selectedOptIndex).getIsCorrect());
                }
                for (int i = 0; i < options.size(); i++) {
                    if (Boolean.TRUE.equals(options.get(i).getIsCorrect())) {
                        correctOptIndex = i;
                        break;
                    }
                }
            } catch (NumberFormatException e) {
            }
        }
        
        String skill = question != null && question.getSkillParam() != null ? question.getSkillParam().getParamValue() : "GENERAL";
        
        record.put("userAnswer", userAnswerText);
        record.put("isCorrect", isCorrect);
        record.put("correctAnswer", correctOptIndex);
        record.put("skill", normalizeSkill(skill));
        record.put("topic", normalizeSkill(skill));

        return record;
    }

    private int parseQuestionNumber(String key) {
        try {
            return Integer.parseInt(key);
        } catch (NumberFormatException e) {
            return 0;
        }
    }

    private String normalizeSkill(Object rawSkill) {
        if (rawSkill == null) {
            return null;
        }
        String skill = rawSkill.toString().trim();
        return skill.isBlank() ? null : skill;
    }

    private ExamAttemptResponseDTO mapToAttemptDTO(ExamAttempt attempt, int attemptNumber) {
        Map<String, Integer> answers = new java.util.HashMap<>();
        Map<String, Boolean> correctness = new java.util.HashMap<>();
        Map<String, Integer> correctAnswers = new java.util.HashMap<>();
        try {
            if (attempt.getAnswersJson() != null && !attempt.getAnswersJson().equals("{}")) {
                List<Map<String, Object>> enrichedList = objectMapper.readValue(attempt.getAnswersJson(), List.class);
                for (Map<String, Object> map : enrichedList) {
                    Object qId = map.get("questionId");
                    Object uAns = map.get("userAnswer");
                    Object isCorrectObj = map.get("isCorrect");
                    if (qId != null && uAns != null) {
                        try {
                            int qIndex = Integer.parseInt(qId.toString());
                            int ansIndex = Integer.parseInt(uAns.toString());
                            String indexStr = String.valueOf(qIndex + 1);
                            answers.put(indexStr, ansIndex);
                            if (isCorrectObj != null) {
                                correctness.put(indexStr, Boolean.parseBoolean(isCorrectObj.toString()));
                            }
                        } catch (NumberFormatException ex) {
                        }
                    }
                }
            }
            
            // Build correctAnswers map dynamically from DB so old attempts work too
            if (attempt.getExam() != null) {
                List<Question> questions = questionRepository.findByExamIdOrderByQuestionOrder(attempt.getExam().getId());
                for (int i = 0; i < questions.size(); i++) {
                    Question q = questions.get(i);
                    if (q != null && q.getOptions() != null) {
                        for (int j = 0; j < q.getOptions().size(); j++) {
                            if (Boolean.TRUE.equals(q.getOptions().get(j).getIsCorrect())) {
                                correctAnswers.put(String.valueOf(i + 1), j);
                                break;
                            }
                        }
                    }
                }
            }
        } catch (Exception e) {
        }

        String dateStr = "";
        if (attempt.getSubmittedAt() != null) {
            dateStr = attempt.getSubmittedAt().toString().replace("T", " ");
            if (dateStr.length() > 16) {
                dateStr = dateStr.substring(0, 16);
            }
        }

        boolean isPassed = attempt.getScore() != null && attempt.getScore().doubleValue() >= 5.0;

        return ExamAttemptResponseDTO.builder()
                .id(attempt.getId())
                .examId(attempt.getExam().getId())
                .examTitle(attempt.getExam().getTitle())
                .score(attempt.getScore())
                .attemptNumber(attemptNumber)
                .date(dateStr)
                .status(isPassed ? "PASSED" : "FAILED")
                .answers(answers)
                .correctness(correctness)
                .correctAnswers(correctAnswers)
                .build();
    }
    
    public List<LearnerExamQuestionDTO> getExamQuestions(Long examId) {
        List<Question> questions = questionRepository.findByExamIdOrderByQuestionOrder(examId);
        
        return questions.stream().map(q -> {
            LearnerQuestionGroupDTO groupDto = null;
            if (q.getQuestionGroup() != null && q.getQuestionGroup().getContextText() != null) {
                groupDto = LearnerQuestionGroupDTO.builder()
                        .id(q.getQuestionGroup().getId())
                        .passage(q.getQuestionGroup().getContextText())
                        .build();
            }
            
            List<LearnerQuestionOptionDTO> opts = q.getOptions().stream().map(opt -> 
                LearnerQuestionOptionDTO.builder()
                        .id(opt.getId())
                        .optionText(opt.getOptionText())
                        .build()
            ).collect(Collectors.toList());
            
            return LearnerExamQuestionDTO.builder()
                    .id(q.getId())
                    .content(q.getQuestionText())
                    .skill(q.getSkillParam() != null ? q.getSkillParam().getParamValue() : "General")
                    .globalIndex(null)
                    .group(groupDto)
                    .options(opts)
                    .build();
        }).collect(Collectors.toList());
    }
}
