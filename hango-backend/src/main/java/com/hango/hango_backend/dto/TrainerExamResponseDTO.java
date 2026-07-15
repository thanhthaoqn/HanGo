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
    private LocalDateTime createdAt;
    private int questionCount;
    private Integer durationMinutes;
    private String status;
    private String visibility;
    private Integer expectedQuestionCount;
    private String thumbnailUrl;
}
