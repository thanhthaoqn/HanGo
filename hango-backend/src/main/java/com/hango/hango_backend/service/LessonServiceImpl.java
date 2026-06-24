package com.hango.hango_backend.service;

import com.hango.hango_backend.dto.CommentDTO;
import com.hango.hango_backend.dto.LessonDetailDTO;
import com.hango.hango_backend.dto.QuizQuestionDTO;
import com.hango.hango_backend.dto.LessonQuizAttemptDTO;
import com.hango.hango_backend.dto.LessonQuizAttemptRequestDTO;
import com.hango.hango_backend.entity.Lesson;
import com.hango.hango_backend.entity.LessonQuizAttempt;
import com.hango.hango_backend.entity.LessonProgress;
import com.hango.hango_backend.entity.Enrollment;
import com.hango.hango_backend.entity.User;
import com.hango.hango_backend.repository.LessonRepository;
import com.hango.hango_backend.repository.LessonQuizAttemptRepository;
import com.hango.hango_backend.repository.UserRepository;
import com.hango.hango_backend.repository.LessonProgressRepository;
import com.hango.hango_backend.repository.EnrollmentRepository;
import com.fasterxml.jackson.databind.ObjectMapper;
import lombok.RequiredArgsConstructor;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDateTime;
import java.math.BigDecimal;
import java.math.RoundingMode;
import java.util.List;
import java.util.Map;
import java.util.stream.Collectors;

@Service
@RequiredArgsConstructor
public class LessonServiceImpl implements LessonService {

    private final LessonRepository lessonRepository;
    private final CommentService commentService;
    private final JdbcTemplate jdbcTemplate;
    private final LessonQuizAttemptRepository quizAttemptRepository;
    private final UserRepository userRepository;
    private final LessonProgressRepository lessonProgressRepository;
    private final EnrollmentRepository enrollmentRepository;
    private final ObjectMapper objectMapper = new ObjectMapper();

    @Override
    public LessonDetailDTO getLessonDetail(Long lessonId, Long userId) {
        Lesson lesson = lessonRepository.findById(lessonId)
                .orElseThrow(() -> new RuntimeException("Lesson not found"));

        List<CommentDTO> comments = commentService.getCommentsByLesson(lessonId, userId);

        List<QuizQuestionDTO> questions = jdbcTemplate.query(
                "SELECT q.id AS question_id, q.question_text, q.explanation, qg.context_text AS passage " +
                "FROM lesson_quizzes lq " +
                "JOIN questions q ON lq.question_id = q.id " +
                "LEFT JOIN question_groups qg ON q.group_id = qg.id " +
                "WHERE lq.lesson_id = ? " +
                "ORDER BY lq.display_order ASC",
                (rs, rowNum) -> {
                    Long qId = rs.getLong("question_id");
                    String questionText = rs.getString("question_text");
                    String explanation = rs.getString("explanation");
                    String passage = rs.getString("passage");

                    List<Map<String, Object>> optionsRows = jdbcTemplate.queryForList(
                            "SELECT option_text, is_correct FROM question_options WHERE question_id = ? ORDER BY id ASC",
                            qId
                    );

                    List<String> options = new java.util.ArrayList<>();
                    Integer correctIndex = 0;
                    for (int i = 0; i < optionsRows.size(); i++) {
                        Map<String, Object> row = optionsRows.get(i);
                        options.add((String) row.get("option_text"));
                        Object isCorrectObj = row.get("is_correct");
                        boolean isCorrect = false;
                        if (isCorrectObj instanceof Boolean) {
                            isCorrect = (Boolean) isCorrectObj;
                        } else if (isCorrectObj instanceof Number) {
                            isCorrect = ((Number) isCorrectObj).intValue() == 1;
                        }
                        if (isCorrect) {
                            correctIndex = i;
                        }
                    }

                    return QuizQuestionDTO.builder()
                            .id(qId)
                            .passage(passage)
                            .questionText(questionText)
                            .explanation(explanation)
                            .options(options)
                            .correctIndex(correctIndex)
                            .build();
                },
                lessonId
        );

        boolean isCompleted = false;
        if (userId != null) {
            isCompleted = lessonProgressRepository.existsByUserIdAndLessonIdAndIsCompletedTrue(userId, lessonId);
        }

        return LessonDetailDTO.builder()
                .id(lesson.getId())
                .title(lesson.getTitle())
                .content(lesson.getContent())
                .sectionId(lesson.getSection() != null ? lesson.getSection().getId() : null)
                .courseId(lesson.getSection() != null && lesson.getSection().getCourse() != null 
                            ? lesson.getSection().getCourse().getId() : null)
                .comments(comments)
                .questions(questions)
                .isCompleted(isCompleted)
                .build();
    }

    @Override
    public List<LessonQuizAttemptDTO> getQuizAttempts(Long lessonId, Long userId) {
        List<LessonQuizAttempt> attempts = quizAttemptRepository.findByLessonIdAndStudentIdOrderByAttemptNumberAsc(lessonId, userId);
        return attempts.stream().map(a -> {
            Map<String, Integer> answers = null;
            try {
                if (a.getAnswersJson() != null) {
                    answers = objectMapper.readValue(a.getAnswersJson(), Map.class);
                }
            } catch (Exception e) {
                answers = new java.util.HashMap<>();
            }
            return LessonQuizAttemptDTO.builder()
                    .attemptNumber(a.getAttemptNumber())
                    .state(a.getState())
                    .grade(String.format("%.1f / 10.0", a.getScore()))
                    .submittedTime(a.getSubmittedAt().toString().replace("T", " ").substring(0, 16))
                    .answers(answers)
                    .build();
        }).collect(Collectors.toList());
    }

    @Override
    @Transactional
    public LessonQuizAttemptDTO saveQuizAttempt(Long lessonId, Long userId, LessonQuizAttemptRequestDTO request) {
        Lesson lesson = lessonRepository.findById(lessonId)
                .orElseThrow(() -> new RuntimeException("Lesson not found"));
        User student = userRepository.findById(userId)
                .orElseThrow(() -> new RuntimeException("User not found"));

        int nextAttemptNumber = quizAttemptRepository.countByLessonIdAndStudentId(lessonId, userId) + 1;

        String answersJson = null;
        try {
            if (request.getAnswers() != null) {
                answersJson = objectMapper.writeValueAsString(request.getAnswers());
            }
        } catch (Exception e) {
            answersJson = "{}";
        }

        LessonQuizAttempt attempt = LessonQuizAttempt.builder()
                .lesson(lesson)
                .student(student)
                .score(request.getScore())
                .attemptNumber(nextAttemptNumber)
                .state(request.getState() != null ? request.getState() : "Finished")
                .answersJson(answersJson)
                .submittedAt(LocalDateTime.now())
                .build();

        LessonQuizAttempt saved = quizAttemptRepository.save(attempt);

        // Auto mark the lesson as completed upon quiz attempt submission
        try {
            completeLesson(lessonId, userId, true);
        } catch (Exception e) {
            e.printStackTrace(); // Log warning but let transaction commit quiz attempt
        }

        return LessonQuizAttemptDTO.builder()
                .attemptNumber(saved.getAttemptNumber())
                .state(saved.getState())
                .grade(String.format("%.1f / 10.0", saved.getScore()))
                .submittedTime(saved.getSubmittedAt().toString().replace("T", " ").substring(0, 16))
                .answers(request.getAnswers())
                .build();
    }

    @Override
    @Transactional
    public void completeLesson(Long lessonId, Long userId, boolean isCompleted) {
        User user = userRepository.findById(userId)
                .orElseThrow(() -> new RuntimeException("User not found"));
        Lesson lesson = lessonRepository.findById(lessonId)
                .orElseThrow(() -> new RuntimeException("Lesson not found"));

        LessonProgress progress = lessonProgressRepository.findByUserIdAndLessonId(userId, lessonId)
                .orElseGet(() -> LessonProgress.builder()
                        .user(user)
                        .lesson(lesson)
                        .isCompleted(!isCompleted)
                        .build());

        if (progress.isCompleted() == isCompleted) {
            return;
        }

        progress.setCompleted(isCompleted);
        progress.setCompletedAt(isCompleted ? LocalDateTime.now() : null);
        lessonProgressRepository.save(progress);

        if (lesson.getSection() != null && lesson.getSection().getCourse() != null) {
            Long courseId = lesson.getSection().getCourse().getId();
            
            // Acquire pessimistic write lock to calculate progress and prevent concurrency races
            Enrollment enrollment = enrollmentRepository.findByUserIdAndCourseIdWithLock(userId, courseId)
                    .orElse(null);
            
            if (enrollment != null) {
                long totalLessons = lessonRepository.countByCourseId(courseId);
                if (totalLessons > 0) {
                    long completedLessons = lessonProgressRepository.countCompletedLessonsByUserIdAndCourseId(userId, courseId);
                    BigDecimal percentage = BigDecimal.valueOf((double) completedLessons / totalLessons * 100)
                            .setScale(2, RoundingMode.HALF_UP);
                    
                    enrollment.setProgressPercentage(percentage);
                    
                    if (completedLessons == totalLessons) {
                        enrollment.setStatus("COMPLETED");
                        enrollment.setCompletedAt(LocalDateTime.now());
                    } else {
                        enrollment.setStatus("ENROLLED");
                        enrollment.setCompletedAt(null);
                    }
                    enrollmentRepository.save(enrollment);
                }
            }
        }
    }
}
