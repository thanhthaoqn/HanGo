package com.hango.hango_backend.dto;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;
import java.time.LocalDateTime;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class TrainerCourseDetailDTO {
    private Long id;
    private String title;
    private String status;
    private String description;
    private long learnersCount;
    private long lessonsCount;
    private String thumbnailUrl;
    private LocalDateTime createdAt;
}
