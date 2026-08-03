package com.hango.hango_backend.dto;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;
import java.util.List;
import com.fasterxml.jackson.annotation.JsonIgnoreProperties;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
@JsonIgnoreProperties(ignoreUnknown = true)
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
    @JsonIgnoreProperties(ignoreUnknown = true)
    public static class BlockDTO {
        private Boolean isQuestionGroup;
        private String passageText;
        private Long categoryId; // GroupType
        private Long skillParamId; // SkillType
        private Long difficultyId;
        private List<CreateTrainerQuestionAIResponseDTO.SingleQuestionDTO> questions;
    }
}
