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
public class CreateQuestionRequestDTO {
    private Long sectionId;
    private String questionText;
    private String explanation;
    private Long categoryId;
    private Long skillParamId;
    private Long difficultyId;
    private String passageText;
    private Long groupId;
    private Long groupTypeParamId;
    private List<CreateOptionDTO> options;
    private Integer usageType;
}
