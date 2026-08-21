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
    private Long id;
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

    // FE-11 agentic upgrade metadata (nullable; backend may not fully support yet)
    @JsonProperty("node_type")
    private String nodeType;

    @JsonProperty("reroute_reason")
    private String rerouteReason;

    @JsonProperty("is_optional")
    private Boolean isOptional;

    @JsonProperty("skipped_at")
    private String skippedAt;

    @JsonProperty("parent_node_id")
    private Long parentNodeId;

    // Smart time-boxing metadata (nullable for now)
    @JsonProperty("start_date")
    private String startDate;

    @JsonProperty("deadline")
    private String deadline;

    @JsonProperty("estimated_hours")
    private Integer estimatedHours;

    @JsonProperty("schedule_status")
    private String scheduleStatus;

    // Feature Phase 2: Retention Engine
    @JsonProperty("mastery_score")
    private Integer masteryScore;

    @JsonProperty("is_mastered")
    private Boolean isMastered;

    @JsonProperty("next_review_date")
    private String nextReviewDate;
    
    @JsonProperty("review_interval_days")
    private Integer reviewIntervalDays;
}

