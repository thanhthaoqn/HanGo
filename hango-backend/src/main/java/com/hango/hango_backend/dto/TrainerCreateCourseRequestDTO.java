package com.hango.hango_backend.dto;

import lombok.*;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class TrainerCreateCourseRequestDTO {
    private String title;
    private String description;
    private String categoryKey;
    private String difficultyKey;
    private String thumbnailUrl;
}
