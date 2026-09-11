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

    /** Gia tri lesson_type danh dau bai danh gia cuoi khoa (spec 20 - A1). */
    public static final String DISPLAY_TYPE_FINAL_QUIZ = "FINAL_QUIZ";

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

    @Lob
    @Column(name = "video_transcript", columnDefinition = "LONGTEXT")
    private String videoTranscript;

    /** Đóng vai trò là cầu nối giúp AIPromptBuilder lấy nội dung không bị lỗi */
    public String getContentText() {
        return this.content;
    }

    /**
     * Chuan hoa lesson_type thanh itemType de FE hien thi (spec 20).
     * FINAL_QUIZ la bai danh gia cuoi khoa nhung van phai duoc FE coi nhu 'quiz'
     * de hien thi danh sach cau hoi practice; con lai giu nguyen chu thuong.
     */
    public static String displayItemType(String lessonType) {
        if (lessonType == null || lessonType.isBlank()) {
            return "learning";
        }
        if ("FINAL_QUIZ".equalsIgnoreCase(lessonType.trim())) {
            return "quiz";
        }
        return lessonType.trim().toLowerCase();
    }
}
