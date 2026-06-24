package com.hango.hango_backend.dto;

import com.hango.hango_backend.entity.TaskType;
import jakarta.validation.constraints.Future;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import lombok.Data;

import java.time.LocalDateTime;

@Data
public class TaskRequestDTO {
    @NotBlank(message = "Task content is required")
    private String content;

    @NotNull(message = "Assignee ID is required")
    private Long assignedToId;

    @NotNull(message = "Task type is required")
    private TaskType type;

    private Long assignedById;

    private String imageBase64;

    @NotNull(message = "Deadline is required")
    @Future(message = "Deadline must be in the future")
    private LocalDateTime deadline;
}
