package com.hango.hango_backend.entity;

import jakarta.persistence.*;
import lombok.*;

import java.time.LocalDateTime;

/**
 * Audit log for pathway mutations (reroute, timebox recalc, merge).
 * Each event captures the before/after JSON snapshot and the reason for the mutation.
 */
@Entity
@Table(name = "pathway_events")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class PathwayEvent {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "pathway_id", nullable = false)
    private Long pathwayId;

    @Column(name = "learner_id", nullable = false)
    private Long learnerId;

    /**
     * Event type: FAST_TRACK_SKIP, DETOUR_INSERT, LOCK_NODES, SCHEDULE_APPLY, MERGE, REROUTE_ACCEPT, REROUTE_DECLINE
     */
    @Column(name = "event_type", length = 50, nullable = false)
    private String eventType;

    @Column(name = "before_json", columnDefinition = "TEXT")
    private String beforeJson;

    @Column(name = "after_json", columnDefinition = "TEXT")
    private String afterJson;

    @Column(name = "reason", columnDefinition = "TEXT")
    private String reason;

    @Column(name = "created_at", insertable = false, updatable = false)
    private LocalDateTime createdAt;

    @PrePersist
    protected void onCreate() {
        createdAt = LocalDateTime.now();
    }
}
