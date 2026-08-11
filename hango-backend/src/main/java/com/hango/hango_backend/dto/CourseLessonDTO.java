package com.hango.hango_backend.dto;

import lombok.*;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class CourseLessonDTO {
    private Long id;
    
    @NotBlank(message = "Lesson title cannot be blank")
    @Size(max = 100, message = "Lesson title cannot exceed 100 characters")
    private String title;
    
    private Integer orderIndex;
    private String itemType;
    private Long examId;
    private Integer questionCount;
    private Boolean isCompleted;
    
    @Size(max = 500, message = "Lesson description cannot exceed 500 characters")
    private String description;
    
    private String questionText;
    private String pdfName;
    private String questionImageUrl;
    private Integer estimatedTime;

    // Added fields
    @Size(max = 20, message = "Lesson code cannot exceed 20 characters")
    private String lessonCode;
    
    private Integer mediaDurationSeconds;
    private Long mediaSizeBytes;
    private Integer estimatedTimeMinutes;
    
    @Size(max = 1000, message = "Learning objectives cannot exceed 1000 characters")
    private String learningObjectives;
    
    private String videoTranscript;
}
