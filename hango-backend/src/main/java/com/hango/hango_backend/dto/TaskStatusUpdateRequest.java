package com.hango.hango_backend.dto;

import com.hango.hango_backend.entity.TaskStatus;
import jakarta.validation.constraints.NotNull;
import lombok.Data;

@Data
public class TaskStatusUpdateRequest {
    @NotNull(message = "Status is required")
    private TaskStatus status;
    
    private String note;
}
