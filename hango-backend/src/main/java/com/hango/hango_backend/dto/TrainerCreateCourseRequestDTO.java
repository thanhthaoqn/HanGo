package com.hango.hango_backend.dto;

import lombok.*;
import java.math.BigDecimal;
import java.util.List;

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
    private BigDecimal price;
    private String version;
    private String objectives;
    private List<CourseSessionDTO> sessions;
}
