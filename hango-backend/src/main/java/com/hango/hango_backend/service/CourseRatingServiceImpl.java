package com.hango.hango_backend.service;

import com.hango.hango_backend.dto.CourseReviewDTO;
import com.hango.hango_backend.dto.CourseReviewSummaryDTO;
import com.hango.hango_backend.entity.Course;
import com.hango.hango_backend.entity.CourseRating;
import com.hango.hango_backend.entity.Enrollment;
import com.hango.hango_backend.entity.User;
import com.hango.hango_backend.repository.CourseRepository;
import com.hango.hango_backend.repository.EnrollmentRepository;
import com.hango.hango_backend.repository.UserRepository;
import com.hango.hango_backend.repository.CourseRatingRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.stream.Collectors;

@Service
@RequiredArgsConstructor
public class CourseRatingServiceImpl implements CourseRatingService {

    /** Requirement 5: only fire the "average dropped" notification once, when crossing this line. */
    private static final double LOW_AVERAGE_THRESHOLD = 4.0;
    /** Requirement 4: any single rating at or below this fires a per-rating notification. */
    private static final int LOW_RATING_THRESHOLD = 3;

    private final CourseRatingRepository courseRatingRepository;
    private final CourseRepository courseRepository;
    private final UserRepository userRepository;
    private final EnrollmentRepository enrollmentRepository;
    private final NotificationService notificationService;

    @Override
    @Transactional(readOnly = true)
    public CourseReviewSummaryDTO getCourseReviews(Long courseId) {
        List<CourseRating> ratings = courseRatingRepository.findByCourseIdOrderByCreatedAtDesc(courseId);

        if (ratings.isEmpty()) {
            Map<Integer, Integer> emptyCounts = new HashMap<>();
            for (int i = 1; i <= 5; i++) emptyCounts.put(i, 0);
            return CourseReviewSummaryDTO.builder()
                    .averageRating(0.0)
                    .totalRatings(0)
                    .ratingCounts(emptyCounts)
                    .reviews(List.of())
                    .build();
        }

        double sum = 0;
        Map<Integer, Integer> counts = new HashMap<>();
        for (int i = 1; i <= 5; i++) counts.put(i, 0);

        for (CourseRating r : ratings) {
            int stars = r.getRating() != null ? r.getRating() : 0;
            sum += stars;
            if (stars >= 1 && stars <= 5) {
                counts.put(stars, counts.get(stars) + 1);
            }
        }

        double avg = sum / ratings.size();
        // Round to 1 decimal place
        avg = Math.round(avg * 10.0) / 10.0;

        List<CourseReviewDTO> dtos = ratings.stream().map(r -> {
            String email = "unknown@domain.com";
            try {
                if (r.getStudent() != null && r.getStudent().getEmail() != null) {
                    email = r.getStudent().getEmail();
                }
            } catch (jakarta.persistence.EntityNotFoundException e) {
                // Ignore
            }

            return CourseReviewDTO.builder()
                    .id(r.getId())
                    .userId(r.getStudent() != null ? r.getStudent().getId() : null)
                    .userName(maskEmail(email))
                    .userInitial(email.substring(0, 1).toUpperCase())
                    .userAvatar(r.getStudent() != null ? r.getStudent().getAvatarUrl() : null)
                    .rating(r.getRating())
                    .content(r.getReviewContent())
                    .createdAt(r.getCreatedAt())
                    .build();
        }).collect(Collectors.toList());

        return CourseReviewSummaryDTO.builder()
                .averageRating(avg)
                .totalRatings(ratings.size())
                .ratingCounts(counts)
                .reviews(dtos)
                .build();
    }

    private String maskEmail(String email) {
        if (email == null || !email.contains("@")) return email;
        String[] parts = email.split("@");
        String local = parts[0];
        String domain = parts[1];
        if (local.length() <= 3) {
            return local.substring(0, 1) + "***@" + domain;
        }
        int keep = Math.min(local.length(), 6);
        return local.substring(0, keep) + "********@" + domain;
    }

    @Override
    @Transactional
    public void addCourseReview(Long courseId, Long userId, Short rating, String content) {
        Course course = courseRepository.findById(courseId)
                .orElseThrow(() -> new RuntimeException("Course not found"));
        User student = userRepository.findById(userId)
                .orElseThrow(() -> new RuntimeException("User not found"));

        Enrollment enrollment = enrollmentRepository.findByUserIdAndCourseId(userId, courseId)
                .orElseThrow(() -> new RuntimeException("You must enroll in this course before rating it"));
        if (!"COMPLETED".equalsIgnoreCase(enrollment.getStatus())) {
            throw new RuntimeException("You must complete the course before rating it");
        }

        CourseRating courseRating = courseRatingRepository.findByCourseIdAndStudentId(courseId, userId)
                .orElse(null);

        if (courseRating != null) {
            courseRating.setRating(rating);
            courseRating.setReviewContent(content);
        } else {
            courseRating = CourseRating.builder()
                    .course(course)
                    .student(student)
                    .rating(rating)
                    .reviewContent(content)
                    .build();
        }

        courseRatingRepository.save(courseRating);

        double previousAverage = course.getAverageRating() != null ? course.getAverageRating() : 0.0;
        int previousTotal = course.getTotalRatings() != null ? course.getTotalRatings() : 0;

        recalculateCourseStats(course);

        if (rating != null && rating <= LOW_RATING_THRESHOLD) {
            String title = "Low Course Rating Detected";
            String message = "Course: " + course.getTitle() + "\nLearner Rating: " + rating + " Stars\nReason: \""
                    + (content == null || content.isBlank() ? "(no comment provided)" : content) + "\"";
            notificationService.notifyCourseManagers(NotificationService.TYPE_LOW_RATING, title, message, course);
            notificationService.notifyRole(NotificationService.RECIPIENT_ADMIN, NotificationService.TYPE_LOW_RATING, title, message, course);
        }

        boolean wasAboveThreshold = previousTotal > 0 && previousAverage > LOW_AVERAGE_THRESHOLD;
        boolean isNowAtOrBelowThreshold = course.getAverageRating() != null && course.getAverageRating() <= LOW_AVERAGE_THRESHOLD;
        if (wasAboveThreshold && isNowAtOrBelowThreshold) {
            String title = "Course Quality Warning";
            String message = "Course: " + course.getTitle() + "\nAverage Rating: " + course.getAverageRating()
                    + "\nTotal Ratings: " + course.getTotalRatings();
            notificationService.notifyCourseManagers(NotificationService.TYPE_LOW_AVERAGE_RATING, title, message, course);
            notificationService.notifyRole(NotificationService.RECIPIENT_ADMIN, NotificationService.TYPE_LOW_AVERAGE_RATING, title, message, course);
        }
    }

    /** Recomputes and persists Course.averageRating/totalRatings from all its CourseRating rows. */
    private void recalculateCourseStats(Course course) {
        List<CourseRating> ratings = courseRatingRepository.findByCourseIdOrderByCreatedAtDesc(course.getId());
        int total = ratings.size();
        double average = 0.0;
        if (total > 0) {
            double sum = 0;
            for (CourseRating r : ratings) {
                sum += r.getRating() != null ? r.getRating() : 0;
            }
            average = Math.round((sum / total) * 10.0) / 10.0;
        }
        courseRepository.updateCourseStats(course.getId(), average, total);
        // Also update the course entity in memory so subsequent checks see the new values
        course.setAverageRating(average);
        course.setTotalRatings(total);
    }

    @Override
    @Transactional
    public void deleteCourseReview(Long courseId, Long userId) {
        CourseRating courseRating = courseRatingRepository.findByCourseIdAndStudentId(courseId, userId)
                .orElseThrow(() -> new RuntimeException("Review not found"));
        Course course = courseRating.getCourse();
        courseRatingRepository.delete(courseRating);
        recalculateCourseStats(course);
    }
}
