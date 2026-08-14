package com.hango.hango_backend.dto;

import jakarta.validation.constraints.NotNull;
import lombok.Data;

@Data
public class PathwayGenerateRequestDTO {
    
    @NotNull(message = "Exam Attempt ID is required")
    private Long examAttemptId;

    // Feature B: Smart time-boxing inputs (optional)
    private String goalName;
    private java.time.LocalDate targetDate;
    private Integer hoursPerWeek;
    private java.util.List<Integer> preferredStudyDays;

    private Boolean onlyFree;
}

