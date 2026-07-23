package com.hango.hango_backend.entity;

import jakarta.persistence.*;
import lombok.*;

import java.time.LocalDateTime;

@Entity
@Table(name = "lessons")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class Lesson {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "section_id", nullable = false)
    private Section section;

    @Column(length = 100)
    private String code;

    @Column(nullable = false)
    private String title;

    @Column(name = "lesson_type", length = 20)
    private String lessonType;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "skill_param_id", nullable = false)
    private SystemParameter skill;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "difficulty_param_id", nullable = false)
    private SystemParameter difficulty;

    @Lob
    @Column(columnDefinition = "LONGTEXT")
    private String content;

    @Column(name = "display_order")
    private Integer displayOrder;

    @Column(name = "media_duration_seconds")
    private Integer mediaDurationSeconds;

    @Column(name = "media_size_bytes")
    private Long mediaSizeBytes;

    @Column(name = "estimated_time_minutes")
    private Integer estimatedTimeMinutes;

    @Column(length = 50)
    private String version;

    @Column(name = "deleted_at")
    private LocalDateTime deletedAt;

    @Column(name = "description", length = 500)
    private String description;

    @Column(name = "learning_objectives", columnDefinition = "TEXT")
    private String learningObjectives;

    @Column(name = "estimated_time")
    private Integer estimatedTime;

    @Column(name = "pdf_name")
    private String pdfName;

    @Column(name = "question_image_url")
    private String questionImageUrl;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "exam_id")
    private Exam exam;

    @com.fasterxml.jackson.annotation.JsonIgnore
    @Lob
    @Column(name = "content_embedding", columnDefinition = "TEXT")
    private String contentEmbedding;

    /** Đóng vai trò là cầu nối giúp AIPromptBuilder lấy nội dung không bị lỗi */
    public String getContentText() {
        return this.content;
    }
}
