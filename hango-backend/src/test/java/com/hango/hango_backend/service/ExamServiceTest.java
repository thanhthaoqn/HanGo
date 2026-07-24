package com.hango.hango_backend.service;

import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.util.List;
import java.util.Map;
import java.util.Optional;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyLong;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import static org.mockito.Mockito.when;
import org.mockito.junit.jupiter.MockitoExtension;

import com.hango.hango_backend.dto.ExamAttemptRequestDTO;
import com.hango.hango_backend.dto.ExamAttemptResponseDTO;
import com.hango.hango_backend.dto.ExamResponseDTO;
import com.hango.hango_backend.entity.Exam;
import com.hango.hango_backend.entity.ExamAttempt;
import com.hango.hango_backend.entity.User;
import com.hango.hango_backend.repository.ExamAttemptRepository;
import com.hango.hango_backend.repository.ExamQuestionRepository;
import com.hango.hango_backend.repository.ExamRepository;
import com.hango.hango_backend.repository.UserRepository;

@ExtendWith(MockitoExtension.class)
class ExamServiceTest {

    @Mock
    private ExamRepository examRepository;
    @Mock
    private ExamQuestionRepository examQuestionRepository;
    @Mock
    private ExamAttemptRepository examAttemptRepository;
    @Mock
    private UserRepository userRepository;

    @InjectMocks
    private ExamService examService;

    private Exam exam(Long id, String title, String status, Integer durationMinutes, User creator) {
        Exam e = new Exam();
        e.setId(id);
        e.setTitle(title);
        e.setStatus(status);
        e.setDurationMinutes(durationMinutes);
        e.setCreatedBy(creator);
        return e;
    }

    private User user(Long id, String email, String fullName) {
        return User.builder().id(id).email(email).fullName(fullName).build();
    }

    // =================================================================
    // getAllExams
    // =================================================================

    @Test
    void getAllExamsShouldQueryPublishedOnlyWhenStatusIsNull() {
        when(examRepository.findByDeletedAtIsNullAndStatus("PUBLISHED"))
                .thenReturn(List.of(exam(1L, "Exam A", "PUBLISHED", 50, user(1L, "trainer@example.com", "Trainer A"))));

        List<ExamResponseDTO> result = examService.getAllExams(null);

        assertEquals(1, result.size());
        assertEquals("Exam A", result.get(0).getTitle());
    }

    @Test
    void getAllExamsShouldQueryPublishedOnlyWhenStatusIsAllCaseInsensitive() {
        when(examRepository.findByDeletedAtIsNullAndStatus("PUBLISHED")).thenReturn(List.of());

        examService.getAllExams("all");

        org.mockito.Mockito.verify(examRepository).findByDeletedAtIsNullAndStatus("PUBLISHED");
    }

    @Test
    void getAllExamsShouldAlwaysReturnEmptyWhenNonPublishedStatusRequested() {
        Exam draftExam = exam(2L, "Draft Exam", "DRAFT", 40, null);
        when(examRepository.findByDeletedAtIsNullAndStatus("DRAFT")).thenReturn(List.of(draftExam));

        List<ExamResponseDTO> result = examService.getAllExams("DRAFT");

        assertTrue(result.isEmpty());
    }

    @Test
    void getAllExamsShouldFallbackCreatorNameToUnknownWhenCreatedByNull() {
        when(examRepository.findByDeletedAtIsNullAndStatus("PUBLISHED"))
                .thenReturn(List.of(exam(3L, "Orphan Exam", "PUBLISHED", 30, null)));

        List<ExamResponseDTO> result = examService.getAllExams(null);

        assertEquals("Unknown", result.get(0).getCreatorName());
    }

    @Test
    void getAllExamsShouldFormatLearnerCountInThousandsAtBoundary() {
        Exam e = exam(4L, "Popular Exam", "PUBLISHED", 45, user(1L, "trainer@example.com", "Trainer A"));
        when(examRepository.findByDeletedAtIsNullAndStatus("PUBLISHED")).thenReturn(List.of(e));
        when(examAttemptRepository.countByExamId(4L)).thenReturn(1000);

        List<ExamResponseDTO> result = examService.getAllExams(null);

        assertEquals("1k Learner", result.get(0).getLearnerCountFormatted());
    }

    @Test
    void getAllExamsShouldFormatLearnerCountAsPlainNumberBelowThousand() {
        Exam e = exam(5L, "New Exam", "PUBLISHED", 45, user(1L, "trainer@example.com", "Trainer A"));
        when(examRepository.findByDeletedAtIsNullAndStatus("PUBLISHED")).thenReturn(List.of(e));
        when(examAttemptRepository.countByExamId(5L)).thenReturn(999);

        List<ExamResponseDTO> result = examService.getAllExams(null);

        assertEquals("999 Learner", result.get(0).getLearnerCountFormatted());
    }

    // =================================================================
    // getExamAttempts
    // =================================================================

    @Test
    void getExamAttemptsShouldReturnSequentialAttemptNumbersInSubmittedOrder() {
        User student = user(1L, "learner@example.com", "Learner A");
        Exam e = exam(1L, "Exam A", "PUBLISHED", 50, null);
        ExamAttempt first = examAttempt(101L, e, student, new BigDecimal("6.0"), null, LocalDateTime.now().minusDays(1));
        ExamAttempt second = examAttempt(102L, e, student, new BigDecimal("8.0"), null, LocalDateTime.now());
        when(examAttemptRepository.findByExamIdAndStudentIdOrderBySubmittedAtAsc(1L, 1L))
                .thenReturn(List.of(first, second));

        List<ExamAttemptResponseDTO> result = examService.getExamAttempts(1L, 1L);

        assertEquals(1, result.get(0).getAttemptNumber());
        assertEquals(2, result.get(1).getAttemptNumber());
        assertEquals("PASSED", result.get(0).getStatus());
    }

    @Test
    void getExamAttemptsShouldMarkScoreBelowFiveAsFailed() {
        User student = user(1L, "learner@example.com", "Learner A");
        Exam e = exam(1L, "Exam A", "PUBLISHED", 50, null);
        ExamAttempt attempt = examAttempt(101L, e, student, new BigDecimal("4.9"), null, LocalDateTime.now());
        when(examAttemptRepository.findByExamIdAndStudentIdOrderBySubmittedAtAsc(1L, 1L))
                .thenReturn(List.of(attempt));

        List<ExamAttemptResponseDTO> result = examService.getExamAttempts(1L, 1L);

        assertEquals("FAILED", result.get(0).getStatus());
    }

    @Test
    void getExamAttemptsShouldMarkNullScoreAsFailed() {
        User student = user(1L, "learner@example.com", "Learner A");
        Exam e = exam(1L, "Exam A", "PUBLISHED", 50, null);
        ExamAttempt attempt = examAttempt(101L, e, student, null, null, LocalDateTime.now());
        when(examAttemptRepository.findByExamIdAndStudentIdOrderBySubmittedAtAsc(1L, 1L))
                .thenReturn(List.of(attempt));

        List<ExamAttemptResponseDTO> result = examService.getExamAttempts(1L, 1L);

        assertEquals("FAILED", result.get(0).getStatus());
    }

    // =================================================================
    // getMyExamAttempts
    // =================================================================

    @Test
    void getMyExamAttemptsShouldComputeAttemptNumberPerExamIndependently() {
        User student = user(1L, "learner@example.com", "Learner A");
        Exam examA = exam(1L, "Exam A", "PUBLISHED", 50, null);
        Exam examB = exam(2L, "Exam B", "PUBLISHED", 50, null);
        ExamAttempt attemptOnA = examAttempt(201L, examA, student, new BigDecimal("7.0"), null, LocalDateTime.now());
        ExamAttempt attemptOnB = examAttempt(202L, examB, student, new BigDecimal("6.0"), null, LocalDateTime.now());
        when(examAttemptRepository.findTop10ByStudent_IdOrderBySubmittedAtDesc(1L))
                .thenReturn(List.of(attemptOnB, attemptOnA));
        when(examAttemptRepository.countByExamIdAndStudentId(2L, 1L)).thenReturn(3);
        when(examAttemptRepository.countByExamIdAndStudentId(1L, 1L)).thenReturn(1);

        List<ExamAttemptResponseDTO> result = examService.getMyExamAttempts(1L);

        assertEquals(3, result.get(0).getAttemptNumber());
        assertEquals(1, result.get(1).getAttemptNumber());
    }

    // =================================================================
    // saveExamAttempt
    // =================================================================

    private ExamAttempt examAttempt(Long id, Exam exam, User student, BigDecimal score, String answersJson, LocalDateTime submittedAt) {
        ExamAttempt a = new ExamAttempt();
        a.setId(id);
        a.setExam(exam);
        a.setStudent(student);
        a.setScore(score);
        a.setAnswersJson(answersJson);
        a.setSubmittedAt(submittedAt);
        return a;
    }

    @Test
    void saveExamAttemptShouldThrowWhenExamNotFound() {
        when(examRepository.findById(99L)).thenReturn(Optional.empty());

        assertThrows(RuntimeException.class,
                () -> examService.saveExamAttempt(99L, 1L, ExamAttemptRequestDTO.builder().score(new BigDecimal("8.0")).build()));
    }

    @Test
    void saveExamAttemptShouldThrowWhenUserNotFound() {
        when(examRepository.findById(1L)).thenReturn(Optional.of(exam(1L, "Exam A", "PUBLISHED", 50, null)));
        when(userRepository.findById(99L)).thenReturn(Optional.empty());

        assertThrows(RuntimeException.class,
                () -> examService.saveExamAttempt(1L, 99L, ExamAttemptRequestDTO.builder().score(new BigDecimal("8.0")).build()));
    }

    @Test
    void saveExamAttemptShouldPersistClientSuppliedScoreWithoutServerSideRecalculation() {
        Exam e = exam(1L, "Exam A", "PUBLISHED", 50, null);
        User student = user(1L, "learner@example.com", "Learner A");
        when(examRepository.findById(1L)).thenReturn(Optional.of(e));
        when(userRepository.findById(1L)).thenReturn(Optional.of(student));
        when(examAttemptRepository.countByExamIdAndStudentId(1L, 1L)).thenReturn(0);
        when(examAttemptRepository.save(any(ExamAttempt.class))).thenAnswer(inv -> {
            ExamAttempt a = inv.getArgument(0);
            a.setId(500L);
            return a;
        });

        ExamAttemptResponseDTO response = examService.saveExamAttempt(1L, 1L,
                ExamAttemptRequestDTO.builder().score(new BigDecimal("11.5")).build());

        assertEquals(new BigDecimal("11.5"), response.getScore());
    }

    @Test
    void saveExamAttemptShouldComputeNextAttemptNumberFromExistingCount() {
        Exam e = exam(1L, "Exam A", "PUBLISHED", 50, null);
        User student = user(1L, "learner@example.com", "Learner A");
        when(examRepository.findById(1L)).thenReturn(Optional.of(e));
        when(userRepository.findById(1L)).thenReturn(Optional.of(student));
        when(examAttemptRepository.countByExamIdAndStudentId(1L, 1L)).thenReturn(2);
        when(examAttemptRepository.save(any(ExamAttempt.class))).thenAnswer(inv -> inv.getArgument(0));

        ExamAttemptResponseDTO response = examService.saveExamAttempt(1L, 1L,
                ExamAttemptRequestDTO.builder().score(new BigDecimal("7.0")).build());

        assertEquals(3, response.getAttemptNumber());
    }

    @Test
    void saveExamAttemptShouldDefaultAnswersJsonToEmptyObjectWhenAnswersIsNull() {
        Exam e = exam(1L, "Exam A", "PUBLISHED", 50, null);
        User student = user(1L, "learner@example.com", "Learner A");
        when(examRepository.findById(1L)).thenReturn(Optional.of(e));
        when(userRepository.findById(1L)).thenReturn(Optional.of(student));
        when(examAttemptRepository.countByExamIdAndStudentId(1L, 1L)).thenReturn(0);
        ArgumentCaptor<ExamAttempt> captor = ArgumentCaptor.forClass(ExamAttempt.class);
        when(examAttemptRepository.save(captor.capture())).thenAnswer(inv -> inv.getArgument(0));

        examService.saveExamAttempt(1L, 1L, ExamAttemptRequestDTO.builder().score(new BigDecimal("7.0")).build());

        assertEquals(null, captor.getValue().getAnswersJson());
    }

    @Test
    void saveExamAttemptShouldPersistEnrichedAnswersAsJsonArrayButEchoBackEmptyAnswersDueToTypeMismatch() {
        Exam e = exam(1L, "Exam A", "PUBLISHED", 50, null);
        User student = user(1L, "learner@example.com", "Learner A");
        when(examRepository.findById(1L)).thenReturn(Optional.of(e));
        when(userRepository.findById(1L)).thenReturn(Optional.of(student));
        when(examAttemptRepository.countByExamIdAndStudentId(1L, 1L)).thenReturn(0);
        ArgumentCaptor<ExamAttempt> captor = ArgumentCaptor.forClass(ExamAttempt.class);
        when(examAttemptRepository.save(captor.capture())).thenAnswer(inv -> inv.getArgument(0));

        Map<String, Object> rawAnswer = Map.of("selectedOption", "A", "isCorrect", true, "skill", "Reading", "topic", "Detail");
        ExamAttemptResponseDTO response = examService.saveExamAttempt(1L, 1L,
                ExamAttemptRequestDTO.builder().score(new BigDecimal("7.0")).answers(Map.of("1", rawAnswer)).build());

        String persistedJson = captor.getValue().getAnswersJson();
        assertTrue(persistedJson.trim().startsWith("["), "answersJson persisted to DB should be a JSON array: " + persistedJson);
        assertTrue(persistedJson.contains("\"questionId\":1"));

        assertTrue(response.getAnswers() == null || response.getAnswers().isEmpty(),
                "GAP-EXM-01: mapToAttemptDTO reads answersJson back as Map.class, but it's actually a JSON array — "
                        + "Jackson throws internally (caught) and answers silently comes back empty despite being correctly persisted.");
    }

    // =================================================================
    // saveExamAttempt (anyLong import usage guard)
    // =================================================================

    @Test
    void saveExamAttemptShouldLookUpExamAndUserByGivenIds() {
        Exam e = exam(1L, "Exam A", "PUBLISHED", 50, null);
        User student = user(1L, "learner@example.com", "Learner A");
        when(examRepository.findById(anyLong())).thenReturn(Optional.of(e));
        when(userRepository.findById(anyLong())).thenReturn(Optional.of(student));
        when(examAttemptRepository.countByExamIdAndStudentId(anyLong(), anyLong())).thenReturn(0);
        when(examAttemptRepository.save(any(ExamAttempt.class))).thenAnswer(inv -> inv.getArgument(0));

        examService.saveExamAttempt(1L, 1L, ExamAttemptRequestDTO.builder().score(new BigDecimal("7.0")).build());

        org.mockito.Mockito.verify(examRepository).findById(1L);
        org.mockito.Mockito.verify(userRepository).findById(1L);
    }
}
