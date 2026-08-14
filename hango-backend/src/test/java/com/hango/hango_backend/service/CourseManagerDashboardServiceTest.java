package com.hango.hango_backend.service;

import com.hango.hango_backend.dto.CourseManagerDashboardSummaryDTO;
import com.hango.hango_backend.dto.CourseReviewDetailDTO;
import com.hango.hango_backend.dto.ExamResponseDTO;
import com.hango.hango_backend.entity.Course;
import com.hango.hango_backend.entity.Enrollment;
import com.hango.hango_backend.entity.Exam;
import com.hango.hango_backend.entity.Lesson;
import com.hango.hango_backend.entity.Section;
import com.hango.hango_backend.entity.User;
import com.hango.hango_backend.repository.CourseRepository;
import com.hango.hango_backend.repository.EnrollmentRepository;
import com.hango.hango_backend.repository.ExamRepository;
import com.hango.hango_backend.repository.LessonRepository;
import com.hango.hango_backend.repository.SectionRepository;
import com.hango.hango_backend.repository.UserRepository;
import com.hango.hango_backend.service.impl.CourseManagerDashboardServiceImpl;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.time.LocalDateTime;
import java.util.Arrays;
import java.util.List;
import java.util.Optional;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class CourseManagerDashboardServiceTest {

    @Mock
    private UserRepository userRepository;
    @Mock
    private CourseRepository courseRepository;
    @Mock
    private ExamRepository examRepository;
    @Mock
    private EnrollmentRepository enrollmentRepository;
    @Mock
    private NotificationService notificationService;
    @Mock
    private SectionRepository sectionRepository;
    @Mock
    private LessonRepository lessonRepository;
    @Mock
    private ExamHistoryService examHistoryService;

    @InjectMocks
    private CourseManagerDashboardServiceImpl service;

    private User user(Long id) {
        return User.builder().id(id).email("user" + id + "@example.com").fullName("User " + id).build();
    }

    private Course course(Long id, String status, User creator) {
        return Course.builder().id(id).title("Course " + id).status(status).creator(creator).build();
    }

    // =================================================================
    // getDashboardSummary
    // =================================================================

    @Test
    void getDashboardSummaryShouldMapRegisteredUsersAndCourseStatusCounts() {
        when(userRepository.countByRoleName("LEARNER")).thenReturn(150L);
        when(courseRepository.countByStatusAndDeletedAtIsNull("PUBLISHED")).thenReturn(20L);
        when(courseRepository.countByStatusAndDeletedAtIsNull("DRAFT")).thenReturn(5L);
        when(courseRepository.countByStatusAndDeletedAtIsNull("ARCHIVED")).thenReturn(3L);
        when(courseRepository.countByStatusAndDeletedAtIsNull("HIDDEN")).thenReturn(2L);
        when(courseRepository.countByStatusAndDeletedAtIsNull("PENDING")).thenReturn(0L);
        when(examRepository.count()).thenReturn(40L);

        CourseManagerDashboardSummaryDTO result = service.getDashboardSummary();

        assertEquals(150L, result.getRegisteredUsersCount());
        assertEquals(20L, result.getActiveCoursesCount());
        assertEquals(10L, result.getInactiveCoursesCount());
        assertEquals(40L, result.getExamsCount());
    }

    // =================================================================
    // publishCourse
    // =================================================================

    @Test
    void publishCourseShouldThrowWhenNotPendingApproval() {
        Course c = course(1L, "DRAFT", user(2L));
        when(courseRepository.findById(1L)).thenReturn(Optional.of(c));

        assertThrows(RuntimeException.class, () -> service.publishCourse(1L));
        verify(notificationService, never()).notifyUser(any(), any(), any(), any(), any());
    }

    @Test
    void publishCourseShouldNotifyCreatorWhenPublished() {
        User creator = user(2L);
        Course c = course(1L, "PENDING_APPROVAL", creator);
        when(courseRepository.findById(1L)).thenReturn(Optional.of(c));

        service.publishCourse(1L);

        assertEquals("PUBLISHED", c.getStatus());
        verify(notificationService).notifyUser(eq(creator), eq(NotificationService.TYPE_CONTENT_APPROVED), any(), any(), eq(c));
    }

    @Test
    void publishCourseShouldNotifyPriorVersionEnrolleesOfCourseUpdateWhenNewVersion() {
        User creator = user(2L);
        Course v1 = course(10L, "PUBLISHED", creator);
        Course v2 = course(11L, "PENDING_APPROVAL", creator);
        v2.setParentId(10L);
        v2.setCode("ENG-101");
        when(courseRepository.findById(11L)).thenReturn(Optional.of(v2));
        when(courseRepository.findById(10L)).thenReturn(Optional.of(v1));
        when(courseRepository.findByCodeAndDeletedAtIsNullOrderByCreatedAtDesc("ENG-101"))
                .thenReturn(List.of(v2, v1));
        User learner = user(5L);
        Enrollment enrollment = Enrollment.builder().user(learner).course(v1).build();
        when(enrollmentRepository.findByCourseIdIn(List.of(10L))).thenReturn(List.of(enrollment));

        service.publishCourse(11L);

        verify(notificationService).notifyUser(eq(learner), eq(NotificationService.TYPE_COURSE_UPDATED), any(), any(), eq(v2));
    }

    // =================================================================
    // rejectCourse
    // =================================================================

    @Test
    void rejectCourseShouldThrowWhenNotPendingApproval() {
        Course c = course(1L, "DRAFT", user(2L));
        when(courseRepository.findById(1L)).thenReturn(Optional.of(c));

        assertThrows(RuntimeException.class, () -> service.rejectCourse(1L, "Reason"));
        verify(notificationService, never()).notifyUser(any(), any(), any(), any(), any());
    }

    @Test
    void rejectCourseShouldNotifyCreator() {
        User creator = user(2L);
        Course c = course(1L, "PENDING_APPROVAL", creator);
        when(courseRepository.findById(1L)).thenReturn(Optional.of(c));

        service.rejectCourse(1L, "Some reason");

        assertEquals("REJECTED", c.getStatus());
        assertEquals("Some reason", c.getRejectionReason());
        verify(notificationService).notifyUser(eq(creator), eq(NotificationService.TYPE_CONTENT_REJECTED), any(), any(), eq(c));
    }

    // =================================================================
    // hideCourse
    // =================================================================

    @Test
    void hideCourseShouldThrowWhenCourseNotFound() {
        when(courseRepository.findById(1L)).thenReturn(Optional.empty());

        assertThrows(RuntimeException.class, () -> service.hideCourse(1L));
    }

    @Test
    void hideCourseShouldThrowWhenNotPublished() {
        Course c = course(1L, "DRAFT", user(2L));
        when(courseRepository.findById(1L)).thenReturn(Optional.of(c));

        assertThrows(RuntimeException.class, () -> service.hideCourse(1L));
        verify(courseRepository, never()).save(any());
    }

    @Test
    void hideCourseShouldSetStatusHiddenWhenPublished() {
        Course c = course(1L, "PUBLISHED", user(2L));
        when(courseRepository.findById(1L)).thenReturn(Optional.of(c));

        service.hideCourse(1L);

        assertEquals("HIDDEN", c.getStatus());
        verify(courseRepository).save(c);
    }

    // =================================================================
    // unhideCourse
    // =================================================================

    @Test
    void unhideCourseShouldThrowWhenCourseNotFound() {
        when(courseRepository.findById(1L)).thenReturn(Optional.empty());

        assertThrows(RuntimeException.class, () -> service.unhideCourse(1L));
    }

    @Test
    void unhideCourseShouldThrowWhenNeitherHiddenNorArchived() {
        Course c = course(1L, "PUBLISHED", user(2L));
        when(courseRepository.findById(1L)).thenReturn(Optional.of(c));

        assertThrows(RuntimeException.class, () -> service.unhideCourse(1L));
        verify(courseRepository, never()).save(any());
    }

    @Test
    void unhideCourseShouldSetStatusPublishedWhenHidden() {
        Course c = course(1L, "HIDDEN", user(2L));
        when(courseRepository.findById(1L)).thenReturn(Optional.of(c));

        service.unhideCourse(1L);

        assertEquals("PUBLISHED", c.getStatus());
        verify(courseRepository).save(c);
    }

    @Test
    void unhideCourseShouldSetStatusPublishedWhenArchived() {
        Course c = course(1L, "ARCHIVED", user(2L));
        when(courseRepository.findById(1L)).thenReturn(Optional.of(c));

        service.unhideCourse(1L);

        assertEquals("PUBLISHED", c.getStatus());
    }

    // =================================================================
    // publishExam
    // =================================================================

    @Test
    void publishExamShouldThrowWhenNotPendingOrSubmitted() {
        Exam exam = new Exam();
        exam.setId(1L);
        exam.setStatus("DRAFT");
        when(examRepository.findById(1L)).thenReturn(Optional.of(exam));

        assertThrows(RuntimeException.class, () -> service.publishExam(1L));
        verify(notificationService, never()).notifyUser(any(), any(), any(), any(), any());
    }

    @Test
    void publishExamShouldNotifyCreator() {
        User creator = user(3L);
        Exam exam = new Exam();
        exam.setId(1L);
        exam.setTitle("Exam A");
        exam.setStatus("PENDING_APPROVAL");
        exam.setCreatedBy(creator);
        when(examRepository.findById(1L)).thenReturn(Optional.of(exam));

        service.publishExam(1L);

        assertEquals("PUBLISHED", exam.getStatus());
        ArgumentCaptor<String> typeCaptor = ArgumentCaptor.forClass(String.class);
        verify(notificationService).notifyUser(eq(creator), typeCaptor.capture(), any(), any(), any());
        assertEquals(NotificationService.TYPE_CONTENT_APPROVED, typeCaptor.getValue());
    }

    // =================================================================
    // returnExamToDraft
    // =================================================================

    @Test
    void returnExamToDraftShouldThrowWhenNotPendingOrSubmitted() {
        Exam exam = new Exam();
        exam.setId(1L);
        exam.setStatus("DRAFT");
        when(examRepository.findById(1L)).thenReturn(Optional.of(exam));

        assertThrows(RuntimeException.class, () -> service.returnExamToDraft(1L, "reason"));
        verify(notificationService, never()).notifyUser(any(), any(), any(), any(), any());
    }

    @Test
    void returnExamToDraftShouldNotifyCreatorWithReason() {
        User creator = user(3L);
        Exam exam = new Exam();
        exam.setId(1L);
        exam.setTitle("Exam A");
        exam.setStatus("PENDING_APPROVAL");
        exam.setCreatedBy(creator);
        when(examRepository.findById(1L)).thenReturn(Optional.of(exam));

        service.returnExamToDraft(1L, "Missing answer key");

        assertEquals("REJECTED", exam.getStatus());
        assertEquals("Missing answer key", exam.getRejectionReason());
        ArgumentCaptor<String> messageCaptor = ArgumentCaptor.forClass(String.class);
        verify(notificationService).notifyUser(eq(creator), eq(NotificationService.TYPE_CONTENT_REJECTED), any(), messageCaptor.capture(), any());
        assertEquals(true, messageCaptor.getValue().contains("Missing answer key"));
    }

    // =================================================================
    // getCoursesForReview
    // =================================================================

    @Test
    void getCoursesForReviewShouldDefaultToPendingApprovalStatusWhenStatusBlank() {
        when(courseRepository.findByStatusAndDeletedAtIsNullOrderByCreatedAtDesc(
                org.mockito.ArgumentMatchers.eq("PENDING_APPROVAL"), 
                org.mockito.ArgumentMatchers.any(org.springframework.data.domain.Pageable.class)))
                .thenReturn(new org.springframework.data.domain.PageImpl<>(List.of()));

        org.springframework.data.domain.Page<CourseReviewDetailDTO> result = service.getCoursesForReview(null, 0, 10);

        assertTrue(result.isEmpty());
        verify(courseRepository).findByStatusAndDeletedAtIsNullOrderByCreatedAtDesc(
                org.mockito.ArgumentMatchers.eq("PENDING_APPROVAL"), 
                org.mockito.ArgumentMatchers.any(org.springframework.data.domain.Pageable.class));
    }

    @Test
    void getCoursesForReviewShouldNormalizeSubmittedAliasToPendingApproval() {
        when(courseRepository.findByStatusAndDeletedAtIsNullOrderByCreatedAtDesc(
                org.mockito.ArgumentMatchers.eq("PENDING_APPROVAL"), 
                org.mockito.ArgumentMatchers.any(org.springframework.data.domain.Pageable.class)))
                .thenReturn(new org.springframework.data.domain.PageImpl<>(List.of()));

        service.getCoursesForReview("submitted", 0, 10);

        verify(courseRepository).findByStatusAndDeletedAtIsNullOrderByCreatedAtDesc(
                org.mockito.ArgumentMatchers.eq("PENDING_APPROVAL"), 
                org.mockito.ArgumentMatchers.any(org.springframework.data.domain.Pageable.class));
    }

    @Test
    void getCoursesForReviewShouldReturnAllNonDeletedCoursesSortedNewestFirstWhenStatusIsAll() {
        Course older = course(1L, "DRAFT", user(2L));
        older.setCreatedAt(LocalDateTime.of(2026, 1, 1, 0, 0));
        Course newer = course(2L, "PUBLISHED", user(2L));
        newer.setCreatedAt(LocalDateTime.of(2026, 2, 1, 0, 0));
        when(courseRepository.findByDeletedAtIsNullOrderByCreatedAtDesc(
                org.mockito.ArgumentMatchers.any(org.springframework.data.domain.Pageable.class)))
                .thenReturn(new org.springframework.data.domain.PageImpl<>(List.of(newer, older))); // Manual sorting simulation for page

        org.springframework.data.domain.Page<CourseReviewDetailDTO> result = service.getCoursesForReview("all", 0, 10);

        assertEquals(2L, result.getContent().get(0).getId());
        assertEquals(1L, result.getContent().get(1).getId());
    }

    @Test
    void getCoursesForReviewShouldMapCourseSummaryFieldsWithoutSessionDetail() {
        Course c = course(5L, "PENDING_APPROVAL", user(2L));
        when(courseRepository.findByStatusAndDeletedAtIsNullOrderByCreatedAtDesc(
                org.mockito.ArgumentMatchers.eq("PENDING_APPROVAL"), 
                org.mockito.ArgumentMatchers.any(org.springframework.data.domain.Pageable.class)))
                .thenReturn(new org.springframework.data.domain.PageImpl<>(List.of(c)));

        org.springframework.data.domain.Page<CourseReviewDetailDTO> result = service.getCoursesForReview(null, 0, 10);

        assertEquals("Course 5", result.getContent().get(0).getTitle());
        assertEquals(0, result.getContent().get(0).getSessions().size());
    }

    // =================================================================
    // getCourseReviewDetail
    // =================================================================

    @Test
    void getCourseReviewDetailShouldThrowWhenCourseNotFound() {
        when(courseRepository.findById(1L)).thenReturn(Optional.empty());

        assertThrows(RuntimeException.class, () -> service.getCourseReviewDetail(1L));
    }

    @Test
    void getCourseReviewDetailShouldThrowWhenCourseIsSoftDeleted() {
        Course deleted = course(1L, "PUBLISHED", user(2L));
        deleted.setDeletedAt(LocalDateTime.now());
        when(courseRepository.findById(1L)).thenReturn(Optional.of(deleted));

        assertThrows(RuntimeException.class, () -> service.getCourseReviewDetail(1L));
    }

    @Test
    void getCourseReviewDetailShouldIncludeSectionAndLessonDetail() {
        Course c = course(5L, "PENDING_APPROVAL", user(2L));
        when(courseRepository.findById(5L)).thenReturn(Optional.of(c));
        Section section = Section.builder().id(20L).title("Section A").displayOrder(1).build();
        when(sectionRepository.findByCourseIdOrderByDisplayOrderAsc(5L)).thenReturn(List.of(section));
        Lesson lesson = Lesson.builder().id(30L).title("Lesson A").displayOrder(1).build();
        when(lessonRepository.findBySectionIdOrderByDisplayOrderAsc(20L)).thenReturn(List.of(lesson));
        when(lessonRepository.countByCourseId(5L)).thenReturn(1L);

        CourseReviewDetailDTO result = service.getCourseReviewDetail(5L);

        assertEquals(1, result.getSessions().size());
        assertEquals("Section A", result.getSessions().get(0).getTitle());
        assertEquals(1, result.getSessions().get(0).getLessons().size());
        assertEquals("Lesson A", result.getSessions().get(0).getLessons().get(0).getTitle());
        assertEquals(1, result.getLessonsCount());
    }

    // =================================================================
    // getExamsForReview
    // =================================================================

    @Test
    void getExamsForReviewShouldReturnAllNonDeletedExamsWhenStatusIsAll() {
        when(examRepository.findByDeletedAtIsNullOrderByCreatedAtDesc()).thenReturn(List.of());

        List<ExamResponseDTO> result = service.getExamsForReview("all");

        assertTrue(result.isEmpty());
        verify(examRepository).findByDeletedAtIsNullOrderByCreatedAtDesc();
    }

    @Test
    void getExamsForReviewShouldQueryBothPendingApprovalAndSubmittedStatusesWhenDefaulted() {
        when(examRepository.findByStatusInAndDeletedAtIsNullOrderByCreatedAtDesc(Arrays.asList("PENDING_APPROVAL", "SUBMITTED")))
                .thenReturn(List.of());

        service.getExamsForReview(null);

        verify(examRepository).findByStatusInAndDeletedAtIsNullOrderByCreatedAtDesc(Arrays.asList("PENDING_APPROVAL", "SUBMITTED"));
    }

    @Test
    void getExamsForReviewShouldQuerySpecificStatusWhenNotPendingOrAll() {
        when(examRepository.findByStatusAndDeletedAtIsNullOrderByCreatedAtDesc("PUBLISHED")).thenReturn(List.of());

        service.getExamsForReview("published");

        verify(examRepository).findByStatusAndDeletedAtIsNullOrderByCreatedAtDesc("PUBLISHED");
    }

    @Test
    void getExamsForReviewShouldMapExpectedQuestionCountAndDefaultToZeroWhenNull() {
        Exam exam = new Exam();
        exam.setId(1L);
        exam.setTitle("Exam A");
        exam.setStatus("PENDING_APPROVAL");
        when(examRepository.findByStatusInAndDeletedAtIsNullOrderByCreatedAtDesc(any())).thenReturn(List.of(exam));

        List<ExamResponseDTO> result = service.getExamsForReview(null);

        assertEquals(0, result.get(0).getQuestionCount());
        assertEquals("Unknown", result.get(0).getCreatorName());
    }
}
