package com.hango.hango_backend.dto;

import lombok.Builder;
import lombok.Data;
import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.util.List;

@Data
@Builder
public class CourseReviewDetailDTO {
    private Long id;
    private String title;
    private String code;
    private String creatorName;
    private String categoryName;
    private String difficultyName;
    private String description;
    private String objectives;
    private BigDecimal price;
    private String version;
    private String status;
    private String thumbnailUrl;
    private Integer sectionsCount;
    private Integer lessonsCount;
    private LocalDateTime submittedAt;
    private List<CourseSessionDTO> sessions;
}
