package com.hango.hango_backend.service;

import java.time.LocalDateTime;
import java.util.List;
import java.util.Map;
import java.util.Optional;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import static org.mockito.ArgumentMatchers.any;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jdbc.core.RowMapper;

import com.hango.hango_backend.dto.LessonDetailDTO;
import com.hango.hango_backend.dto.LessonQuizAttemptDTO;
import com.hango.hango_backend.dto.LessonQuizAttemptRequestDTO;
import com.hango.hango_backend.dto.QuizQuestionDTO;
import com.hango.hango_backend.entity.Course;
import com.hango.hango_backend.entity.Enrollment;
import com.hango.hango_backend.entity.Lesson;
import com.hango.hango_backend.entity.LessonProgress;
import com.hango.hango_backend.entity.LessonQuizAttempt;
import com.hango.hango_backend.entity.Section;
import com.hango.hango_backend.entity.User;
import com.hango.hango_backend.repository.EnrollmentRepository;
import com.hango.hango_backend.repository.LessonProgressRepository;
import com.hango.hango_backend.repository.LessonQuizAttemptRepository;

import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.eq;
import com.hango.hango_backend.repository.LessonRepository;
import com.hango.hango_backend.repository.UserRepository;

@ExtendWith(MockitoExtension.class)
class LessonServiceTest {

    @Mock
    private LessonRepository lessonRepository;
    @Mock
    private CommentService commentService;
    @Mock
    private JdbcTemplate jdbcTemplate;
    @Mock
    private LessonQuizAttemptRepository quizAttemptRepository;
    @Mock
    private UserRepository userRepository;
    @Mock
    private LessonProgressRepository lessonProgressRepository;
    @Mock
    private EnrollmentRepository enrollmentRepository;

    @InjectMocks
    private LessonServiceImpl lessonService;

    private User user(Long id) {
        return User.builder().id(id).email("learner@example.com").build();
    }

    private Course course(Long id) {
        return Course.builder().id(id).title("Course").build();
    }

    private Lesson lesson(Long id, Course c) {
        Section section = Section.builder().id(1L).course(c).build();
        return Lesson.builder().id(id).title("Lesson").section(section).build();
    }

    // =================================================================
    // completeLesson
    // =================================================================

    @Test
    void completeLessonShouldThrowWhenUserNotFound() {
        when(userRepository.findById(1L)).thenReturn(Optional.empty());

        assertThrows(RuntimeException.class, () -> lessonService.completeLesson(1L, 1L, true));
    }

    @Test
    void completeLessonShouldThrowWhenLessonNotFound() {
        when(userRepository.findById(1L)).thenReturn(Optional.of(user(1L)));
        when(lessonRepository.findById(1L)).thenReturn(Optional.empty());

        assertThrows(RuntimeException.class, () -> lessonService.completeLesson(1L, 1L, true));
    }

    @Test
    void completeLessonShouldCreateProgressRowWhenNoPriorProgressExists() {
        Course c = course(10L);
        Lesson l = lesson(1L, c);
        when(userRepository.findById(1L)).thenReturn(Optional.of(user(1L)));
        when(lessonRepository.findById(1L)).thenReturn(Optional.of(l));
        when(lessonProgressRepository.findByUserIdAndLessonId(1L, 1L)).thenReturn(Optional.empty());
        when(enrollmentRepository.findByUserIdAndCourseIdWithLock(1L, 10L)).thenReturn(Optional.empty());

        lessonService.completeLesson(1L, 1L, true);

        ArgumentCaptor<LessonProgress> captor = ArgumentCaptor.forClass(LessonProgress.class);
        verify(lessonProgressRepository).save(captor.capture());
        assertTrue(captor.getValue().isCompleted());
        assertNull(captor.getValue().getId());
    }

    @Test
    void completeLessonShouldReturnEarlyWithoutSavingWhenAlreadyInRequestedState() {
        Course c = course(10L);
        Lesson l = lesson(1L, c);
        LessonProgress existing = LessonProgress.builder().id(5L).isCompleted(true).build();
        when(userRepository.findById(1L)).thenReturn(Optional.of(user(1L)));
        when(lessonRepository.findById(1L)).thenReturn(Optional.of(l));
        when(lessonProgressRepository.findByUserIdAndLessonId(1L, 1L)).thenReturn(Optional.of(existing));

        lessonService.completeLesson(1L, 1L, true);

        verify(lessonProgressRepository, never()).save(any());
        verify(enrollmentRepository, never()).findByUserIdAndCourseIdWithLock(any(), any());
    }

    @Test
    void completeLessonShouldMarkEnrollmentCompletedWhenAllLessonsCompleted() {
        Course c = course(10L);
        Lesson l = lesson(1L, c);
        LessonProgress existing = LessonProgress.builder().id(5L).isCompleted(false).build();
        Enrollment enrollment = Enrollment.builder().id(1L).status("ENROLLED").build();
        when(userRepository.findById(1L)).thenReturn(Optional.of(user(1L)));
        when(lessonRepository.findById(1L)).thenReturn(Optional.of(l));
        when(lessonProgressRepository.findByUserIdAndLessonId(1L, 1L)).thenReturn(Optional.of(existing));
        when(enrollmentRepository.findByUserIdAndCourseIdWithLock(1L, 10L)).thenReturn(Optional.of(enrollment));
        when(lessonRepository.countByCourseId(10L)).thenReturn(4L);
        when(lessonProgressRepository.countCompletedLessonsByUserIdAndCourseId(1L, 10L)).thenReturn(4L);

        lessonService.completeLesson(1L, 1L, true);

        ArgumentCaptor<Enrollment> captor = ArgumentCaptor.forClass(Enrollment.class);
        verify(enrollmentRepository).save(captor.capture());
        assertEquals("COMPLETED", captor.getValue().getStatus());
        assertTrue(captor.getValue().getProgressPercentage().doubleValue() == 100.0);
    }

    @Test
    void completeLessonShouldKeepEnrollmentStatusEnrolledWhenNotAllLessonsCompleted() {
        Course c = course(10L);
        Lesson l = lesson(1L, c);
        LessonProgress existing = LessonProgress.builder().id(5L).isCompleted(false).build();
        Enrollment enrollment = Enrollment.builder().id(1L).status("COMPLETED").build();
        when(userRepository.findById(1L)).thenReturn(Optional.of(user(1L)));
        when(lessonRepository.findById(1L)).thenReturn(Optional.of(l));
        when(lessonProgressRepository.findByUserIdAndLessonId(1L, 1L)).thenReturn(Optional.of(existing));
        when(enrollmentRepository.findByUserIdAndCourseIdWithLock(1L, 10L)).thenReturn(Optional.of(enrollment));
        when(lessonRepository.countByCourseId(10L)).thenReturn(4L);
        when(lessonProgressRepository.countCompletedLessonsByUserIdAndCourseId(1L, 10L)).thenReturn(2L);

        lessonService.completeLesson(1L, 1L, true);

        ArgumentCaptor<Enrollment> captor = ArgumentCaptor.forClass(Enrollment.class);
        verify(enrollmentRepository).save(captor.capture());
        assertEquals("ENROLLED", captor.getValue().getStatus());
        assertNull(captor.getValue().getCompletedAt());
    }

    @Test
    void completeLessonShouldSkipEnrollmentUpdateWhenUserNotEnrolled() {
        Course c = course(10L);
        Lesson l = lesson(1L, c);
        LessonProgress existing = LessonProgress.builder().id(5L).isCompleted(false).build();
        when(userRepository.findById(1L)).thenReturn(Optional.of(user(1L)));
        when(lessonRepository.findById(1L)).thenReturn(Optional.of(l));
        when(lessonProgressRepository.findByUserIdAndLessonId(1L, 1L)).thenReturn(Optional.of(existing));
        when(enrollmentRepository.findByUserIdAndCourseIdWithLock(1L, 10L)).thenReturn(Optional.empty());

        lessonService.completeLesson(1L, 1L, true);

        verify(enrollmentRepository, never()).save(any());
    }

    @Test
    void completeLessonShouldSkipEnrollmentUpdateWhenCourseHasZeroLessons() {
        Course c = course(10L);
        Lesson l = lesson(1L, c);
        LessonProgress existing = LessonProgress.builder().id(5L).isCompleted(false).build();
        Enrollment enrollment = Enrollment.builder().id(1L).status("ENROLLED").build();
        when(userRepository.findById(1L)).thenReturn(Optional.of(user(1L)));
        when(lessonRepository.findById(1L)).thenReturn(Optional.of(l));
        when(lessonProgressRepository.findByUserIdAndLessonId(1L, 1L)).thenReturn(Optional.of(existing));
        when(enrollmentRepository.findByUserIdAndCourseIdWithLock(1L, 10L)).thenReturn(Optional.of(enrollment));
        when(lessonRepository.countByCourseId(10L)).thenReturn(0L);

        lessonService.completeLesson(1L, 1L, true);

        verify(enrollmentRepository, never()).save(any());
    }

    @Test
    void completeLessonShouldClearCompletedAtWhenMarkingIncomplete() {
        Course c = course(10L);
        Lesson l = lesson(1L, c);
        LessonProgress existing = LessonProgress.builder().id(5L).isCompleted(true).completedAt(LocalDateTime.now()).build();
        when(userRepository.findById(1L)).thenReturn(Optional.of(user(1L)));
        when(lessonRepository.findById(1L)).thenReturn(Optional.of(l));
        when(lessonProgressRepository.findByUserIdAndLessonId(1L, 1L)).thenReturn(Optional.of(existing));
        when(enrollmentRepository.findByUserIdAndCourseIdWithLock(1L, 10L)).thenReturn(Optional.empty());

        lessonService.completeLesson(1L, 1L, false);

        ArgumentCaptor<LessonProgress> captor = ArgumentCaptor.forClass(LessonProgress.class);
        verify(lessonProgressRepository).save(captor.capture());
        assertTrue(!captor.getValue().isCompleted());
        assertNull(captor.getValue().getCompletedAt());
    }

    // =================================================================
    // saveQuizAttempt
    // =================================================================

    @Test
    void saveQuizAttemptShouldThrowWhenLessonNotFound() {
        when(lessonRepository.findById(1L)).thenReturn(Optional.empty());

        assertThrows(RuntimeException.class,
                () -> lessonService.saveQuizAttempt(1L, 1L, LessonQuizAttemptRequestDTO.builder().score(8.0).build()));
    }

    @Test
    void saveQuizAttemptShouldThrowWhenUserNotFound() {
        when(lessonRepository.findById(1L)).thenReturn(Optional.of(lesson(1L, course(10L))));
        when(userRepository.findById(1L)).thenReturn(Optional.empty());

        assertThrows(RuntimeException.class,
                () -> lessonService.saveQuizAttempt(1L, 1L, LessonQuizAttemptRequestDTO.builder().score(8.0).build()));
    }

    @Test
    void saveQuizAttemptShouldComputeNextAttemptNumberFromExistingCount() {
        Lesson l = lesson(1L, course(10L));
        when(lessonRepository.findById(1L)).thenReturn(Optional.of(l));
        when(userRepository.findById(1L)).thenReturn(Optional.of(user(1L)));
        when(quizAttemptRepository.countByLessonIdAndStudentId(1L, 1L)).thenReturn(2);
        when(quizAttemptRepository.save(any(LessonQuizAttempt.class))).thenAnswer(inv -> inv.getArgument(0));
        when(lessonProgressRepository.findByUserIdAndLessonId(1L, 1L)).thenReturn(Optional.empty());
        when(enrollmentRepository.findByUserIdAndCourseIdWithLock(1L, 10L)).thenReturn(Optional.empty());

        LessonQuizAttemptDTO result = lessonService.saveQuizAttempt(1L, 1L, LessonQuizAttemptRequestDTO.builder().score(8.0).build());

        assertEquals(3, result.getAttemptNumber());
    }

    @Test
    void saveQuizAttemptShouldDefaultStateToFinishedWhenNotProvided() {
        Lesson l = lesson(1L, course(10L));
        when(lessonRepository.findById(1L)).thenReturn(Optional.of(l));
        when(userRepository.findById(1L)).thenReturn(Optional.of(user(1L)));
        when(quizAttemptRepository.countByLessonIdAndStudentId(1L, 1L)).thenReturn(0);
        when(quizAttemptRepository.save(any(LessonQuizAttempt.class))).thenAnswer(inv -> inv.getArgument(0));
        when(lessonProgressRepository.findByUserIdAndLessonId(1L, 1L)).thenReturn(Optional.empty());
        when(enrollmentRepository.findByUserIdAndCourseIdWithLock(1L, 10L)).thenReturn(Optional.empty());

        LessonQuizAttemptDTO result = lessonService.saveQuizAttempt(1L, 1L, LessonQuizAttemptRequestDTO.builder().score(8.0).build());

        assertEquals("Finished", result.getState());
    }

    @Test
    void saveQuizAttemptShouldAutoCompleteLessonAsSideEffect() {
        Lesson l = lesson(1L, course(10L));
        when(lessonRepository.findById(1L)).thenReturn(Optional.of(l));
        when(userRepository.findById(1L)).thenReturn(Optional.of(user(1L)));
        when(quizAttemptRepository.countByLessonIdAndStudentId(1L, 1L)).thenReturn(0);
        when(quizAttemptRepository.save(any(LessonQuizAttempt.class))).thenAnswer(inv -> inv.getArgument(0));
        when(lessonProgressRepository.findByUserIdAndLessonId(1L, 1L)).thenReturn(Optional.empty());
        when(enrollmentRepository.findByUserIdAndCourseIdWithLock(1L, 10L)).thenReturn(Optional.empty());

        lessonService.saveQuizAttempt(1L, 1L, LessonQuizAttemptRequestDTO.builder().score(8.0).build());

        ArgumentCaptor<LessonProgress> captor = ArgumentCaptor.forClass(LessonProgress.class);
        verify(lessonProgressRepository).save(captor.capture());
        assertTrue(captor.getValue().isCompleted());
    }

    @Test
    void saveQuizAttemptShouldSwallowExceptionFromAutoCompleteLessonAndStillReturnResult() {
        Lesson l = lesson(1L, course(10L));
        when(lessonRepository.findById(1L)).thenReturn(Optional.of(l));
        when(userRepository.findById(1L)).thenReturn(Optional.of(user(1L)));
        when(quizAttemptRepository.countByLessonIdAndStudentId(1L, 1L)).thenReturn(0);
        when(quizAttemptRepository.save(any(LessonQuizAttempt.class))).thenAnswer(inv -> inv.getArgument(0));
        when(lessonProgressRepository.findByUserIdAndLessonId(1L, 1L)).thenThrow(new RuntimeException("DB down"));

        LessonQuizAttemptDTO result = lessonService.saveQuizAttempt(1L, 1L, LessonQuizAttemptRequestDTO.builder().score(8.0).build());

        assertEquals(1, result.getAttemptNumber());
    }

    // =================================================================
    // getQuizAttempts
    // =================================================================

    @Test
    void getQuizAttemptsShouldMapAttemptsWithParsedAnswers() throws Exception {
        LessonQuizAttempt attempt = LessonQuizAttempt.builder()
                .attemptNumber(1)
                .state("Finished")
                .score(8.5)
                .answersJson("{\"1\":2,\"2\":1}")
                .submittedAt(LocalDateTime.of(2026, 7, 17, 10, 30))
                .build();
        when(quizAttemptRepository.findByLessonIdAndStudentIdOrderByAttemptNumberAsc(1L, 1L)).thenReturn(List.of(attempt));

        List<LessonQuizAttemptDTO> result = lessonService.getQuizAttempts(1L, 1L);

        assertEquals(1, result.size());
        assertEquals(Map.of("1", 2, "2", 1), result.get(0).getAnswers());
        assertEquals("8.5 / 10.0", result.get(0).getGrade());
    }

    @Test
    void getQuizAttemptsShouldLeaveAnswersNullWhenAnswersJsonIsNull() {
        LessonQuizAttempt attempt = LessonQuizAttempt.builder()
                .attemptNumber(1)
                .state("Finished")
                .score(8.5)
                .answersJson(null)
                .submittedAt(LocalDateTime.now())
                .build();
        when(quizAttemptRepository.findByLessonIdAndStudentIdOrderByAttemptNumberAsc(1L, 1L)).thenReturn(List.of(attempt));

        List<LessonQuizAttemptDTO> result = lessonService.getQuizAttempts(1L, 1L);

        assertNull(result.get(0).getAnswers());
    }

    // =================================================================
    // getLessonDetail
    // =================================================================

    @SuppressWarnings("unchecked")
    private void stubJdbcQuestions(List<QuizQuestionDTO> questions) {
        when(jdbcTemplate.query(anyString(), any(RowMapper.class), eq(1L))).thenReturn(questions);
    }

    @Test
    void getLessonDetailShouldThrowWhenLessonNotFound() {
        when(lessonRepository.findById(1L)).thenReturn(Optional.empty());

        assertThrows(RuntimeException.class, () -> lessonService.getLessonDetail(1L, 1L));
    }

    @Test
    void getLessonDetailShouldMapFieldsFromLessonSectionAndCourse() {
        Course c = course(10L);
        Lesson l = lesson(1L, c);
        when(lessonRepository.findById(1L)).thenReturn(Optional.of(l));
        when(commentService.getCommentsByLesson(1L, 1L)).thenReturn(List.of());
        stubJdbcQuestions(List.of());
        when(lessonProgressRepository.existsByUserIdAndLessonIdAndIsCompletedTrue(1L, 1L)).thenReturn(false);

        LessonDetailDTO result = lessonService.getLessonDetail(1L, 1L);

        assertEquals(1L, result.getId());
        assertEquals(1L, result.getSectionId());
        assertEquals(10L, result.getCourseId());
    }

    @Test
    void getLessonDetailShouldNotCheckCompletionWhenUserIdNull() {
        Lesson l = lesson(1L, course(10L));
        when(lessonRepository.findById(1L)).thenReturn(Optional.of(l));
        when(commentService.getCommentsByLesson(1L, null)).thenReturn(List.of());
        stubJdbcQuestions(List.of());

        LessonDetailDTO result = lessonService.getLessonDetail(1L, null);

        assertFalse(result.getIsCompleted());
        verify(lessonProgressRepository, never()).existsByUserIdAndLessonIdAndIsCompletedTrue(any(), any());
    }

    @Test
    void getLessonDetailShouldMarkIsCompletedTrueWhenProgressRecordExists() {
        Lesson l = lesson(1L, course(10L));
        when(lessonRepository.findById(1L)).thenReturn(Optional.of(l));
        when(commentService.getCommentsByLesson(1L, 1L)).thenReturn(List.of());
        stubJdbcQuestions(List.of());
        when(lessonProgressRepository.existsByUserIdAndLessonIdAndIsCompletedTrue(1L, 1L)).thenReturn(true);

        LessonDetailDTO result = lessonService.getLessonDetail(1L, 1L);

        assertTrue(result.getIsCompleted());
    }

    @Test
    void getLessonDetailShouldIncludeQuizQuestionsFromJdbcQuery() {
        Lesson l = lesson(1L, course(10L));
        when(lessonRepository.findById(1L)).thenReturn(Optional.of(l));
        when(commentService.getCommentsByLesson(1L, 1L)).thenReturn(List.of());
        QuizQuestionDTO question = QuizQuestionDTO.builder().id(99L).questionText("2+2?").options(List.of("3", "4")).correctIndex(1).build();
        stubJdbcQuestions(List.of(question));
        when(lessonProgressRepository.existsByUserIdAndLessonIdAndIsCompletedTrue(1L, 1L)).thenReturn(false);

        LessonDetailDTO result = lessonService.getLessonDetail(1L, 1L);

        assertEquals(1, result.getQuestions().size());
        assertEquals("2+2?", result.getQuestions().get(0).getQuestionText());
    }

    @Test
    void getLessonDetailShouldLeaveSectionAndCourseIdNullWhenSectionMissing() {
        Lesson l = Lesson.builder().id(1L).title("Orphan lesson").section(null).build();
        when(lessonRepository.findById(1L)).thenReturn(Optional.of(l));
        when(commentService.getCommentsByLesson(1L, 1L)).thenReturn(List.of());
        stubJdbcQuestions(List.of());
        when(lessonProgressRepository.existsByUserIdAndLessonIdAndIsCompletedTrue(1L, 1L)).thenReturn(false);

        LessonDetailDTO result = lessonService.getLessonDetail(1L, 1L);

        assertNull(result.getSectionId());
        assertNull(result.getCourseId());
    }
}
