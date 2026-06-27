package com.hango.hango_backend.config;

import org.springframework.boot.context.properties.ConfigurationProperties;
import org.springframework.stereotype.Component;

import lombok.Getter;
import lombok.Setter;

@Getter
@Setter
@Component
@ConfigurationProperties(prefix = "hango.gemini")
public class GeminiProperties {
    private String apiKey;
    private String chatModel;
    private String embeddingModel;
    private String baseUrl;
    private int timeoutSeconds;
}