package com.hango.hango_backend.entity;

import jakarta.persistence.*;
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
    private Course course;

    @Builder.Default
    @Column(length = 30)
    private String status = "LOCKED"; // LOCKED, IN_PROGRESS, COMPLETED

    @Column(name = "reason_why", columnDefinition = "TEXT")
    private String reasonWhy;

    @Builder.Default
    @Column(name = "progress_percent")
    private Integer progressPercent = 0;
}
