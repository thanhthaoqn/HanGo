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
public class CreateTrainerExamAIResponseDTO {
    private String title;
    private String description;
    private Integer durationMinutes;
    private Double passingScore;
    private Integer expectedQuestionCount;
    private List<BlockDTO> blocks;

    @Data
    @Builder
    @NoArgsConstructor
    @AllArgsConstructor
    public static class BlockDTO {
        private Boolean isQuestionGroup;
        private String passageText;
        private Long categoryId; // GroupType
        private Long skillParamId; // SkillType
        private Long difficultyId;
        private List<CreateTrainerQuestionAIResponseDTO.SingleQuestionDTO> questions;
    }
}
