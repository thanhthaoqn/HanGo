package com.hango.hango_backend.entity;

import jakarta.persistence.*;
import lombok.*;

/**
 * Represents a goal associated with a learning pathway for multi-goal merging (Feature C).
 * Each pathway can have one primary goal and multiple secondary goals.
 */
@Entity
@Table(name = "learning_pathway_goals")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class LearningPathwayGoal {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "pathway_id", nullable = false)
    private LearningPathway learningPathway;

    /**
     * Goal type: EXAM_PREP, COMMUNICATION, GENERAL, CERTIFICATION, etc.
     */
    @Column(name = "goal_type", length = 50, nullable = false)
    private String goalType;

    @Column(name = "goal_label", nullable = false)
    private String goalLabel;

    @Column(name = "source_course_id")
    private Long sourceCourseId;

    @Builder.Default
    @Column(name = "priority", nullable = false)
    private Integer priority = 0;
}
