package com.hango.hango_backend.service;

import java.util.List;
import java.util.Optional;

import org.junit.jupiter.api.AfterEach;
import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
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
import com.hango.hango_backend.entity.Course;
import com.hango.hango_backend.entity.TrainerProfile;
import com.hango.hango_backend.entity.User;
import com.hango.hango_backend.repository.CourseRepository;
import com.hango.hango_backend.repository.EnrollmentRepository;
import com.hango.hango_backend.repository.LessonProgressRepository;
import com.hango.hango_backend.repository.LessonRepository;
import com.hango.hango_backend.repository.SectionRepository;
import com.hango.hango_backend.repository.TrainerProfileRepository;
import com.hango.hango_backend.repository.UserRepository;
import com.hango.hango_backend.sercurity.UserDetailsImpl;

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
    private TrainerProfileRepository trainerProfileRepository;

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
        return Course.builder().id(id).title("Course").creator(creator).averageRating(0.0).totalRatings(0).build();
    }

    private Course course(Long id, User creator, double averageRating, int totalRatings) {
        return Course.builder().id(id).title("Course").creator(creator)
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

    // =================================================================
    // getCourseDetail
    // =================================================================

    @Test
    void getCourseDetailShouldThrowWhenCourseNotFound() {
        when(courseRepository.findById(99L)).thenReturn(Optional.empty());

        assertThrows(RuntimeException.class, () -> courseService.getCourseDetail(99L, 1L));
    }

    @Test
    void getCourseDetailShouldReadCachedAverageRatingAndTotalRatingsFromCourse() {
        Course c = course(1L, trainer(2L), 4.7, 3);
        when(courseRepository.findById(1L)).thenReturn(Optional.of(c));
        when(sectionRepository.findByCourseIdOrderByDisplayOrderAsc(1L)).thenReturn(List.of());

        CourseDetailDTO result = courseService.getCourseDetail(1L, null);

        assertEquals(4.7, result.getRating());
        assertEquals(3, result.getTotalRatings());
    }

    @Test
    void getCourseDetailShouldReturnZeroRatingWhenNoRatingsExist() {
        Course c = course(1L, trainer(2L));
        when(courseRepository.findById(1L)).thenReturn(Optional.of(c));
        when(sectionRepository.findByCourseIdOrderByDisplayOrderAsc(1L)).thenReturn(List.of());

        CourseDetailDTO result = courseService.getCourseDetail(1L, null);

        assertEquals(0.0, result.getRating());
        assertEquals(0, result.getTotalRatings());
    }

    @Test
    void getCourseDetailShouldMarkIsEnrolledTrueWhenEnrollmentExists() {
        Course c = course(1L, trainer(2L));
        when(courseRepository.findById(1L)).thenReturn(Optional.of(c));
        when(sectionRepository.findByCourseIdOrderByDisplayOrderAsc(1L)).thenReturn(List.of());
        when(enrollmentRepository.existsByUserIdAndCourseId(5L, 1L)).thenReturn(true);

        CourseDetailDTO result = courseService.getCourseDetail(1L, 5L);

        assertTrue(result.getIsEnrolled());
    }

    @Test
    void getCourseDetailShouldFallbackCreatorNameToUnknownTrainerWhenCreatorNull() {
        Course c = course(1L, null);
        when(courseRepository.findById(1L)).thenReturn(Optional.of(c));
        when(sectionRepository.findByCourseIdOrderByDisplayOrderAsc(1L)).thenReturn(List.of());

        CourseDetailDTO result = courseService.getCourseDetail(1L, null);

        assertEquals("Unknown Trainer", result.getCreatorName());
    }

    // =================================================================
    // enrollCourse
    // =================================================================

    @Test
    void enrollCourseShouldThrowWhenAlreadyEnrolled() {
        when(enrollmentRepository.existsByUserIdAndCourseId(1L, 10L)).thenReturn(true);

        assertThrows(RuntimeException.class, () -> courseService.enrollCourse(10L, 1L));
        verify(enrollmentRepository, never()).save(any());
    }

    @Test
    void enrollCourseShouldThrowWhenUserNotFound() {
        when(enrollmentRepository.existsByUserIdAndCourseId(1L, 10L)).thenReturn(false);
        when(userRepository.findById(1L)).thenReturn(Optional.empty());

        assertThrows(RuntimeException.class, () -> courseService.enrollCourse(10L, 1L));
    }

    @Test
    void enrollCourseShouldThrowWhenCourseNotFound() {
        when(enrollmentRepository.existsByUserIdAndCourseId(1L, 10L)).thenReturn(false);
        when(userRepository.findById(1L)).thenReturn(Optional.of(User.builder().id(1L).build()));
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
}
