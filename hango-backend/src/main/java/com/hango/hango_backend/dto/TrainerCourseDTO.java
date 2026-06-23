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
    private long learnersCount;
    private long lessonsCount;
    private String thumbnailUrl;
}
