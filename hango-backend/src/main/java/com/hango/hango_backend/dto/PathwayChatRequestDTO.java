package com.hango.hango_backend.dto;

import jakarta.validation.constraints.NotBlank;
import lombok.Data;

@Data
public class PathwayChatRequestDTO {
    
    @NotBlank(message = "Message cannot be empty")
    private String message;
}
