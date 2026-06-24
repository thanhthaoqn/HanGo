package com.hango.hango_backend.dto;

import lombok.*;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class CourseLessonDTO {
    private Long id;
    private String title;
    private Integer orderIndex;
    private String itemType;
    private Long examId;
    private Integer questionCount;
    private Boolean isCompleted;
}
