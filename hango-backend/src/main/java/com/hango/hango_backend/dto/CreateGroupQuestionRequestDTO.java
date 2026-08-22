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
    private Long id;
    private Long sectionId;
    private String passageText;
    private String explanation;
    private Long categoryId;
    private Long skillParamId; // REQUIRED by DB (skill-param-id)
    private Long difficultyId;
    private Long groupTypeParamId;
    private String groupTypeName;
    private String status;
    private List<CreateSubQuestionDTO> subQuestions;
    private Integer usageType;
}

