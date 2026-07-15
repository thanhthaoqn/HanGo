package com.hango.hango_backend.dto;

import lombok.Data;
import java.util.List;

@Data
public class ExamMatrixCreateRequestDTO {
    private String title;
    private String description;
    private List<DetailRequest> details;

    @Data
    public static class DetailRequest {
        private Long skillParamId;
        private Long difficultyParamId;
        private Long categoryId;
        private Integer quantity;
    }
}
