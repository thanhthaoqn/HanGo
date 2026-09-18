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
public class TrainerExamResponseDTO {
    private Long id;
    private String title;
    private String description;
    private LocalDateTime createdAt;
    private int questionCount;
    private Integer durationMinutes;
    private String status;
    private String visibility;
    private Integer expectedQuestionCount;
    private Double passingScore;
    private String thumbnailUrl;
    private Long creatorId;
    private String creatorName;
    private String rejectionReason;
}
