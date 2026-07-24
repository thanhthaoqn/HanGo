package com.hango.hango_backend.dto;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class LearnerQuestionOptionDTO {
    private Long id;
    private String optionText;
    // We explicitly exclude isCorrect for security
}
