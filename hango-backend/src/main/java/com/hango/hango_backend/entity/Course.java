package com.hango.hango_backend.entity;

import jakarta.persistence.*;
import lombok.*;
import java.time.LocalDateTime;

@Entity
@Table(name = "courses")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class Course {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "created_by", nullable = false)
    private User creator;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "category_param_id", nullable = false)
    private SystemParameter category;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "difficulty_param_id", nullable = true)
    private SystemParameter difficulty;

    @Column(nullable = false)
    private String title;

    @Column(columnDefinition = "TEXT")
    private String description;

    @Column(name = "thumbnail_url", columnDefinition = "TEXT")
    private String thumbnailUrl;

    @Column(columnDefinition = "TEXT")
    private String objectives;

    @Builder.Default
    @Column(length = 30)
    private String status = "DRAFT";

    /** Cached from CourseRating rows for quick display; recalculated by CourseRatingServiceImpl on every add/update/delete. */
    @Builder.Default
    @Column(name = "average_rating")
    private Double averageRating = 0.0;

    @Builder.Default
    @Column(name = "total_ratings")
    private Integer totalRatings = 0;

    @Column(name = "created_at", insertable = false, updatable = false)
    private LocalDateTime createdAt;

    @Column(name = "deleted_at")
    private LocalDateTime deletedAt;
}
