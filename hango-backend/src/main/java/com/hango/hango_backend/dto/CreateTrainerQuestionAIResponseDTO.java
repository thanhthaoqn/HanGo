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
public class CreateTrainerQuestionAIResponseDTO {
    private String mode;

    /** chỉ dùng cho SINGLE */
    private List<SingleQuestionDTO> questions;

    /** chỉ dùng cho MULTIPLE */
    private MultipleGroupDTO group;

    @Data
    @Builder
    @NoArgsConstructor
    @AllArgsConstructor
    @JsonIgnoreProperties(ignoreUnknown = true)
    public static class SingleQuestionDTO {
        private String questionText;
        private String explanation;
        private Long categoryId;
        private Long difficultyId;
        private List<OptionDTO> options;
        private String sourceCitation;
    }

    @Data
    @Builder
    @NoArgsConstructor
    @AllArgsConstructor
    @JsonIgnoreProperties(ignoreUnknown = true)
    public static class MultipleGroupDTO {
        private String passageText;
        private String explanation;
        private Long categoryId;
        private Long difficultyId;
        private List<SubQuestionDTO> subQuestions;
        private String sourceCitation;
    }

    @Data
    @Builder
    @NoArgsConstructor
    @AllArgsConstructor
    @JsonIgnoreProperties(ignoreUnknown = true)
    public static class SubQuestionDTO {
        private String questionText;
        private String explanation;
        private Long skillParamId;
        private Long difficultyId;
        private List<OptionDTO> options;
    }

    @Data
    @Builder
    @NoArgsConstructor
    @AllArgsConstructor
    @JsonIgnoreProperties(ignoreUnknown = true)
    public static class OptionDTO {
        private String optionText;
        private Boolean isCorrect;
    }
}

