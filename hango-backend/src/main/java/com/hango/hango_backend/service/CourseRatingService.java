package com.hango.hango_backend.service;

import com.hango.hango_backend.dto.CourseReviewSummaryDTO;

public interface CourseRatingService {
    CourseReviewSummaryDTO getCourseReviews(Long courseId);
    void addCourseReview(Long courseId, Long userId, Short rating, String content);
    void deleteCourseReview(Long courseId, Long userId);
}
