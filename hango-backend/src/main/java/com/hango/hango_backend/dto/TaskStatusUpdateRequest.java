package com.hango.hango_backend.dto;

import jakarta.validation.constraints.NotBlank;
import lombok.Data;

@Data
public class TaskStatusUpdateRequest {
    @NotBlank(message = "Status is required")
    private String status;
    private String submissionNotes;
    private String reviewComment;
    
    // If a Trainer Lead is updating the status for a specific trainer, they provide this ID.
    // If a Trainer is updating their own status, this can be null.
    private Long creatorId;
}
