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

    @JsonProperty("exam_attempt_id")
    private Long examAttemptId;

    // Feature B: Smart Time-boxing metadata
    @JsonProperty("goal_name")
    private String goalName;

    @JsonProperty("target_date")
    private String targetDate;

    @JsonProperty("hours_per_week")
    private Integer hoursPerWeek;

    @JsonProperty("schedule_status")
    private String scheduleStatus;

    private List<PathwayNodeDTO> nodes;

    // FE-11 agentic reroute contract
    @JsonProperty("pending_reroute_suggestion")
    private PathwayRerouteSuggestionDTO pendingRerouteSuggestion;

    // Skill analysis metadata for FE Skill Analysis Panel
    @JsonProperty("weak_skills") // Historical
    private List<String> weakSkills;

    @JsonProperty("analyzed_attempts")
    private Integer analyzedAttempts;

    @JsonProperty("latest_weak_skills") // Latest Exam
    private List<String> latestWeakSkills;

    @JsonProperty("total_steps")
    private Integer totalSteps;

    @JsonProperty("completed_steps")
    private Integer completedSteps;

    @JsonProperty("suggested_actions")
    private List<String> suggestedActions;
}

