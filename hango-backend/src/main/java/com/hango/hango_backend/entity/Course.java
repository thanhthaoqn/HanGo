package com.hango.hango_backend.entity;

import jakarta.persistence.*;
import lombok.*;
import org.hibernate.annotations.NotFound;
import org.hibernate.annotations.NotFoundAction;
import org.hibernate.annotations.DynamicUpdate;
import java.math.BigDecimal;
import java.time.LocalDateTime;

import java.util.Set;
import java.util.HashSet;

@Entity
@Table(name = "courses")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
@DynamicUpdate
public class Course {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY)
    @NotFound(action = NotFoundAction.IGNORE)
    @JoinColumn(name = "created_by", nullable = false)
    private User creator;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "category_param_id", nullable = true)
    @NotFound(action = NotFoundAction.IGNORE)
    private SystemParameter category;

    @ManyToMany(fetch = FetchType.LAZY)
    @JoinTable(
        name = "course_categories",
        joinColumns = @JoinColumn(name = "course_id"),
        inverseJoinColumns = @JoinColumn(name = "category_param_id")
    )
    @Builder.Default
    private Set<SystemParameter> categories = new HashSet<>();

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "difficulty_param_id", nullable = true)
    @NotFound(action = NotFoundAction.IGNORE)
    private SystemParameter difficulty;

    @Column(nullable = false)
    private String title;

    @Column(columnDefinition = "TEXT")
    private String description;

    @Column(name = "thumbnail_url", columnDefinition = "TEXT")
    private String thumbnailUrl;

    @Column(columnDefinition = "TEXT")
    private String objectives;

    @Column(name = "estimated_duration")
    private Integer estimatedDuration;

    @Column(length = 100)
    private String code;

    @Builder.Default
    @Column(precision = 10, scale = 2)
    private BigDecimal price = BigDecimal.ZERO;

    @Column(name = "suggested_price", precision = 10, scale = 2)
    private BigDecimal suggestedPrice;

    @Column(name = "price_note", columnDefinition = "TEXT")
    private String priceNote;
 
    @Column(name = "published_at")
    private LocalDateTime publishedAt;

    @Column(length = 50)
    private String version;

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

    @Column(name = "parent_id")
    private Long parentId;

    @Column(name = "latest_version_id")
    private Long latestVersionId;

    @Column(name = "deleted_at")
    private LocalDateTime deletedAt;

    @Column(name = "rejection_reason", columnDefinition = "TEXT")
    private String rejectionReason;
}
