package com.hango.hango_backend.dto;

import lombok.Builder;
import lombok.Data;

@Data
@Builder
public class ExamResponseDTO {
    private Long id;
    private String title;
    private String description;
    private String status;
    private String creatorName;
    private Integer questionCount;
    private Integer durationMinutes;
    private Double rating;
    private String learnerCountFormatted;
}
