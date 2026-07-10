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
public class LearningPathwayResponseDTO {
    @JsonProperty("pathway_id")
    private Long pathwayId;
    @JsonProperty("roadmap_id")
    private String roadmapId;
    @JsonProperty("mentor_summary")
    private String mentorSummary;
    private List<PathwayNodeDTO> nodes;

    // Skill analysis metadata for FE Skill Analysis Panel
    @JsonProperty("weak_skills")
    private List<String> weakSkills;

    @JsonProperty("total_steps")
    private Integer totalSteps;

    @JsonProperty("completed_steps")
    private Integer completedSteps;
}
