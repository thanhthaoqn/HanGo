package com.hango.hango_backend.dto;

import jakarta.validation.constraints.NotNull;
import lombok.Data;

import java.time.LocalDate;
import java.util.List;

@Data
public class PathwayScheduleRequestDTO {

    @NotNull(message = "goal_name is required")
    private String goalName;

    @NotNull(message = "target_date is required")
    private LocalDate targetDate;

    @NotNull(message = "hours_per_week is required")
    private Integer hoursPerWeek;

    // optional
    private java.util.List<Integer> preferredStudyDays;

}

