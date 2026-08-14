package com.hango.hango_backend.service;

import java.time.LocalDateTime;
import java.util.List;
import java.util.Map;
import java.util.Optional;

import org.junit.jupiter.api.AfterEach;
import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.ArgumentMatchers.isNull;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.context.SecurityContextHolder;

import com.hango.hango_backend.dto.CourseDetailDTO;
import com.hango.hango_backend.dto.CourseSummaryDTO;
import com.hango.hango_backend.entity.Course;
import com.hango.hango_backend.entity.Enrollment;
import com.hango.hango_backend.entity.Lesson;
import com.hango.hango_backend.entity.LessonProgress;
import com.hango.hango_backend.entity.Section;
import com.hango.hango_backend.entity.SystemParameter;
import com.hango.hango_backend.entity.TrainerProfile;
import com.hango.hango_backend.entity.User;
import com.hango.hango_backend.repository.CourseRatingRepository;
import com.hango.hango_backend.repository.CourseRepository;
import com.hango.hango_backend.repository.EnrollmentRepository;
import com.hango.hango_backend.repository.LessonProgressRepository;
import com.hango.hango_backend.repository.LessonRepository;
import com.hango.hango_backend.repository.SectionRepository;
import com.hango.hango_backend.repository.TrainerProfileRepository;
import com.hango.hango_backend.repository.UserRepository;
import com.hango.hango_backend.security.UserDetailsImpl;

@ExtendWith(MockitoExtension.class)
class CourseServiceTest {

    @Mock
    private CourseRepository courseRepository;
    @Mock
    private SectionRepository sectionRepository;
    @Mock
    private LessonRepository lessonRepository;
    @Mock
    private EnrollmentRepository enrollmentRepository;
    @Mock
    private UserRepository userRepository;
    @Mock
    private LessonProgressRepository lessonProgressRepository;
    @Mock
    private CourseRatingRepository courseRatingRepository;
    @Mock
    private TrainerProfileRepository trainerProfileRepository;
    @Mock
    private EmailService emailService;
    @Mock
    private NotificationService notificationService;
    @Mock
    private com.hango.hango_backend.repository.PathwayNodeRepository pathwayNodeRepository;

    @InjectMocks
    private CourseServiceImpl courseService;

    @AfterEach
    void clearSecurityContext() {
        SecurityContextHolder.clearContext();
    }

    private User trainer(Long id) {
        return User.builder().id(id).email("trainer@example.com").fullName("Trainer A").build();
    }

    private Course course(Long id, User creator) {
        return Course.builder().id(id).title("Course").creator(creator).status("PUBLISHED")
                .averageRating(0.0).totalRatings(0).build();
    }

    private Course course(Long id, User creator, double averageRating, int totalRatings) {
        return Course.builder().id(id).title("Course").creator(creator).status("PUBLISHED")
                .averageRating(averageRating).totalRatings(totalRatings).build();
    }

    private void authenticateAs(Long userId) {
        UserDetailsImpl principal = new UserDetailsImpl(userId, "learner@example.com", "Learner", "hash", List.of());
        SecurityContextHolder.getContext().setAuthentication(
                new UsernamePasswordAuthenticationToken(principal, null, List.of()));
    }

    // =================================================================
    // getCourses
    // =================================================================

    @Test
    void getCoursesShouldTreatDifficultyAllCaseInsensitiveAsNoFilter() {
        when(courseRepository.findCoursesWithFilters(eq("kw"), isNull(), isNull(), isNull()))
                .thenReturn(List.of());

        courseService.getCourses("kw", null, "all");

        verify(courseRepository).findCoursesWithFilters(eq("kw"), isNull(), isNull(), isNull());
    }

    @Test
    void getCoursesShouldUppercaseNonAllDifficultyFilter() {
        when(courseRepository.findCoursesWithFilters(any(), eq("EASY"), any(), any())).thenReturn(List.of());

        courseService.getCourses(null, null, "easy");

        verify(courseRepository).findCoursesWithFilters(any(), eq("EASY"), any(), any());
    }

    @Test
    void getCoursesShouldNotResolveUserWhenNoAuthenticationPresent() {
        when(courseRepository.findCoursesWithFilters(any(), any(), isNull(), any())).thenReturn(List.of());

        courseService.getCourses(null, "ENROLLED", null);

        verify(courseRepository).findCoursesWithFilters(any(), any(), isNull(), any());
    }

    @Test
    void getCoursesShouldResolveEnrolledUserIdFromSecurityContextWhenFilterTypeEnrolled() {
        authenticateAs(7L);
        when(courseRepository.findCoursesWithFilters(any(), any(), eq(7L), isNull())).thenReturn(List.of());

        courseService.getCourses(null, "ENROLLED", null);

        verify(courseRepository).findCoursesWithFilters(any(), any(), eq(7L), isNull());
    }

    @Test
    void getCoursesShouldSetEnrollmentStatusInProgressWhenFilterTypeInProgress() {
        authenticateAs(7L);
        when(courseRepository.findCoursesWithFilters(any(), any(), eq(7L), eq("ENROLLED"))).thenReturn(List.of());

        courseService.getCourses(null, "IN_PROGRESS", null);

        verify(courseRepository).findCoursesWithFilters(any(), any(), eq(7L), eq("ENROLLED"));
    }

    @Test
    void getCoursesShouldSetEnrollmentStatusCompletedWhenFilterTypeCompleted() {
        authenticateAs(7L);
        when(courseRepository.findCoursesWithFilters(any(), any(), eq(7L), eq("COMPLETED"))).thenReturn(List.of());

        courseService.getCourses(null, "COMPLETED", null);

        verify(courseRepository).findCoursesWithFilters(any(), any(), eq(7L), eq("COMPLETED"));
    }

    @Test
    void getCoursesShouldEnrichDtoCategoriesFromCourseCategoriesSet() {
        CourseSummaryDTO dto = CourseSummaryDTO.builder().id(1L).build();
        when(courseRepository.findCoursesWithFilters(any(), any(), any(), any())).thenReturn(List.of(dto));
        
        List<Object[]> categoryList = new java.util.ArrayList<>();
        categoryList.add(new Object[]{1L, "Grammar"});
        when(courseRepository.findCategoriesByCourseIds(any())).thenReturn(categoryList);

        List<CourseSummaryDTO> result = courseService.getCourses(null, null, null);

        assertEquals(List.of("Grammar"), result.get(0).getCategories());
        assertEquals("Grammar", result.get(0).getCategoryName());
    }

    @Test
    void getCoursesShouldFallBackToSingleCategoryWhenCategoriesSetEmpty() {
        CourseSummaryDTO dto = CourseSummaryDTO.builder().id(1L).categoryName("Reading").build();
        when(courseRepository.findCoursesWithFilters(any(), any(), any(), any())).thenReturn(List.of(dto));
        when(courseRepository.findCategoriesByCourseIds(any())).thenReturn(new java.util.ArrayList<>());

        List<CourseSummaryDTO> result = courseService.getCourses(null, null, null);

        assertEquals(List.of("Reading"), result.get(0).getCategories());
    }

    // =================================================================
    // getCourseDetail
    // =================================================================

    @Test
    void getCourseDetailShouldThrowWhenCourseNotFound() {
        when(courseRepository.findByIdWithDetails(99L)).thenReturn(Optional.empty());

        assertThrows(RuntimeException.class, () -> courseService.getCourseDetail(99L, 1L));
    }

    @Test
    void getCourseDetailShouldReadCachedAverageRatingAndTotalRatingsFromCourse() {
        Course c = course(1L, trainer(2L), 4.7, 3);
        when(courseRepository.findByIdWithDetails(1L)).thenReturn(Optional.of(c));
        when(sectionRepository.findByCourseIdOrderByDisplayOrderAsc(1L)).thenReturn(List.of());

        CourseDetailDTO result = courseService.getCourseDetail(1L, null);

        assertEquals(4.7, result.getRating());
        assertEquals(3, result.getTotalRatings());
    }

    @Test
    void getCourseDetailShouldReturnZeroRatingWhenNoRatingsExist() {
        Course c = course(1L, trainer(2L));
        when(courseRepository.findByIdWithDetails(1L)).thenReturn(Optional.of(c));
        when(sectionRepository.findByCourseIdOrderByDisplayOrderAsc(1L)).thenReturn(List.of());

        CourseDetailDTO result = courseService.getCourseDetail(1L, null);

        assertEquals(0.0, result.getRating());
        assertEquals(0, result.getTotalRatings());
    }

    @Test
    void getCourseDetailShouldMarkIsEnrolledTrueWhenEnrollmentExists() {
        Course c = course(1L, trainer(2L));
        when(courseRepository.findByIdWithDetails(1L)).thenReturn(Optional.of(c));
        when(sectionRepository.findByCourseIdOrderByDisplayOrderAsc(1L)).thenReturn(List.of());
        when(enrollmentRepository.findByUserIdAndCourseId(5L, 1L))
                .thenReturn(java.util.Optional.of(com.hango.hango_backend.entity.Enrollment.builder().build()));

        CourseDetailDTO result = courseService.getCourseDetail(1L, 5L);

        assertTrue(result.getIsEnrolled());
    }

    @Test
    void getCourseDetailShouldFallbackCreatorNameToUnknownTrainerWhenCreatorNull() {
        Course c = course(1L, null);
        when(courseRepository.findByIdWithDetails(1L)).thenReturn(Optional.of(c));
        when(sectionRepository.findByCourseIdOrderByDisplayOrderAsc(1L)).thenReturn(List.of());

        CourseDetailDTO result = courseService.getCourseDetail(1L, null);

        assertEquals("Unknown Trainer", result.getCreatorName());
    }

    @Test
    void getCourseDetailShouldThrowWhenCourseIsSoftDeleted() {
        Course c = course(1L, trainer(2L));
        c.setDeletedAt(LocalDateTime.now());
        when(courseRepository.findByIdWithDetails(1L)).thenReturn(Optional.of(c));

        assertThrows(RuntimeException.class, () -> courseService.getCourseDetail(1L, null));
    }

    @Test
    void getCourseDetailShouldThrowWhenUnpublishedAndCurrentUserIsNotCreator() {
        Course c = course(1L, trainer(2L));
        c.setStatus("DRAFT");
        when(courseRepository.findByIdWithDetails(1L)).thenReturn(Optional.of(c));

        assertThrows(RuntimeException.class, () -> courseService.getCourseDetail(1L, 99L));
    }

    @Test
    void getCourseDetailShouldThrowWhenUnpublishedAndCurrentUserIdNull() {
        Course c = course(1L, trainer(2L));
        c.setStatus("DRAFT");
        when(courseRepository.findByIdWithDetails(1L)).thenReturn(Optional.of(c));

        assertThrows(RuntimeException.class, () -> courseService.getCourseDetail(1L, null));
    }

    @Test
    void getCourseDetailShouldAllowCreatorToViewOwnUnpublishedCourse() {
        Course c = course(1L, trainer(2L));
        c.setStatus("DRAFT");
        when(courseRepository.findByIdWithDetails(1L)).thenReturn(Optional.of(c));
        when(sectionRepository.findByCourseIdOrderByDisplayOrderAsc(1L)).thenReturn(List.of());
        when(enrollmentRepository.findByUserIdAndCourseId(2L, 1L)).thenReturn(Optional.empty());
        when(lessonProgressRepository.findCompletedLessonIdsByUserIdAndCourseId(2L, 1L)).thenReturn(List.of());

        CourseDetailDTO result = courseService.getCourseDetail(1L, 2L);

        assertEquals("Course", result.getTitle());
    }

    @Test
    void getCourseDetailShouldMapSessionsAndLessonsFromSectionsAndLessons() {
        Course c = course(1L, trainer(2L));
        when(courseRepository.findByIdWithDetails(1L)).thenReturn(Optional.of(c));
        Section section = Section.builder().id(10L).title("Section A").displayOrder(1).build();
        when(sectionRepository.findByCourseIdOrderByDisplayOrderAsc(1L)).thenReturn(List.of(section));
        Lesson lesson = Lesson.builder().id(20L).title("Lesson A").section(section).lessonType("video").displayOrder(1).build();
        when(lessonRepository.findByCourseIdOrdered(1L)).thenReturn(List.of(lesson));

        CourseDetailDTO result = courseService.getCourseDetail(1L, null);

        assertEquals(1, result.getSessions().size());
        assertEquals("Section A", result.getSessions().get(0).getTitle());
        assertEquals(1, result.getSessions().get(0).getLessons().size());
        assertEquals("Lesson A", result.getSessions().get(0).getLessons().get(0).getTitle());
        assertEquals(15, result.getSessions().get(0).getLessons().get(0).getEstimatedTime());
    }

    @Test
    void getCourseDetailShouldSetHasNewVersionAvailableWhenLatestVersionDiffersFromEnrolled() {
        Course c = course(1L, trainer(2L));
        c.setLatestVersionId(2L);
        when(courseRepository.findByIdWithDetails(1L)).thenReturn(Optional.of(c));
        when(sectionRepository.findByCourseIdOrderByDisplayOrderAsc(1L)).thenReturn(List.of());
        when(enrollmentRepository.findByUserIdAndCourseId(5L, 1L))
                .thenReturn(Optional.of(Enrollment.builder().enrolledVersionId(1L).build()));
        Course latest = course(2L, trainer(2L));
        latest.setVersion("v2");
        when(courseRepository.findById(2L)).thenReturn(Optional.of(latest));

        CourseDetailDTO result = courseService.getCourseDetail(1L, 5L);

        assertTrue(result.getHasNewVersionAvailable());
        assertEquals(2L, result.getLatestPublishedCourseId());
        assertEquals("v2", result.getLatestPublishedVersion());
    }

    // =================================================================
    // enrollCourse
    // =================================================================

    @Test
    void enrollCourseShouldThrowWhenAlreadyEnrolled() {
        when(courseRepository.findById(10L)).thenReturn(Optional.of(course(10L, trainer(2L))));
        when(enrollmentRepository.existsByUserIdAndCourseId(1L, 10L)).thenReturn(true);

        assertThrows(RuntimeException.class, () -> courseService.enrollCourse(10L, 1L));
        verify(enrollmentRepository, never()).save(any());
    }

    @Test
    void enrollCourseShouldThrowWhenUserNotFound() {
        when(courseRepository.findById(10L)).thenReturn(Optional.of(course(10L, trainer(2L))));
        when(enrollmentRepository.existsByUserIdAndCourseId(1L, 10L)).thenReturn(false);
        when(userRepository.findById(1L)).thenReturn(Optional.empty());

        assertThrows(RuntimeException.class, () -> courseService.enrollCourse(10L, 1L));
    }

    @Test
    void enrollCourseShouldThrowWhenCourseNotFound() {
        when(courseRepository.findById(10L)).thenReturn(Optional.empty());

        assertThrows(RuntimeException.class, () -> courseService.enrollCourse(10L, 1L));
    }

    @Test
    void enrollCourseShouldRejectWhenTrainerProfileNotVerified() {
        User creator = trainer(2L);
        Course c = course(10L, creator);
        when(enrollmentRepository.existsByUserIdAndCourseId(1L, 10L)).thenReturn(false);
        when(userRepository.findById(1L)).thenReturn(Optional.of(User.builder().id(1L).build()));
        when(courseRepository.findById(10L)).thenReturn(Optional.of(c));
        when(trainerProfileRepository.findById(2L)).thenReturn(Optional.of(
                TrainerProfile.builder().userId(2L).status("PENDING_VERIFICATION").build()));

        RuntimeException ex = assertThrows(RuntimeException.class, () -> courseService.enrollCourse(10L, 1L));
        assertTrue(ex.getMessage().contains("chưa được xuất bản") || ex.getMessage().contains("phê duyệt"));
        verify(enrollmentRepository, never()).save(any());
    }

    @Test
    void enrollCourseShouldSucceedWhenTrainerVerified() {
        User creator = trainer(2L);
        Course c = course(10L, creator);
        when(enrollmentRepository.existsByUserIdAndCourseId(1L, 10L)).thenReturn(false);
        when(userRepository.findById(1L)).thenReturn(Optional.of(User.builder().id(1L).build()));
        when(courseRepository.findById(10L)).thenReturn(Optional.of(c));
        when(trainerProfileRepository.findById(2L)).thenReturn(Optional.of(
                TrainerProfile.builder().userId(2L).status("VERIFIED").build()));

        courseService.enrollCourse(10L, 1L);

        verify(enrollmentRepository).save(any());
    }

    @Test
    void enrollCourseShouldSucceedWhenCourseHasNoCreator() {
        Course c = course(10L, null);
        when(enrollmentRepository.existsByUserIdAndCourseId(1L, 10L)).thenReturn(false);
        when(userRepository.findById(1L)).thenReturn(Optional.of(User.builder().id(1L).build()));
        when(courseRepository.findById(10L)).thenReturn(Optional.of(c));

        courseService.enrollCourse(10L, 1L);

        verify(trainerProfileRepository, never()).findById(any());
        verify(enrollmentRepository).save(any());
    }

    @Test
    void enrollCourseShouldEnrollInLatestVersionWhenRequestedCourseHasNewerVersion() {
        User creator = trainer(2L);
        Course requested = course(10L, creator);
        requested.setLatestVersionId(11L);
        Course latest = course(11L, creator);
        when(courseRepository.findById(10L)).thenReturn(Optional.of(requested));
        when(courseRepository.findById(11L)).thenReturn(Optional.of(latest));
        when(enrollmentRepository.existsByUserIdAndCourseId(1L, 11L)).thenReturn(false);
        when(userRepository.findById(1L)).thenReturn(Optional.of(User.builder().id(1L).build()));
        when(trainerProfileRepository.findById(2L)).thenReturn(Optional.of(
                TrainerProfile.builder().userId(2L).status("VERIFIED").build()));

        courseService.enrollCourse(10L, 1L);

        ArgumentCaptor<Enrollment> captor = ArgumentCaptor.forClass(Enrollment.class);
        verify(enrollmentRepository).save(captor.capture());
        assertEquals(11L, captor.getValue().getCourse().getId());
    }

    // =================================================================
    // unenrollCourse
    // =================================================================

    @Test
    void unenrollCourseShouldThrowWhenNotEnrolled() {
        when(enrollmentRepository.existsByUserIdAndCourseId(1L, 10L)).thenReturn(false);

        assertThrows(RuntimeException.class, () -> courseService.unenrollCourse(10L, 1L));
        verify(enrollmentRepository, never()).deleteByUserIdAndCourseId(any(), any());
    }

    @Test
    void unenrollCourseShouldDeleteEnrollmentWhenEnrolled() {
        when(enrollmentRepository.existsByUserIdAndCourseId(1L, 10L)).thenReturn(true);

        courseService.unenrollCourse(10L, 1L);

        verify(enrollmentRepository).deleteByUserIdAndCourseId(1L, 10L);
    }

    // =================================================================
    // switchCourseVersion
    // =================================================================

    @Test
    void switchCourseVersionShouldThrowWhenEnrollmentNotFound() {
        when(enrollmentRepository.findByUserIdAndCourseId(1L, 10L)).thenReturn(Optional.empty());

        assertThrows(RuntimeException.class, () -> courseService.switchCourseVersion(10L, 1L));
    }

    @Test
    void switchCourseVersionShouldThrowWhenNoPublishedVersionAvailable() {
        Course c = course(10L, trainer(2L));
        Enrollment enrollment = Enrollment.builder().course(c).build();
        when(enrollmentRepository.findByUserIdAndCourseId(1L, 10L)).thenReturn(Optional.of(enrollment));

        assertThrows(RuntimeException.class, () -> courseService.switchCourseVersion(10L, 1L));
    }

    @Test
    void switchCourseVersionShouldThrowWhenAlreadyOnLatestVersion() {
        Course c = course(10L, trainer(2L));
        c.setLatestVersionId(10L);
        Enrollment enrollment = Enrollment.builder().course(c).build();
        when(enrollmentRepository.findByUserIdAndCourseId(1L, 10L)).thenReturn(Optional.of(enrollment));
        when(courseRepository.findById(10L)).thenReturn(Optional.of(c));

        assertThrows(RuntimeException.class, () -> courseService.switchCourseVersion(10L, 1L));
    }

    @Test
    void switchCourseVersionShouldCarryCompletedProgressByCodeMatchAndMarkEnrollmentCompleted() {
        Course current = course(10L, trainer(2L));
        current.setLatestVersionId(11L);
        Course latest = course(11L, trainer(2L));
        User learner = User.builder().id(1L).build();
        Enrollment enrollment = Enrollment.builder().id(5L).user(learner).course(current).build();
        when(enrollmentRepository.findByUserIdAndCourseId(1L, 10L)).thenReturn(Optional.of(enrollment));
        when(courseRepository.findById(11L)).thenReturn(Optional.of(latest));

        Lesson oldLesson = Lesson.builder().id(100L).code("L1").build();
        LessonProgress progress = LessonProgress.builder().lesson(oldLesson).isCompleted(true).completedAt(LocalDateTime.now()).build();
        when(lessonProgressRepository.findCompletedProgressByUserIdAndCourseId(1L, 10L)).thenReturn(List.of(progress));

        Section newSection = Section.builder().id(20L).build();
        when(sectionRepository.findByCourseIdOrderByDisplayOrderAsc(11L)).thenReturn(List.of(newSection));
        Lesson newLesson = Lesson.builder().id(200L).code("L1").section(newSection).build();
        when(lessonRepository.findByCourseIdOrdered(11L)).thenReturn(List.of(newLesson));
        when(lessonProgressRepository.existsByUserIdAndLessonIdAndIsCompletedTrue(1L, 200L)).thenReturn(false);

        courseService.switchCourseVersion(10L, 1L);

        ArgumentCaptor<Enrollment> captor = ArgumentCaptor.forClass(Enrollment.class);
        verify(enrollmentRepository).save(captor.capture());
        assertEquals(latest, captor.getValue().getCourse());
        assertEquals("COMPLETED", captor.getValue().getStatus());
        assertEquals(0, captor.getValue().getProgressPercentage().compareTo(java.math.BigDecimal.valueOf(100)));
        verify(lessonProgressRepository).save(any(LessonProgress.class));
    }

    // =================================================================
    // getCourseVersionHistory
    // =================================================================

    @Test
    void getCourseVersionHistoryShouldThrowWhenCourseNotFound() {
        when(courseRepository.findById(1L)).thenReturn(Optional.empty());

        assertThrows(RuntimeException.class, () -> courseService.getCourseVersionHistory(1L));
    }

    @Test
    void getCourseVersionHistoryShouldReturnSingleVersionWhenCourseHasNoCode() {
        Course c = course(1L, trainer(2L));
        when(courseRepository.findById(1L)).thenReturn(Optional.of(c));

        List<Map<String, Object>> result = courseService.getCourseVersionHistory(1L);

        assertEquals(1, result.size());
        assertEquals(true, result.get(0).get("isCurrent"));
    }

    @Test
    void getCourseVersionHistoryShouldReturnAllVersionsWithLearnersCountWhenCodePresent() {
        Course c = course(1L, trainer(2L));
        c.setCode("ENG-101");
        Course otherVersion = course(2L, trainer(2L));
        otherVersion.setCode("ENG-101");
        when(courseRepository.findById(1L)).thenReturn(Optional.of(c));
        when(courseRepository.findByCodeAndDeletedAtIsNullOrderByCreatedAtDesc("ENG-101"))
                .thenReturn(List.of(c, otherVersion));
        when(enrollmentRepository.countByCourseId(1L)).thenReturn(5);
        when(enrollmentRepository.countByCourseId(2L)).thenReturn(2);

        List<Map<String, Object>> result = courseService.getCourseVersionHistory(1L);

        assertEquals(2, result.size());
        assertEquals(5, result.get(0).get("learnersCount"));
        assertEquals(true, result.get(0).get("isCurrent"));
        assertEquals(false, result.get(1).get("isCurrent"));
    }
}
