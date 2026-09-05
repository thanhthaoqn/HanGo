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
public class MasterySubmitResponseDTO {
    private LearningPathwayResponseDTO pathway;
    private List<MasteryQuestionEvaluationDTO> evaluations;
}
