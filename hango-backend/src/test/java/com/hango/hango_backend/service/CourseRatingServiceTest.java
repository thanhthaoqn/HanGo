package com.hango.hango_backend.service;

import java.util.List;
import java.util.Optional;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyString;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;
import org.mockito.junit.jupiter.MockitoExtension;

import com.hango.hango_backend.dto.CourseReviewSummaryDTO;
import com.hango.hango_backend.entity.Course;
import com.hango.hango_backend.entity.CourseRating;
import com.hango.hango_backend.entity.Enrollment;
import com.hango.hango_backend.entity.User;
import com.hango.hango_backend.repository.CourseRatingRepository;
import com.hango.hango_backend.repository.CourseRepository;
import com.hango.hango_backend.repository.EnrollmentRepository;
import com.hango.hango_backend.repository.UserRepository;

@ExtendWith(MockitoExtension.class)
class CourseRatingServiceTest {

    @Mock
    private CourseRatingRepository courseRatingRepository;
    @Mock
    private CourseRepository courseRepository;
    @Mock
    private UserRepository userRepository;
    @Mock
    private EnrollmentRepository enrollmentRepository;
    @Mock
    private NotificationService notificationService;

    @InjectMocks
    private CourseRatingServiceImpl courseRatingService;

    private User student(Long id, String email) {
        return User.builder().id(id).email(email).build();
    }

    private CourseRating rating(Long id, User student, short stars, String content) {
        return CourseRating.builder().id(id).student(student).rating(stars).reviewContent(content).build();
    }

    private Course course(Long id, double averageRating, int totalRatings) {
        return Course.builder().id(id).title("English Grammar Mastery")
                .averageRating(averageRating).totalRatings(totalRatings).build();
    }

    private Enrollment completedEnrollment() {
        return Enrollment.builder().status("COMPLETED").build();
    }

    private void stubEligibleLearner(Long courseId, Long userId, Course course) {
        when(courseRepository.findById(courseId)).thenReturn(Optional.of(course));
        when(userRepository.findById(userId)).thenReturn(Optional.of(student(userId, "learner@example.com")));
        when(enrollmentRepository.findByUserIdAndCourseId(userId, courseId)).thenReturn(Optional.of(completedEnrollment()));
        when(courseRatingRepository.findByCourseIdAndStudentId(courseId, userId)).thenReturn(Optional.empty());
    }

    // =================================================================
    // getCourseReviews
    // =================================================================

    @Test
    void getCourseReviewsShouldReturnZeroedSummaryWhenNoRatingsExist() {
        when(courseRatingRepository.findByCourseIdOrderByCreatedAtDesc(1L)).thenReturn(List.of());

        CourseReviewSummaryDTO result = courseRatingService.getCourseReviews(1L);

        assertEquals(0.0, result.getAverageRating());
        assertEquals(0, result.getTotalRatings());
        assertEquals(0, result.getRatingCounts().get(5));
        assertTrue(result.getReviews().isEmpty());
    }

    @Test
    void getCourseReviewsShouldComputeAverageRoundedToOneDecimalAndCountsPerStar() {
        when(courseRatingRepository.findByCourseIdOrderByCreatedAtDesc(1L)).thenReturn(List.of(
                rating(1L, student(1L, "a@example.com"), (short) 4, "Good"),
                rating(2L, student(2L, "b@example.com"), (short) 5, "Great"),
                rating(3L, student(3L, "c@example.com"), (short) 5, "Excellent")));

        CourseReviewSummaryDTO result = courseRatingService.getCourseReviews(1L);

        assertEquals(4.7, result.getAverageRating());
        assertEquals(3, result.getTotalRatings());
        assertEquals(1, result.getRatingCounts().get(4));
        assertEquals(2, result.getRatingCounts().get(5));
    }

    @Test
    void getCourseReviewsShouldMaskLongLocalPartEmailKeepingFirstSixChars() {
        when(courseRatingRepository.findByCourseIdOrderByCreatedAtDesc(1L))
                .thenReturn(List.of(rating(1L, student(1L, "nguyenthanh@example.com"), (short) 5, "Nice")));

        CourseReviewSummaryDTO result = courseRatingService.getCourseReviews(1L);

        assertEquals("nguyen********@example.com", result.getReviews().get(0).getUserName());
        assertEquals("N", result.getReviews().get(0).getUserInitial());
    }

    @Test
    void getCourseReviewsShouldMaskShortLocalPartEmailKeepingFirstChar() {
        when(courseRatingRepository.findByCourseIdOrderByCreatedAtDesc(1L))
                .thenReturn(List.of(rating(1L, student(1L, "abc@example.com"), (short) 5, "Nice")));

        CourseReviewSummaryDTO result = courseRatingService.getCourseReviews(1L);

        assertEquals("a***@example.com", result.getReviews().get(0).getUserName());
    }

    @Test
    void getCourseReviewsShouldDefaultEmailAndNullUserIdWhenStudentIsNull() {
        CourseRating r = CourseRating.builder().id(1L).student(null).rating((short) 5).reviewContent("Nice").build();
        when(courseRatingRepository.findByCourseIdOrderByCreatedAtDesc(1L)).thenReturn(List.of(r));

        CourseReviewSummaryDTO result = courseRatingService.getCourseReviews(1L);

        assertEquals("unknow********@domain.com", result.getReviews().get(0).getUserName());
        assertEquals("U", result.getReviews().get(0).getUserInitial());
        assertNull(result.getReviews().get(0).getUserId());
    }

    @Test
    void getCourseReviewsShouldExcludeOutOfRangeStarsFromCountsButStillIncludeInAverage() {
        when(courseRatingRepository.findByCourseIdOrderByCreatedAtDesc(1L)).thenReturn(List.of(
                rating(1L, student(1L, "a@example.com"), (short) 0, "Weird"),
                rating(2L, student(2L, "b@example.com"), (short) 5, "Great")));

        CourseReviewSummaryDTO result = courseRatingService.getCourseReviews(1L);

        assertEquals(2.5, result.getAverageRating());
        assertEquals(0, result.getRatingCounts().get(1));
        assertEquals(1, result.getRatingCounts().get(5));
    }

    // =================================================================
    // addCourseReview - eligibility
    // =================================================================

    @Test
    void addCourseReviewShouldThrowWhenCourseNotFound() {
        when(courseRepository.findById(1L)).thenReturn(Optional.empty());

        assertThrows(RuntimeException.class, () -> courseRatingService.addCourseReview(1L, 1L, (short) 5, "Nice"));
    }

    @Test
    void addCourseReviewShouldThrowWhenUserNotFound() {
        when(courseRepository.findById(1L)).thenReturn(Optional.of(course(1L, 0.0, 0)));
        when(userRepository.findById(1L)).thenReturn(Optional.empty());

        assertThrows(RuntimeException.class, () -> courseRatingService.addCourseReview(1L, 1L, (short) 5, "Nice"));
    }

    @Test
    void addCourseReviewShouldThrowWhenLearnerIsNotEnrolled() {
        when(courseRepository.findById(1L)).thenReturn(Optional.of(course(1L, 0.0, 0)));
        when(userRepository.findById(1L)).thenReturn(Optional.of(student(1L, "a@example.com")));
        when(enrollmentRepository.findByUserIdAndCourseId(1L, 1L)).thenReturn(Optional.empty());

        assertThrows(RuntimeException.class, () -> courseRatingService.addCourseReview(1L, 1L, (short) 5, "Nice"));
        verify(courseRatingRepository, never()).save(any());
    }

    @Test
    void addCourseReviewShouldThrowWhenEnrolledButNotYetCompleted() {
        when(courseRepository.findById(1L)).thenReturn(Optional.of(course(1L, 0.0, 0)));
        when(userRepository.findById(1L)).thenReturn(Optional.of(student(1L, "a@example.com")));
        when(enrollmentRepository.findByUserIdAndCourseId(1L, 1L))
                .thenReturn(Optional.of(Enrollment.builder().status("ENROLLED").build()));

        assertThrows(RuntimeException.class, () -> courseRatingService.addCourseReview(1L, 1L, (short) 5, "Nice"));
        verify(courseRatingRepository, never()).save(any());
    }

    // =================================================================
    // addCourseReview - persistence
    // =================================================================

    @Test
    void addCourseReviewShouldCreateNewRatingWhenNoneExists() {
        stubEligibleLearner(1L, 1L, course(1L, 0.0, 0));
        when(courseRatingRepository.findByCourseIdOrderByCreatedAtDesc(1L)).thenReturn(List.of());

        courseRatingService.addCourseReview(1L, 1L, (short) 4, "Good course");

        ArgumentCaptor<CourseRating> captor = ArgumentCaptor.forClass(CourseRating.class);
        verify(courseRatingRepository).save(captor.capture());
        assertEquals((short) 4, captor.getValue().getRating());
        assertEquals("Good course", captor.getValue().getReviewContent());
    }

    @Test
    void addCourseReviewShouldUpdateExistingRatingInsteadOfCreatingDuplicate() {
        Course c = course(1L, 2.0, 1);
        User learner = student(1L, "a@example.com");
        CourseRating existing = rating(9L, learner, (short) 2, "Meh");
        when(courseRepository.findById(1L)).thenReturn(Optional.of(c));
        when(userRepository.findById(1L)).thenReturn(Optional.of(learner));
        when(enrollmentRepository.findByUserIdAndCourseId(1L, 1L)).thenReturn(Optional.of(completedEnrollment()));
        when(courseRatingRepository.findByCourseIdAndStudentId(1L, 1L)).thenReturn(Optional.of(existing));
        when(courseRatingRepository.findByCourseIdOrderByCreatedAtDesc(1L)).thenReturn(List.of(existing));

        courseRatingService.addCourseReview(1L, 1L, (short) 5, "Changed my mind, great!");

        ArgumentCaptor<CourseRating> captor = ArgumentCaptor.forClass(CourseRating.class);
        verify(courseRatingRepository).save(captor.capture());
        assertEquals(9L, captor.getValue().getId());
        assertEquals((short) 5, captor.getValue().getRating());
        assertEquals("Changed my mind, great!", captor.getValue().getReviewContent());
    }

    @Test
    void addCourseReviewShouldAllowBlankReviewContent() {
        stubEligibleLearner(1L, 1L, course(1L, 0.0, 0));
        when(courseRatingRepository.findByCourseIdOrderByCreatedAtDesc(1L)).thenReturn(List.of());

        courseRatingService.addCourseReview(1L, 1L, (short) 4, null);

        ArgumentCaptor<CourseRating> captor = ArgumentCaptor.forClass(CourseRating.class);
        verify(courseRatingRepository).save(captor.capture());
        assertEquals((short) 4, captor.getValue().getRating());
    }

    // =================================================================
    // addCourseReview - aggregate stats caching on Course
    // =================================================================

    @Test
    void addCourseReviewShouldRecalculateCourseAverageAndTotalRatings() {
        Course c = course(1L, 0.0, 0);
        stubEligibleLearner(1L, 1L, c);
        when(courseRatingRepository.findByCourseIdOrderByCreatedAtDesc(1L)).thenReturn(List.of(
                rating(1L, student(1L, "a@example.com"), (short) 4, "Good"),
                rating(2L, student(2L, "b@example.com"), (short) 5, "Great")));

        courseRatingService.addCourseReview(1L, 1L, (short) 4, "Good");

        verify(courseRepository).updateCourseStats(1L, 4.5, 2);
    }

    // =================================================================
    // addCourseReview - low rating notification (requirement 4)
    // =================================================================

    @Test
    void addCourseReviewShouldNotifyCourseManagersWhenRatingIsThreeStarsOrLower() {
        Course c = course(1L, 0.0, 0);
        stubEligibleLearner(1L, 1L, c);
        when(courseRatingRepository.findByCourseIdOrderByCreatedAtDesc(1L)).thenReturn(List.of(
                rating(1L, student(1L, "a@example.com"), (short) 2, "Hard to understand")));

        courseRatingService.addCourseReview(1L, 1L, (short) 2, "Hard to understand");

        verify(notificationService).notifyCourseManagers(
                org.mockito.ArgumentMatchers.eq(NotificationService.TYPE_LOW_RATING), anyString(), anyString(), any());
    }

    @Test
    void addCourseReviewShouldUseNoCommentFallbackTextInLowRatingNotificationWhenContentBlank() {
        Course c = course(1L, 0.0, 0);
        stubEligibleLearner(1L, 1L, c);
        when(courseRatingRepository.findByCourseIdOrderByCreatedAtDesc(1L)).thenReturn(List.of(
                rating(1L, student(1L, "a@example.com"), (short) 2, "")));

        courseRatingService.addCourseReview(1L, 1L, (short) 2, "");

        ArgumentCaptor<String> messageCaptor = ArgumentCaptor.forClass(String.class);
        verify(notificationService).notifyCourseManagers(
                org.mockito.ArgumentMatchers.eq(NotificationService.TYPE_LOW_RATING), anyString(), messageCaptor.capture(), any());
        assertTrue(messageCaptor.getValue().contains("(no comment provided)"));
    }

    @Test
    void addCourseReviewShouldNotNotifyLowRatingWhenRatingIsAboveThreeStars() {
        Course c = course(1L, 0.0, 0);
        stubEligibleLearner(1L, 1L, c);
        when(courseRatingRepository.findByCourseIdOrderByCreatedAtDesc(1L)).thenReturn(List.of(
                rating(1L, student(1L, "a@example.com"), (short) 4, "Nice")));

        courseRatingService.addCourseReview(1L, 1L, (short) 4, "Nice");

        verify(notificationService, never()).notifyCourseManagers(
                org.mockito.ArgumentMatchers.eq(NotificationService.TYPE_LOW_RATING), anyString(), anyString(), any());
    }

    // =================================================================
    // addCourseReview - low average-rating threshold crossing (requirement 5)
    // =================================================================

    @Test
    void addCourseReviewShouldNotifyWhenAverageCrossesFromAboveFourToAtOrBelowFour() {
        // Cached baseline: 10 ratings (nine 4-star + one 5-star) averaging 4.1 (above threshold).
        Course c = course(1L, 4.1, 10);
        stubEligibleLearner(1L, 1L, c);
        List<CourseRating> allRatingsAfterNewOne = new java.util.ArrayList<>();
        for (int i = 0; i < 9; i++) {
            allRatingsAfterNewOne.add(rating((long) i + 1, student((long) i + 1, "u" + i + "@example.com"), (short) 4, null));
        }
        allRatingsAfterNewOne.add(rating(10L, student(10L, "u10@example.com"), (short) 5, null));
        allRatingsAfterNewOne.add(rating(11L, student(1L, "learner@example.com"), (short) 2, "meh")); // the new one
        when(courseRatingRepository.findByCourseIdOrderByCreatedAtDesc(1L)).thenReturn(allRatingsAfterNewOne);

        // New average = (36 + 5 + 2) / 11 = 3.9 -> crosses from 4.1 to 3.9.
        courseRatingService.addCourseReview(1L, 1L, (short) 2, "meh");

        verify(notificationService).notifyCourseManagers(
                org.mockito.ArgumentMatchers.eq(NotificationService.TYPE_LOW_AVERAGE_RATING), anyString(), anyString(), any());
    }

    @Test
    void addCourseReviewShouldNotNotifyAverageCrossingWhenAlreadyAtOrBelowFour() {
        // Cached baseline already at 3.9 (already at/below threshold) - no new "crossing" event should fire.
        Course c = course(1L, 3.9, 10);
        stubEligibleLearner(1L, 1L, c);
        List<CourseRating> allRatingsAfterNewOne = new java.util.ArrayList<>();
        for (int i = 0; i < 9; i++) {
            allRatingsAfterNewOne.add(rating((long) i + 1, student((long) i + 1, "u" + i + "@example.com"), (short) 4, null));
        }
        allRatingsAfterNewOne.add(rating(10L, student(10L, "u10@example.com"), (short) 3, null));
        allRatingsAfterNewOne.add(rating(11L, student(1L, "learner@example.com"), (short) 4, "ok")); // the new one
        when(courseRatingRepository.findByCourseIdOrderByCreatedAtDesc(1L)).thenReturn(allRatingsAfterNewOne);

        courseRatingService.addCourseReview(1L, 1L, (short) 4, "ok");

        verify(notificationService, never()).notifyCourseManagers(
                org.mockito.ArgumentMatchers.eq(NotificationService.TYPE_LOW_AVERAGE_RATING), anyString(), anyString(), any());
    }

    @Test
    void addCourseReviewShouldNotNotifyAverageCrossingOnTheVeryFirstRatingEvenIfLow() {
        // No prior ratings at all - there is no "above 4.0" baseline to cross from.
        Course c = course(1L, 0.0, 0);
        stubEligibleLearner(1L, 1L, c);
        when(courseRatingRepository.findByCourseIdOrderByCreatedAtDesc(1L)).thenReturn(List.of(
                rating(1L, student(1L, "a@example.com"), (short) 1, "Terrible")));

        courseRatingService.addCourseReview(1L, 1L, (short) 1, "Terrible");

        verify(notificationService, never()).notifyCourseManagers(
                org.mockito.ArgumentMatchers.eq(NotificationService.TYPE_LOW_AVERAGE_RATING), anyString(), anyString(), any());
    }

    @Test
    void addCourseReviewShouldNotNotifyAverageCrossingWhenStayingAboveFour() {
        Course c = course(1L, 4.8, 10);
        stubEligibleLearner(1L, 1L, c);
        when(courseRatingRepository.findByCourseIdOrderByCreatedAtDesc(1L)).thenReturn(List.of(
                rating(1L, student(1L, "a@example.com"), (short) 5, "Great"),
                rating(2L, student(2L, "b@example.com"), (short) 5, "Great")));

        courseRatingService.addCourseReview(1L, 1L, (short) 5, "Great");

        verify(notificationService, never()).notifyCourseManagers(
                org.mockito.ArgumentMatchers.eq(NotificationService.TYPE_LOW_AVERAGE_RATING), anyString(), anyString(), any());
    }

    // =================================================================
    // deleteCourseReview
    // =================================================================

    @Test
    void deleteCourseReviewShouldThrowWhenReviewNotFound() {
        when(courseRatingRepository.findByCourseIdAndStudentId(1L, 1L)).thenReturn(Optional.empty());

        assertThrows(RuntimeException.class, () -> courseRatingService.deleteCourseReview(1L, 1L));
        verify(courseRatingRepository, never()).delete(any());
    }

    @Test
    void deleteCourseReviewShouldDeleteAndRecalculateCourseStats() {
        Course c = course(1L, 4.0, 2);
        CourseRating existing = rating(9L, student(1L, "a@example.com"), (short) 4, "Good");
        existing.setCourse(c);
        when(courseRatingRepository.findByCourseIdAndStudentId(1L, 1L)).thenReturn(Optional.of(existing));
        when(courseRatingRepository.findByCourseIdOrderByCreatedAtDesc(1L)).thenReturn(List.of(
                rating(2L, student(2L, "b@example.com"), (short) 4, "Good")));

        courseRatingService.deleteCourseReview(1L, 1L);

        verify(courseRatingRepository).delete(existing);
        verify(courseRepository).updateCourseStats(1L, 4.0, 1);
    }
}
