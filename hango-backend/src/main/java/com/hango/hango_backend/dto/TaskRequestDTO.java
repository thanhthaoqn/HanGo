package com.hango.hango_backend.dto;

import jakarta.validation.constraints.Future;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import lombok.Data;

import java.time.LocalDateTime;
import java.util.List;

@Data
public class TaskRequestDTO {
    @NotBlank(message = "Title is required")
    private String title;

    private String description;
    
    private String type;

    @NotNull(message = "Due date is required")
    @Future(message = "Due date must be in the future")
    private LocalDateTime dueDate;

    @NotNull(message = "Assignee is required")
    private Long assigneeId;

    @NotNull(message = "Reviewer is required")
    private Long reviewerId;
}
