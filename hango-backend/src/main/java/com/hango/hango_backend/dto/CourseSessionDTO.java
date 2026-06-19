package com.hango.hango_backend.dto;

import lombok.Builder;
import lombok.Data;

import java.util.List;

@Data
@Builder
public class CourseSessionDTO {
    private Long id;
    private String title;
    private Integer orderIndex;
    private List<CourseLessonDTO> lessons;
}
