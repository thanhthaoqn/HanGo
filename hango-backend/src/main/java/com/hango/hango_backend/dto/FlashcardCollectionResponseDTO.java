package com.hango.hango_backend.dto;

import lombok.Data;
import java.util.List;

@Data
public class FlashcardCollectionResponseDTO {
    private String id;
    private String title;
    private String description;
    private String creator;
    private Integer sentenceCount;
    private Integer durationMinutes;
    private Double rating;
    private String learnerCount;
    private String imageUrl;
    private List<FlashcardResponseDTO> flashcards;
    private Boolean isRecent = false;
    private Boolean isLearned = false;
    private String lastStudiedAt;
}
