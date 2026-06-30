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
public class CreateGroupQuestionRequestDTO {
    private Long sectionId;
    private String passageText;
    private String explanation;
    private Long categoryId;
    private Long difficultyId;
    private List<CreateSubQuestionDTO> subQuestions;
}
