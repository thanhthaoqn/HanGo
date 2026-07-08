package com.hango.hango_backend.dto;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class TrainerCreateExamRequestDTO {
    private String title;
    private String description;
    private Integer expectedQuestionCount;
    private Double passingScore;
    private Integer durationMinutes;
}
