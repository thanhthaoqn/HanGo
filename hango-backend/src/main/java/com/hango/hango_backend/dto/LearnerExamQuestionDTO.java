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
public class LearnerExamQuestionDTO {
    private Long id;
    private String content; // question_text
    private String skill; // from skillParam
    private Integer globalIndex; // question_order
    
    private LearnerQuestionGroupDTO group;
    private List<LearnerQuestionOptionDTO> options;
}
