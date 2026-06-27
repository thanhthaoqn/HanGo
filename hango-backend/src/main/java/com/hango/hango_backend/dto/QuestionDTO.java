package com.hango.hango_backend.dto;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;
import java.time.LocalDateTime;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class QuestionDTO {
    private Long id;
    private String questionText;
    private String categoryName;
    private String difficultyName;
    private String status;
    private String creatorName;
    private LocalDateTime createdAt;
    private LocalDateTime updatedAt;
}
