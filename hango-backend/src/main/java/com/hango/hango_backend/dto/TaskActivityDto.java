package com.hango.hango_backend.dto;

import lombok.Data;
import lombok.NoArgsConstructor;
import lombok.AllArgsConstructor;
import lombok.Builder;

import java.time.LocalDateTime;

@Data
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class TaskActivityDto {
    private Long id;
    private Long taskId;
    private Long userId;
    private String userName;
    private String actionType;
    private String description;
    private LocalDateTime createdAt;
}
