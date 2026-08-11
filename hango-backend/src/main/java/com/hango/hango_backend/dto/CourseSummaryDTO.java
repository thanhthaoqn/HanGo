package com.hango.hango_backend.dto;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;
import java.math.BigDecimal;
import java.util.List;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class CourseSummaryDTO {
    private Long id;
    private String categoryName;
    private List<String> categories;
    private String title;
    private String creatorName;
    private Double rating;
    private Long learnersCount;
    private String difficultyName;
    private String thumbnailUrl;
    private BigDecimal price;
    private BigDecimal progressPercentage;

    private String code;

    public CourseSummaryDTO(Long id, String categoryName, String title, String creatorName, Double rating, Long learnersCount, String difficultyName, String thumbnailUrl, BigDecimal price, BigDecimal progressPercentage, String code) {
        this.id = id;
        this.categoryName = categoryName;
        this.title = title;
        this.creatorName = creatorName;
        this.rating = rating;
        this.learnersCount = learnersCount;
        this.difficultyName = difficultyName;
        this.thumbnailUrl = thumbnailUrl;
        this.price = price;
        this.progressPercentage = progressPercentage;
        this.code = code;
    }
}
