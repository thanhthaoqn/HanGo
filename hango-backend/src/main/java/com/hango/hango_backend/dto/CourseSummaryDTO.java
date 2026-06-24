package com.hango.hango_backend.dto;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;
import java.math.BigDecimal;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class CourseSummaryDTO {
    private Long id;
    private String categoryName;
    private String title;
    private String creatorName;
    private Double rating;
    private Long learnersCount;
    private String difficultyName;
    private String thumbnailUrl;
    private BigDecimal progressPercentage;
}
