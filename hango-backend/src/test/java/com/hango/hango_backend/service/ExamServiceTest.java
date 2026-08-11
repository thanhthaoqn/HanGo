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
import com.hango.hango_backend.dto.LearnerExamQuestionDTO;
import com.hango.hango_backend.entity.Exam;
import com.hango.hango_backend.entity.ExamAttempt;
import com.hango.hango_backend.entity.Question;
import com.hango.hango_backend.entity.QuestionGroup;
import com.hango.hango_backend.entity.QuestionOption;
import com.hango.hango_backend.entity.SystemParameter;
import com.hango.hango_backend.entity.User;
import com.hango.hango_backend.repository.ExamAttemptRepository;
import com.hango.hango_backend.repository.ExamQuestionRepository;
import com.hango.hango_backend.repository.ExamRepository;
import com.hango.hango_backend.repository.QuestionRepository;
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
    @Mock
    private QuestionRepository questionRepository;

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

    private ExamAttempt examAttempt(Long id, Exam exam, User student, BigDecimal score, String answersJson,
            LocalDateTime startedAt, LocalDateTime submittedAt) {
        ExamAttempt a = new ExamAttempt();
        a.setId(id);
        a.setExam(exam);
        a.setStudent(student);
        a.setScore(score);
        a.setAnswersJson(answersJson);
        a.setStartedAt(startedAt);
        a.setSubmittedAt(submittedAt);
        return a;
    }

    private QuestionOption questionOption(Long id, boolean isCorrect) {
        QuestionOption opt = new QuestionOption();
        opt.setId(id);
        opt.setIsCorrect(isCorrect);
        return opt;
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
    void getAllExamsShouldReturnExamsMatchingTheRequestedNonPublishedStatus() {
        Exam draftExam = exam(2L, "Draft Exam", "DRAFT", 40, null);
        when(examRepository.findByDeletedAtIsNullAndStatus("DRAFT")).thenReturn(List.of(draftExam));

        List<ExamResponseDTO> result = examService.getAllExams("DRAFT");

        assertEquals(1, result.size());
        assertEquals("Draft Exam", result.get(0).getTitle());
    }

    @Test
    void getAllExamsShouldFallbackCreatorNameToUnknownWhenCreatedByNull() {
        when(examRepository.findByDeletedAtIsNullAndStatus("PUBLISHED"))
                .thenReturn(List.of(exam(3L, "Orphan Exam", "PUBLISHED", 30, null)));

        List<ExamResponseDTO> result = examService.getAllExams(null);

        assertEquals("Unknown", result.get(0).getCreatorName());
    }

    @Test
    void getAllExamsShouldReturnDistinctStudentCountAsLearnerCountFormatted() {
        Exam e = exam(4L, "Popular Exam", "PUBLISHED", 45, user(1L, "trainer@example.com", "Trainer A"));
        when(examRepository.findByDeletedAtIsNullAndStatus("PUBLISHED")).thenReturn(List.of(e));
        when(examAttemptRepository.countDistinctStudentsByExamIds(List.of(4L)))
                .thenReturn(java.util.Collections.singletonList(new Object[] { 4L, 1000L }));

        List<ExamResponseDTO> result = examService.getAllExams(null);

        assertEquals("1000", result.get(0).getLearnerCountFormatted());
    }

    @Test
    void getAllExamsShouldDefaultLearnerCountToZeroWhenCountIsZero() {
        Exam e = exam(5L, "New Exam", "PUBLISHED", 45, user(1L, "trainer@example.com", "Trainer A"));
        when(examRepository.findByDeletedAtIsNullAndStatus("PUBLISHED")).thenReturn(List.of(e));
        when(examAttemptRepository.countDistinctStudentsByExamIds(List.of(5L)))
                .thenReturn(java.util.Collections.singletonList(new Object[] { 5L, 0L }));

        List<ExamResponseDTO> result = examService.getAllExams(null);

        assertEquals("0", result.get(0).getLearnerCountFormatted());
    }

    @Test
    void getAllExamsShouldDefaultLearnerCountToZeroWhenNoAttemptRowReturned() {
        Exam e = exam(6L, "Fresh Exam", "PUBLISHED", 45, user(1L, "trainer@example.com", "Trainer A"));
        when(examRepository.findByDeletedAtIsNullAndStatus("PUBLISHED")).thenReturn(List.of(e));
        when(examAttemptRepository.countDistinctStudentsByExamIds(List.of(6L))).thenReturn(List.of());

        List<ExamResponseDTO> result = examService.getAllExams(null);

        assertEquals("0", result.get(0).getLearnerCountFormatted());
    }

    // =================================================================
    // getExamAttempts
    // =================================================================

    @Test
    void getExamAttemptsShouldReturnSequentialAttemptNumbersInSubmittedOrder() {
        User student = user(1L, "learner@example.com", "Learner A");
        Exam e = exam(1L, "Exam A", "PUBLISHED", 50, null);
        LocalDateTime t1 = LocalDateTime.of(2026, 1, 1, 10, 0);
        LocalDateTime t2 = LocalDateTime.of(2026, 1, 2, 10, 0);
        ExamAttempt first = examAttempt(101L, e, student, new BigDecimal("6.0"), null, t1, t1);
        ExamAttempt second = examAttempt(102L, e, student, new BigDecimal("8.0"), null, t2, t2);
        when(examAttemptRepository.findByExamIdAndStudentIdOrderByStartedAtDesc(1L, 1L))
                .thenReturn(List.of(first, second));
        when(examAttemptRepository.countByExamIdAndStudentIdAndStartedAtLessThanEqual(1L, 1L, t1)).thenReturn(1);
        when(examAttemptRepository.countByExamIdAndStudentIdAndStartedAtLessThanEqual(1L, 1L, t2)).thenReturn(2);

        List<ExamAttemptResponseDTO> result = examService.getExamAttempts(1L, 1L);

        assertEquals(1, result.get(0).getAttemptNumber());
        assertEquals(2, result.get(1).getAttemptNumber());
        assertEquals("PASSED", result.get(0).getStatus());
    }

    @Test
    void getExamAttemptsShouldMarkScoreBelowFiveAsFailed() {
        User student = user(1L, "learner@example.com", "Learner A");
        Exam e = exam(1L, "Exam A", "PUBLISHED", 50, null);
        LocalDateTime t = LocalDateTime.of(2026, 1, 1, 10, 0);
        ExamAttempt attempt = examAttempt(101L, e, student, new BigDecimal("4.9"), null, t, t);
        when(examAttemptRepository.findByExamIdAndStudentIdOrderByStartedAtDesc(1L, 1L))
                .thenReturn(List.of(attempt));
        when(examAttemptRepository.countByExamIdAndStudentIdAndStartedAtLessThanEqual(1L, 1L, t)).thenReturn(1);

        List<ExamAttemptResponseDTO> result = examService.getExamAttempts(1L, 1L);

        assertEquals("FAILED", result.get(0).getStatus());
    }

    @Test
    void getExamAttemptsShouldMarkNullScoreAsFailed() {
        User student = user(1L, "learner@example.com", "Learner A");
        Exam e = exam(1L, "Exam A", "PUBLISHED", 50, null);
        LocalDateTime t = LocalDateTime.of(2026, 1, 1, 10, 0);
        ExamAttempt attempt = examAttempt(101L, e, student, null, null, t, t);
        when(examAttemptRepository.findByExamIdAndStudentIdOrderByStartedAtDesc(1L, 1L))
                .thenReturn(List.of(attempt));
        when(examAttemptRepository.countByExamIdAndStudentIdAndStartedAtLessThanEqual(1L, 1L, t)).thenReturn(1);

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
        LocalDateTime tA = LocalDateTime.of(2026, 1, 1, 10, 0);
        LocalDateTime tB = LocalDateTime.of(2026, 1, 2, 10, 0);
        ExamAttempt attemptOnA = examAttempt(201L, examA, student, new BigDecimal("7.0"), null, tA, tA);
        ExamAttempt attemptOnB = examAttempt(202L, examB, student, new BigDecimal("6.0"), null, tB, tB);
        when(examAttemptRepository.findByStudentIdOrderByStartedAtDesc(1L))
                .thenReturn(List.of(attemptOnB, attemptOnA));
        when(examAttemptRepository.countByExamIdAndStudentIdAndStartedAtLessThanEqual(2L, 1L, tB)).thenReturn(3);
        when(examAttemptRepository.countByExamIdAndStudentIdAndStartedAtLessThanEqual(1L, 1L, tA)).thenReturn(1);

        List<ExamAttemptResponseDTO> result = examService.getMyExamAttempts(1L);

        assertEquals(3, result.get(0).getAttemptNumber());
        assertEquals(1, result.get(1).getAttemptNumber());
    }

    // =================================================================
    // saveExamAttempt
    // =================================================================

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
    void saveExamAttemptShouldDefaultScoreToZeroWhenNoAnswersProvided() {
        Exam e = exam(1L, "Exam A", "PUBLISHED", 50, null);
        User student = user(1L, "learner@example.com", "Learner A");
        when(examRepository.findById(1L)).thenReturn(Optional.of(e));
        when(userRepository.findById(1L)).thenReturn(Optional.of(student));
        when(examAttemptRepository.countByExamIdAndStudentId(1L, 1L)).thenReturn(0);
        when(questionRepository.findByExamIdOrderByQuestionOrder(1L)).thenReturn(List.of());
        when(examAttemptRepository.save(any(ExamAttempt.class))).thenAnswer(inv -> {
            ExamAttempt a = inv.getArgument(0);
            a.setId(500L);
            return a;
        });

        ExamAttemptResponseDTO response = examService.saveExamAttempt(1L, 1L,
                ExamAttemptRequestDTO.builder().score(new BigDecimal("11.5")).build());

        assertEquals(0, response.getScore().compareTo(BigDecimal.ZERO));
    }

    @Test
    void saveExamAttemptShouldComputeNextAttemptNumberFromExistingCount() {
        Exam e = exam(1L, "Exam A", "PUBLISHED", 50, null);
        User student = user(1L, "learner@example.com", "Learner A");
        when(examRepository.findById(1L)).thenReturn(Optional.of(e));
        when(userRepository.findById(1L)).thenReturn(Optional.of(student));
        when(examAttemptRepository.countByExamIdAndStudentId(1L, 1L)).thenReturn(2);
        when(questionRepository.findByExamIdOrderByQuestionOrder(1L)).thenReturn(List.of());
        when(examAttemptRepository.save(any(ExamAttempt.class))).thenAnswer(inv -> inv.getArgument(0));

        ExamAttemptResponseDTO response = examService.saveExamAttempt(1L, 1L,
                ExamAttemptRequestDTO.builder().score(new BigDecimal("7.0")).build());

        assertEquals(3, response.getAttemptNumber());
    }

    @Test
    void saveExamAttemptShouldCalculateScoreFromCorrectAnswersAgainstExamQuestions() {
        Exam e = exam(1L, "Exam A", "PUBLISHED", 50, null);
        User student = user(1L, "learner@example.com", "Learner A");

        Question q0 = new Question();
        q0.setId(10L);
        q0.setOptions(List.of(questionOption(100L, false), questionOption(101L, true)));

        Question q1 = new Question();
        q1.setId(11L);
        q1.setOptions(List.of(questionOption(110L, true), questionOption(111L, false)));

        when(examRepository.findById(1L)).thenReturn(Optional.of(e));
        when(userRepository.findById(1L)).thenReturn(Optional.of(student));
        when(examAttemptRepository.countByExamIdAndStudentId(1L, 1L)).thenReturn(0);
        when(questionRepository.findByExamIdOrderByQuestionOrder(1L)).thenReturn(List.of(q0, q1));
        when(examAttemptRepository.save(any(ExamAttempt.class))).thenAnswer(inv -> inv.getArgument(0));

        // Answer keys are 1-indexed (question 1 -> q0, question 2 -> q1).
        // q0: selects option index 1 (correct). q1: selects option index 1 (incorrect) -> 1 of 2 correct.
        Map<String, Object> answers = Map.of("1", "1", "2", "1");

        ExamAttemptResponseDTO response = examService.saveExamAttempt(1L, 1L,
                ExamAttemptRequestDTO.builder().answers(answers).build());

        assertEquals(0, response.getScore().compareTo(new BigDecimal("5.00")));
    }

    @Test
    void saveExamAttemptShouldLeaveAnswersJsonNullWhenAnswersIsNull() {
        Exam e = exam(1L, "Exam A", "PUBLISHED", 50, null);
        User student = user(1L, "learner@example.com", "Learner A");
        when(examRepository.findById(1L)).thenReturn(Optional.of(e));
        when(userRepository.findById(1L)).thenReturn(Optional.of(student));
        when(examAttemptRepository.countByExamIdAndStudentId(1L, 1L)).thenReturn(0);
        when(questionRepository.findByExamIdOrderByQuestionOrder(1L)).thenReturn(List.of());
        ArgumentCaptor<ExamAttempt> captor = ArgumentCaptor.forClass(ExamAttempt.class);
        when(examAttemptRepository.save(captor.capture())).thenAnswer(inv -> inv.getArgument(0));

        examService.saveExamAttempt(1L, 1L, ExamAttemptRequestDTO.builder().score(new BigDecimal("7.0")).build());

        assertEquals(null, captor.getValue().getAnswersJson());
    }

    @Test
    void saveExamAttemptShouldPersistEnrichedAnswersAsJsonArrayAndCorrectlyEchoBackAnswersOnRoundTrip() {
        // GAP-EXM-01 (reading the persisted JSON array back via Map.class) is fixed:
        // mapToAttemptDTO now reads answersJson back via List.class, so a numeric
        // selectedOption round-trips correctly instead of coming back empty.
        Exam e = exam(1L, "Exam A", "PUBLISHED", 50, null);
        User student = user(1L, "learner@example.com", "Learner A");
        Question q0 = new Question();
        q0.setId(10L);
        q0.setOptions(List.of(questionOption(100L, false), questionOption(101L, true)));
        when(examRepository.findById(1L)).thenReturn(Optional.of(e));
        when(userRepository.findById(1L)).thenReturn(Optional.of(student));
        when(examAttemptRepository.countByExamIdAndStudentId(1L, 1L)).thenReturn(0);
        when(questionRepository.findByExamIdOrderByQuestionOrder(1L)).thenReturn(List.of(q0));
        ArgumentCaptor<ExamAttempt> captor = ArgumentCaptor.forClass(ExamAttempt.class);
        when(examAttemptRepository.save(captor.capture())).thenAnswer(inv -> inv.getArgument(0));

        Map<String, Object> rawAnswer = Map.of("selectedOption", "1");
        ExamAttemptResponseDTO response = examService.saveExamAttempt(1L, 1L,
                ExamAttemptRequestDTO.builder().score(new BigDecimal("7.0")).answers(Map.of("1", rawAnswer)).build());

        String persistedJson = captor.getValue().getAnswersJson();
        assertTrue(persistedJson.trim().startsWith("["), "answersJson persisted to DB should be a JSON array: " + persistedJson);
        assertTrue(persistedJson.contains("\"questionId\":0"));

        assertEquals(1, response.getAnswers().get("1"));
        assertTrue(response.getCorrectness().get("1"));
    }

    @Test
    void saveExamAttemptShouldLookUpExamAndUserByGivenIds() {
        Exam e = exam(1L, "Exam A", "PUBLISHED", 50, null);
        User student = user(1L, "learner@example.com", "Learner A");
        when(examRepository.findById(anyLong())).thenReturn(Optional.of(e));
        when(userRepository.findById(anyLong())).thenReturn(Optional.of(student));
        when(examAttemptRepository.countByExamIdAndStudentId(anyLong(), anyLong())).thenReturn(0);
        when(questionRepository.findByExamIdOrderByQuestionOrder(anyLong())).thenReturn(List.of());
        when(examAttemptRepository.save(any(ExamAttempt.class))).thenAnswer(inv -> inv.getArgument(0));

        examService.saveExamAttempt(1L, 1L, ExamAttemptRequestDTO.builder().score(new BigDecimal("7.0")).build());

        org.mockito.Mockito.verify(examRepository).findById(1L);
        org.mockito.Mockito.verify(userRepository).findById(1L);
    }

    // =================================================================
    // getExamQuestions
    // =================================================================

    @Test
    void getExamQuestionsShouldReturnEmptyListWhenExamHasNoQuestions() {
        when(questionRepository.findByExamIdOrderByQuestionOrder(1L)).thenReturn(List.of());

        List<LearnerExamQuestionDTO> result = examService.getExamQuestions(1L);

        assertTrue(result.isEmpty());
    }

    @Test
    void getExamQuestionsShouldMapContentSkillAndOptionsWithoutExposingIsCorrect() {
        Question q = new Question();
        q.setId(10L);
        q.setQuestionText("What is the past tense of 'go'?");
        SystemParameter skill = SystemParameter.builder().id(1L).paramValue("Grammar").build();
        q.setSkillParam(skill);
        QuestionOption wrong = questionOption(100L, false);
        wrong.setOptionText("Goed");
        QuestionOption correct = questionOption(101L, true);
        correct.setOptionText("Went");
        q.setOptions(List.of(wrong, correct));
        when(questionRepository.findByExamIdOrderByQuestionOrder(1L)).thenReturn(List.of(q));

        List<LearnerExamQuestionDTO> result = examService.getExamQuestions(1L);

        assertEquals(1, result.size());
        LearnerExamQuestionDTO dto = result.get(0);
        assertEquals(10L, dto.getId());
        assertEquals("What is the past tense of 'go'?", dto.getContent());
        assertEquals("Grammar", dto.getSkill());
        assertEquals(2, dto.getOptions().size());
        assertEquals("Goed", dto.getOptions().get(0).getOptionText());
        assertEquals(101L, dto.getOptions().get(1).getId());
    }

    @Test
    void getExamQuestionsShouldDefaultSkillToGeneralWhenSkillParamMissing() {
        Question q = new Question();
        q.setId(11L);
        q.setQuestionText("Choose the correct synonym.");
        q.setOptions(List.of());
        when(questionRepository.findByExamIdOrderByQuestionOrder(1L)).thenReturn(List.of(q));

        List<LearnerExamQuestionDTO> result = examService.getExamQuestions(1L);

        assertEquals("General", result.get(0).getSkill());
    }

    @Test
    void getExamQuestionsShouldOmitGroupWhenQuestionHasNoQuestionGroup() {
        Question q = new Question();
        q.setId(12L);
        q.setQuestionText("Standalone question");
        q.setOptions(List.of());
        when(questionRepository.findByExamIdOrderByQuestionOrder(1L)).thenReturn(List.of(q));

        List<LearnerExamQuestionDTO> result = examService.getExamQuestions(1L);

        assertEquals(null, result.get(0).getGroup());
    }

    @Test
    void getExamQuestionsShouldIncludeGroupPassageWhenQuestionBelongsToAGroup() {
        QuestionGroup group = new QuestionGroup();
        group.setId(5L);
        group.setContextText("Read the passage below and answer the questions.");
        Question q = new Question();
        q.setId(13L);
        q.setQuestionText("According to the passage, what is true?");
        q.setQuestionGroup(group);
        q.setOptions(List.of());
        when(questionRepository.findByExamIdOrderByQuestionOrder(1L)).thenReturn(List.of(q));

        List<LearnerExamQuestionDTO> result = examService.getExamQuestions(1L);

        assertEquals(5L, result.get(0).getGroup().getId());
        assertEquals("Read the passage below and answer the questions.", result.get(0).getGroup().getPassage());
    }
}
