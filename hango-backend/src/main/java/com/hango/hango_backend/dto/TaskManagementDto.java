package com.hango.hango_backend.dto;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class TaskManagementDto {
    private Long id;
    private String taskContent;
    private String assigneeName;
    private String reviewerName;
    private String type;
    private String status;
}
