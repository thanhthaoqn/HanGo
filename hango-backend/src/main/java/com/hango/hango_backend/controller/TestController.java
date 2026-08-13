package com.hango.hango_backend.controller;

import com.hango.hango_backend.service.SystemConfigService;
import lombok.RequiredArgsConstructor;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;
import com.hango.hango_backend.config.GeminiProperties;
import java.util.Map;

@RestController
@RequestMapping("/api/test-config")
@RequiredArgsConstructor
public class TestController {

    private final SystemConfigService systemConfigService;
    private final GeminiProperties geminiProperties;

    @GetMapping
    public Map<String, String> get() {
        Map<String, String> configs = new java.util.HashMap<>(systemConfigService.getAllConfigsByType("AI"));
        if (!configs.containsKey("GEMINI_API_KEY")) {
            configs.put("GEMINI_API_KEY", geminiProperties.getApiKey());
        }
        if (!configs.containsKey("GEMINI_CHAT_MODEL")) {
            configs.put("GEMINI_CHAT_MODEL", geminiProperties.getChatModel());
        }
        if (!configs.containsKey("GEMINI_EMBEDDING_MODEL")) {
            configs.put("GEMINI_EMBEDDING_MODEL", geminiProperties.getEmbeddingModel());
        }
        if (!configs.containsKey("GEMINI_TIMEOUT_SECONDS")) {
            configs.put("GEMINI_TIMEOUT_SECONDS", String.valueOf(geminiProperties.getTimeoutSeconds()));
        }
        return configs;
    }
}
