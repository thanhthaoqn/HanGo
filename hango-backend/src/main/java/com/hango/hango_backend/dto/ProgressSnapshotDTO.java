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
public class ProgressSnapshotDTO {
    
    @JsonProperty("pathway_id")
    private Long pathwayId;

    @JsonProperty("learner_id")
    private Long learnerId;

    @JsonProperty("nodes_snapshot")
    private List<NodeSnapshotDTO> nodesSnapshot;

    @Data
    @Builder
    @NoArgsConstructor
    @AllArgsConstructor
    public static class NodeSnapshotDTO {
        @JsonProperty("node_id")
        private Long nodeId;

        @JsonProperty("course_id")
        private Long courseId;

        @JsonProperty("step_order")
        private Integer stepOrder;

        @JsonProperty("status")
        private String status;

        @JsonProperty("progress_percent")
        private Integer progressPercent;

        @JsonProperty("fail_streak")
        private Integer failStreak;

        @JsonProperty("latest_score")
        private Double latestScore;

        @JsonProperty("completion_time_minutes")
        private Long completionTimeMinutes;

        @JsonProperty("has_weak_skill_overlap")
        private Boolean hasWeakSkillOverlap;
    }
}
