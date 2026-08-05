package com.hango.hango_backend.dto;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.util.List;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class LessonDetailDTO {
    private Long id;
    private String title;
    private String content;
    private Long sectionId;
    private Long courseId;
    private List<CommentDTO> comments;
    private List<QuizQuestionDTO> questions;
    private Boolean isCompleted;
    private Integer estimatedTime;

    // Added fields
    private String lessonCode;
    private Integer mediaDurationSeconds;
    private Long mediaSizeBytes;
    private Integer estimatedTimeMinutes;
    private String learningObjectives;
    
    private String mediaFileUrl;
    private String mediaType;
}
