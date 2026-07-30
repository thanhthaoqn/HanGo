package com.hango.hango_backend.dto;

import lombok.Builder;
import lombok.Data;

@Data
@Builder
public class ExamMatrixDetailDTO {
    private Long id;
    private Long skillParamId;
    private String skillParamName;
    private Long difficultyParamId;
    private String difficultyParamName;
    private Long groupTypeId;
    private String groupTypeName;
    private Integer quantity;
}
