package com.hango.hango_backend.dto;

import lombok.Data;

@Data
public class FlashcardCreateDTO {
    private String id; // null if new
    private String frontText;
    private String backText;
}
