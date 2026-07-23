package com.hango.hango_backend.dto;

import lombok.*;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class CourseLessonDTO {
    private Long id;
    private String title;
    private Integer orderIndex;
    private String itemType;
    private Long examId;
    private Integer questionCount;
    private Boolean isCompleted;
    private String description;
    private String questionText;
    private String pdfName;
    private String questionImageUrl;
    private Integer estimatedTime;

    // Added fields
    private String lessonCode;
    private Integer mediaDurationSeconds;
    private Long mediaSizeBytes;
    private Integer estimatedTimeMinutes;
    private String learningObjectives;
}
