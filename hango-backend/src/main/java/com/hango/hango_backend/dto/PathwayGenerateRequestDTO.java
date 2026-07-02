package com.hango.hango_backend.dto;

import jakarta.validation.constraints.NotNull;
import lombok.Data;

@Data
public class PathwayGenerateRequestDTO {
    
    @NotNull(message = "Exam Attempt ID is required")
    private Long examAttemptId;
}
