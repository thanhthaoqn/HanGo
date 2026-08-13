package com.hango.hango_backend.controller;

import com.hango.hango_backend.service.SystemConfigService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

import java.util.Map;

@RestController
@RequestMapping("/api/v1/admin/config")
@RequiredArgsConstructor
public class AdminConfigController {

    private final SystemConfigService systemConfigService;
    private final com.hango.hango_backend.config.GeminiProperties geminiProperties;

    @GetMapping("/ai")
    @PreAuthorize("hasRole('ADMIN')")
    public ResponseEntity<Map<String, String>> getAiConfig() {
        Map<String, String> configs = new java.util.HashMap<>(systemConfigService.getAllConfigsByType("AI"));
        
        // Return active fallback defaults if missing or empty in DB
        if (!configs.containsKey("GEMINI_API_KEY") || configs.get("GEMINI_API_KEY").trim().isEmpty()) {
            configs.put("GEMINI_API_KEY", geminiProperties.getApiKey());
        }
        if (!configs.containsKey("GEMINI_CHAT_MODEL") || configs.get("GEMINI_CHAT_MODEL").trim().isEmpty()) {
            configs.put("GEMINI_CHAT_MODEL", geminiProperties.getChatModel());
        }
        if (!configs.containsKey("GEMINI_EMBEDDING_MODEL") || configs.get("GEMINI_EMBEDDING_MODEL").trim().isEmpty()) {
            configs.put("GEMINI_EMBEDDING_MODEL", geminiProperties.getEmbeddingModel());
        }
        if (!configs.containsKey("GEMINI_TIMEOUT_SECONDS") || configs.get("GEMINI_TIMEOUT_SECONDS").trim().isEmpty()) {
            configs.put("GEMINI_TIMEOUT_SECONDS", String.valueOf(geminiProperties.getTimeoutSeconds()));
        }
        if (!configs.containsKey("AI_ASSISTANT_SYSTEM_PROMPT") || configs.get("AI_ASSISTANT_SYSTEM_PROMPT").trim().isEmpty()) {
            configs.put("AI_ASSISTANT_SYSTEM_PROMPT", com.hango.hango_backend.service.AIPromptBuilder.DEFAULT_PROMPT);
        }
        if (!configs.containsKey("AI_TRAINER_EXAM_CHAT_PROMPT") || configs.get("AI_TRAINER_EXAM_CHAT_PROMPT").trim().isEmpty()) {
            configs.put("AI_TRAINER_EXAM_CHAT_PROMPT", com.hango.hango_backend.service.TrainerQuestionAIService.DEFAULT_CHAT_PROMPT);
        }
        if (!configs.containsKey("AI_TRAINER_EXAM_GENERATE_PROMPT") || configs.get("AI_TRAINER_EXAM_GENERATE_PROMPT").trim().isEmpty()) {
            configs.put("AI_TRAINER_EXAM_GENERATE_PROMPT", com.hango.hango_backend.service.TrainerQuestionAIService.DEFAULT_GENERATE_PROMPT);
        }
        
        return ResponseEntity.ok(configs);
    }

    @PutMapping("/ai")
    @PreAuthorize("hasRole('ADMIN')")
    public ResponseEntity<Void> updateAiConfig(@RequestBody Map<String, String> configs) {
        systemConfigService.updateConfigs("AI", configs);
        return ResponseEntity.ok().build();
    }
}
