package com.hango.hango_backend.dto;

import lombok.Data;

@Data
public class FlashcardResponseDTO {
    private String id;
    private String frontText;
    private String backText;
    private Boolean isLearned = false;
}
