package com.hango.hango_backend.dto;

import lombok.*;
import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

import java.util.List;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class CourseSessionDTO {
    private Long id;
    
    @NotBlank(message = "Session title cannot be blank")
    @Size(max = 255, message = "Session title cannot exceed 255 characters")
    private String title;
    
    @Size(max = 500, message = "Session description cannot exceed 500 characters")
    private String description;
    
    private Integer orderIndex;
    
    @Valid
    private List<CourseLessonDTO> lessons;
}
