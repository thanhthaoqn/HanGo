package com.hango.hango_backend.entity;

import jakarta.persistence.*;
import org.hibernate.annotations.NotFound;
import org.hibernate.annotations.NotFoundAction;
import lombok.*;

@Entity
@Table(name = "pathway_nodes")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class PathwayNode {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "pathway_id", nullable = false)
    private LearningPathway learningPathway;

    @Column(name = "step_order", nullable = false)
    private Integer stepOrder;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "course_id", nullable = false)
    @NotFound(action = NotFoundAction.IGNORE)
    private Course course;

    @Builder.Default
    @Column(length = 30)
    private String status = "LOCKED"; // LOCKED, IN_PROGRESS, COMPLETED

    @Column(name = "reason_why", columnDefinition = "TEXT")
    private String reasonWhy;

    @Builder.Default
    @Column(name = "progress_percent")
    private Integer progressPercent = 0;

    @Column(name = "tags", columnDefinition = "TEXT")
    private String tags;

    // FE-11 agentic upgrade metadata (nullable; schema migration may be required)
    @Column(name = "node_type", length = 40)
    private String nodeType;

    @Column(name = "reroute_reason", columnDefinition = "TEXT")
    private String rerouteReason;

    @Column(name = "is_optional")
    private Boolean isOptional;

    @Column(name = "skipped_at")
    private java.time.LocalDateTime skippedAt;

    @Column(name = "parent_node_id")
    private Long parentNodeId;

    // Smart time-boxing metadata (nullable; schema migration may be required)
    @Column(name = "start_date")
    private java.time.LocalDateTime startDate;

    @Column(name = "deadline")
    private java.time.LocalDateTime deadline;

    @Column(name = "estimated_hours")
    private Integer estimatedHours;

    @Column(name = "schedule_status", length = 30)
    private String scheduleStatus;

    // Feature C: Multi-goal merge metadata
    /**
     * JSON array of goal labels this node serves, e.g. ["THPT", "Communication"]
     */
    @Column(name = "source_goal_labels", columnDefinition = "TEXT")
    private String sourceGoalLabels;

    @Column(name = "merge_reason", columnDefinition = "TEXT")
    private String mergeReason;

    // Feature Phase 2: Retention Engine (Mastery & Spaced Repetition)
    @Column(name = "mastery_score")
    private Integer masteryScore;

    @Builder.Default
    @Column(name = "is_mastered")
    private Boolean isMastered = false;

    @Column(name = "next_review_date")
    private java.time.LocalDateTime nextReviewDate;

    @Builder.Default
    @Column(name = "review_interval_days")
    private Integer reviewIntervalDays = 1;
}

