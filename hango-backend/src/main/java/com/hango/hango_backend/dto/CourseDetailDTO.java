package com.hango.hango_backend.dto;

import lombok.Builder;
import lombok.Data;

import java.util.List;

@Data
@Builder
public class CourseDetailDTO {
    private Long id;
    private String title;
    private String creatorName;
    private String difficultyName;
    private Double rating;
    private Integer learnersCount;
    private String description;
    private String objectives;
    private Boolean isEnrolled;
    private List<CourseSessionDTO> sessions;
}
