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
public class CourseDetailDTO {
    private Long id;
    private String status;
    private String title;
    private String code;
    private String creatorName;
    private String difficultyName;
    private Double rating;
    private Integer learnersCount;
    private String description;
    private String objectives;
    private BigDecimal price;
    private String version;
    private Boolean isEnrolled;
    private Boolean hasNewVersionAvailable;
    private Long latestPublishedCourseId;
    private String latestPublishedVersion;
    private String categoryKey;
    private String categoryName;
    private List<String> categoryKeys;
    private List<String> categoryNames;
    private String difficultyKey;
    private String thumbnailUrl;
    private Integer estimatedDuration;
    private List<CourseSessionDTO> sessions;
}
