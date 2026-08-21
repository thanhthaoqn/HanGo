package com.hango.hango_backend.entity;

import jakarta.persistence.*;
import lombok.*;

import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.List;

@Entity
@Table(name = "learning_pathways")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class LearningPathway {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "student_id", nullable = false)
    private User student;

    @OneToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "exam_attempt_id")
    private ExamAttempt examAttempt;

    @Column(name = "mentor_summary", columnDefinition = "TEXT")
    private String mentorSummary;

    @Builder.Default
    @Column(length = 30)
    private String status = "ACTIVE"; // ACTIVE, ARCHIVED

    // Feature B: Smart Time-boxing metadata
    @Column(name = "goal_name")
    private String goalName;

    @Column(name = "target_date")
    private LocalDate targetDate;

    @Column(name = "hours_per_week")
    private Integer hoursPerWeek;

    /**
     * Schedule status: ON_TRACK, AT_RISK, BEHIND, COMPLETED
     */
    @Column(name = "schedule_status", length = 30)
    private String scheduleStatus;

    @Column(name = "created_at", insertable = false, updatable = false)
    private LocalDateTime createdAt;

    @Column(name = "updated_at")
    private LocalDateTime updatedAt;

    @OneToMany(mappedBy = "learningPathway", cascade = CascadeType.ALL, orphanRemoval = true)
    @Builder.Default
    private List<PathwayNode> nodes = new ArrayList<>();



    @PrePersist
    protected void onCreate() {
        createdAt = LocalDateTime.now();
        updatedAt = LocalDateTime.now();
    }

    @PreUpdate
    protected void onUpdate() {
        updatedAt = LocalDateTime.now();
    }

    public void addNode(PathwayNode node) {
        nodes.add(node);
        node.setLearningPathway(this);
    }
}

