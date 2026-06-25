package com.hango.hango_backend.dto;

import lombok.Builder;
import lombok.Data;

import java.time.LocalDateTime;

@Data
@Builder
public class TaskActivityDTO {
    private Long id;
    private Long taskId;
    private Long userId;
    private String userName;
    private String action;
    private String details;
    private LocalDateTime timestamp;
}
