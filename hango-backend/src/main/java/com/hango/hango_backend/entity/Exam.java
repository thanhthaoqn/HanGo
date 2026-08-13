package com.hango.hango_backend.entity;

import jakarta.persistence.*;
import lombok.Data;
import java.time.LocalDateTime;

@Entity
@Table(name = "exams")
@Data
public class Exam {

    public static final String DEFAULT_THUMBNAIL_URL =
            "https://i.postimg.cc/3r0N7XX3/1786612247888-2782837767096679587-2782837767096679587-9949ba3331c93dfd1b5b113d20c37b92.jpg";

    public static String resolveThumbnailUrl(String thumbnailUrl) {
        return (thumbnailUrl == null || thumbnailUrl.isBlank()) ? DEFAULT_THUMBNAIL_URL : thumbnailUrl;
    }

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    private String title;

    @Column(columnDefinition = "TEXT")
    private String description;

    @Column(name = "duration_minutes")
    private Integer durationMinutes;

    private String status;

    @Column(length = 20)
    private String version = "v0.1";


    @Column(name = "passing_score")
    private Double passingScore;

    @Column(name = "expected_question_count")
    private Integer expectedQuestionCount;

    private String visibility = "PRIVATE";

    @Column(name = "rejection_reason", columnDefinition = "TEXT")
    private String rejectionReason;

    @Column(name = "thumbnail_url")
    private String thumbnailUrl;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "created_by", referencedColumnName = "id")
    private User createdBy;

    @Column(name = "deleted_at")
    private LocalDateTime deletedAt;

    @Column(name = "created_at", updatable = false)
    private LocalDateTime createdAt;

    @PrePersist
    protected void onCreate() {
        if (createdAt == null) {
            createdAt = LocalDateTime.now();
        }
    }
}
