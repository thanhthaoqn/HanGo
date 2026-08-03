package com.hango.hango_backend.dto;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;
import java.time.LocalDateTime;
import java.util.List;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class TrainerCourseDetailDTO {
    private Long id;
    private String title;
    private String status;
    private String description;
    private List<String> categoryKeys;
    private List<String> categories;
    private long learnersCount;
    private long lessonsCount;
    private String thumbnailUrl;
    private LocalDateTime createdAt;
    private String code;
    private String version;
    private java.math.BigDecimal price;
    private java.math.BigDecimal suggestedPrice;
    private String priceNote;
    private Long parentId;
    private String rejectionReason;
}
