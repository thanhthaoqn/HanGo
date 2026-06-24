package com.hango.hango_backend.dto;

import lombok.*;

import java.util.List;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class CourseSessionDTO {
    private Long id;
    private String title;
    private Integer orderIndex;
    private List<CourseLessonDTO> lessons;
}
