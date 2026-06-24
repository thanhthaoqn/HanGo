package com.hango.hango_backend.dto;

import lombok.Builder;
import lombok.Data;

import java.time.LocalDateTime;
import java.util.List;

@Data
@Builder
public class TaskDTO {
    private Long id;
    private Long leadId;
    private String leadName;
    private String title;
    private String description;
    private String type;
    private LocalDateTime dueDate;
    private LocalDateTime createdAt;
    private List<CreatorTaskDTO> assignees;

    @Data
    @Builder
    public static class CreatorTaskDTO {
        private Long creatorTaskId;
        private Long creatorId;
        private String creatorName;
        private String status;
        private String submissionNotes;
        private LocalDateTime submittedAt;
        private Long reviewerId;
        private String reviewerName;
        private String reviewComment;
        private LocalDateTime reviewedAt;
    }
}
