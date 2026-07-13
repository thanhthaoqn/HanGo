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
public class CreateSubQuestionDTO {
    private Long id;
    private String questionText;
    private String explanation;
    private Long skillParamId;
    private Long difficultyId;
    private List<CreateOptionDTO> options;
}
