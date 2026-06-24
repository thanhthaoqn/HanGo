package com.hango.hango_backend.service;

import com.hango.hango_backend.dto.CourseReviewDTO;
import com.hango.hango_backend.dto.CourseReviewSummaryDTO;
import com.hango.hango_backend.entity.Course;
import com.hango.hango_backend.entity.CourseRating;
import com.hango.hango_backend.entity.User;
import com.hango.hango_backend.repository.CourseRepository;
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

    private final CourseRatingRepository courseRatingRepository;
    private final CourseRepository courseRepository;
    private final UserRepository userRepository;

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
    }

    @Override
    @Transactional
    public void deleteCourseReview(Long courseId, Long userId) {
        CourseRating courseRating = courseRatingRepository.findByCourseIdAndStudentId(courseId, userId)
                .orElseThrow(() -> new RuntimeException("Review not found"));
        courseRatingRepository.delete(courseRating);
    }
}
