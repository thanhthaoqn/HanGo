package com.hango.hango_backend.dto;

import lombok.Builder;
import lombok.Data;
import java.time.LocalDateTime;
import java.util.List;

@Data
@Builder
public class ExamMatrixDTO {
    private Long id;
    private String title;
    private String description;
    private Long createdBy;
    private LocalDateTime createdAt;
    private Boolean isPublic;
    private List<ExamMatrixDetailDTO> details;
}
