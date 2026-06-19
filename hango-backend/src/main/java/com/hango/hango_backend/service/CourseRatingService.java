package com.hango.hango_backend.service;

import com.hango.hango_backend.dto.CourseReviewSummaryDTO;

public interface CourseRatingService {
    CourseReviewSummaryDTO getCourseReviews(Long courseId);
}
