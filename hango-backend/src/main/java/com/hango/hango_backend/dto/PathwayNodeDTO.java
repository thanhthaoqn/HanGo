package com.hango.hango_backend.dto;

import com.fasterxml.jackson.annotation.JsonProperty;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;
import java.util.List;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class PathwayNodeDTO {
    private Integer step;
    @JsonProperty("course_id")
    private Long courseId;
    @JsonProperty("course_title")
    private String courseTitle;
    private List<String> tags;
    private String status;
    @JsonProperty("reason_why")
    private String reasonWhy;
    @JsonProperty("progress_percent")
    private Integer progressPercent;
    @JsonProperty("skill_type")
    private String skillType;
    @JsonProperty("total_lessons")
    private Integer totalLessons;
    @JsonProperty("completed_lessons")
    private Integer completedLessons;
}
