package com.hango.hango_backend.service;

import com.hango.hango_backend.dto.ExamResponseDTO;
import com.hango.hango_backend.dto.ExamAttemptRequestDTO;
import com.hango.hango_backend.dto.ExamAttemptResponseDTO;
import com.hango.hango_backend.entity.Exam;
import com.hango.hango_backend.entity.ExamAttempt;
import com.hango.hango_backend.entity.User;
import com.hango.hango_backend.repository.ExamAttemptRepository;
import com.hango.hango_backend.repository.ExamQuestionRepository;
import com.hango.hango_backend.repository.ExamRepository;
import com.hango.hango_backend.repository.UserRepository;
import com.fasterxml.jackson.databind.ObjectMapper;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDateTime;
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
    private final ObjectMapper objectMapper = new ObjectMapper();

    public List<ExamResponseDTO> getAllExams(String status) {
        List<Exam> exams;
        if (status != null && !status.isEmpty() && !status.equalsIgnoreCase("All")) {
            exams = examRepository.findByDeletedAtIsNullAndStatus(status);
        } else {
            exams = examRepository.findAll().stream()
                    .filter(e -> e.getDeletedAt() == null)
                    .collect(Collectors.toList());
        }

        return exams.stream().map(this::mapToDTO).collect(Collectors.toList());
    }

    private ExamResponseDTO mapToDTO(Exam exam) {
        int questionCount = examQuestionRepository.countByIdExamId(exam.getId());
        int attemptCount = examAttemptRepository.countByExamId(exam.getId());

        // Mock rating between 4.5 and 5.0 for MVP
        double mockRating = 4.5 + (Math.random() * 0.5);

        String formattedLearners;
        if (attemptCount >= 1000) {
            formattedLearners = (attemptCount / 1000) + "k Learner";
        } else {
            formattedLearners = attemptCount + " Learner";
        }

        String creatorName = exam.getCreatedBy() != null ? exam.getCreatedBy().getFullName() : "Unknown";

        return ExamResponseDTO.builder()
                .id(exam.getId())
                .title(exam.getTitle())
                .description(exam.getDescription())
                .status(exam.getStatus())
                .creatorName(creatorName)
                .questionCount(questionCount)
                .durationMinutes(exam.getDurationMinutes())
                .rating(Math.round(mockRating * 10.0) / 10.0)
                .learnerCountFormatted(formattedLearners)
                .build();
    }

    public List<ExamAttemptResponseDTO> getExamAttempts(Long examId, Long userId) {
        List<ExamAttempt> attempts = examAttemptRepository.findByExamIdAndStudentIdOrderBySubmittedAtAsc(examId, userId);
        java.util.concurrent.atomic.AtomicInteger index = new java.util.concurrent.atomic.AtomicInteger(1);
        return attempts.stream()
                .map(a -> mapToAttemptDTO(a, index.getAndIncrement()))
                .collect(Collectors.toList());
    }

    @Transactional
    public ExamAttemptResponseDTO saveExamAttempt(Long examId, Long userId, ExamAttemptRequestDTO request) {
        Exam exam = examRepository.findById(examId)
                .orElseThrow(() -> new RuntimeException("Exam not found"));
        User student = userRepository.findById(userId)
                .orElseThrow(() -> new RuntimeException("User not found"));

        int nextAttemptNumber = examAttemptRepository.countByExamIdAndStudentId(examId, userId) + 1;

        String answersJson = null;
        try {
            if (request.getAnswers() != null) {
                answersJson = objectMapper.writeValueAsString(request.getAnswers());
            }
        } catch (Exception e) {
            answersJson = "{}";
        }

        ExamAttempt attempt = new ExamAttempt();
        attempt.setExam(exam);
        attempt.setStudent(student);
        attempt.setScore(request.getScore());
        attempt.setAnswersJson(answersJson);
        attempt.setStartedAt(LocalDateTime.now().minusMinutes(exam.getDurationMinutes()));
        attempt.setSubmittedAt(LocalDateTime.now());

        ExamAttempt saved = examAttemptRepository.save(attempt);
        return mapToAttemptDTO(saved, nextAttemptNumber);
    }

    private ExamAttemptResponseDTO mapToAttemptDTO(ExamAttempt attempt, int attemptNumber) {
        Map<String, Integer> answers = null;
        try {
            if (attempt.getAnswersJson() != null) {
                answers = objectMapper.readValue(attempt.getAnswersJson(), Map.class);
            }
        } catch (Exception e) {
            answers = new java.util.HashMap<>();
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
                .score(attempt.getScore())
                .attemptNumber(attemptNumber)
                .date(dateStr)
                .status(isPassed ? "PASSED" : "FAILED")
                .answers(answers)
                .build();
    }
}
