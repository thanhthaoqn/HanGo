package com.hango.hango_backend.dto;

import jakarta.validation.constraints.NotBlank;
import lombok.Data;

import java.util.Map;

@Data
public class MentorActionRequestDTO {
    
    @NotBlank(message = "Action type is required")
    private String actionType;
    
    private Map<String, Object> payload;
}
