package com.hango.hango_backend.dto;

import lombok.Builder;
import lombok.Data;

@Data
@Builder
public class CourseLessonDTO {
    private Long id;
    private String title;
    private Integer orderIndex;
    private String itemType;
    private Long examId;
}
