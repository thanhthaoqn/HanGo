package com.hango.hango_backend.config;

import org.springframework.boot.context.properties.ConfigurationProperties;
import lombok.Getter;
import lombok.Setter;

@Getter
@Setter
@ConfigurationProperties(prefix = "hango.ai-assistant")
public class AIAssistantProperties {
    private double scopeSimilarityThreshold;
    private int maxPromptLength;
}