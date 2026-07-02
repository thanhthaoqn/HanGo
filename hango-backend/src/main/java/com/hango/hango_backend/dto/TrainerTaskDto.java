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
public class TrainerTaskDto {
    private Long id; // CreatorTask id (the id needed to accept the task)
    private Long taskId; // Actual task id
    private String taskContent;
    private LocalDateTime deadline;
    private String type;
    private String status;
}
