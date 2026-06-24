package com.hango.hango_backend.dto;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class AiHealthResponse {

    private boolean available;
    private String message;
    private String chatModel;
    private String embeddingModel;
}
