package com.hango.hango_backend.dto;

import lombok.*;
import java.util.List;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class TrainerCreateCourseRequestDTO {
    private Long taskId;
    private String title;
    private String description;
    private String categoryKey;
    private String difficultyKey;
    private String thumbnailUrl;
    private List<CourseSessionDTO> sessions;
}
