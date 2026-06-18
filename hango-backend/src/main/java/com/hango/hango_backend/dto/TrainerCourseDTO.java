package com.hango.hango_backend.dto;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class TrainerCourseDTO {
    private Long id;
    private String title;
    private String thumbnailUrl;
    private Long learnersCount;
    private Long lessonsCount;
    private String status;
}
