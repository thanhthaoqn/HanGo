package com.hango.hango_backend.dto;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.LocalDateTime;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class TaskDetailDto {
    private Long id;
    private String title;
    private String description;
    private String type;
    private Long assigneeId;
    private Long reviewerId;
    private LocalDateTime deadline;
    private String status;
}
