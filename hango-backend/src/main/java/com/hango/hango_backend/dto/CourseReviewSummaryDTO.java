package com.hango.hango_backend.dto;

import lombok.Builder;
import lombok.Data;

import java.util.List;
import java.util.Map;

@Data
@Builder
public class CourseReviewSummaryDTO {
    private Double averageRating;
    private Integer totalRatings;
    private Map<Integer, Integer> ratingCounts; // Key: 1-5 star, Value: count
    private List<CourseReviewDTO> reviews;
}
