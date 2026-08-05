package com.hango.hango_backend.dto;

import lombok.*;
import jakarta.validation.Valid;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;
import java.math.BigDecimal;
import java.util.List;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class TrainerCreateCourseRequestDTO {
    @NotBlank(message = "Title cannot be blank")
    @Size(max = 255, message = "Title cannot exceed 255 characters")
    private String title;
    
    @NotBlank(message = "Code cannot be blank")
    @Size(max = 100, message = "Code cannot exceed 100 characters")
    private String code;
    
    @Size(max = 5000, message = "Description cannot exceed 5000 characters")
    private String description;
    
    private String categoryKey;
    private List<String> categoryKeys;
    private String difficultyKey;
    private String thumbnailUrl;
    
    @Min(value = 0, message = "Price cannot be negative")
    private BigDecimal price;
    
    private String priceNote;
    private String version;
    
    @Size(max = 5000, message = "Objectives cannot exceed 5000 characters")
    private String objectives;
    
    private Integer estimatedDuration;
    
    @Valid
    private List<CourseSessionDTO> sessions;
}
