package com.hango.hango_backend.dto;

import lombok.Builder;
import lombok.Data;

import java.time.LocalDateTime;

@Data
@Builder
public class ExamHistoryLogDTO {
    private Long id;
    private String action;
    private String oldStatus;
    private String newStatus;
    private Long actorId;
    private String actorName;
    private String reason;
    private String diff;
    private LocalDateTime createdAt;
}
