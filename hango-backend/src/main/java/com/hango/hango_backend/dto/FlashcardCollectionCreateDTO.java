package com.hango.hango_backend.dto;

import lombok.Data;
import java.util.List;

@Data
public class FlashcardCollectionCreateDTO {
    private String title;
    private String description;
    private String creator;
    private Integer sentenceCount = 0;
    private Integer durationMinutes = 0;
    private Double rating = 5.0;
    private String learnerCount = "0 Learner";
    private String imageUrl;
    private List<FlashcardCreateDTO> flashcards;
}
