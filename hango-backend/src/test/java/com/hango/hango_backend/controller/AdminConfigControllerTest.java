package com.hango.hango_backend.controller;

import com.hango.hango_backend.config.GeminiProperties;
import com.hango.hango_backend.service.SystemConfigService;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.http.ResponseEntity;

import java.util.HashMap;
import java.util.Map;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class AdminConfigControllerTest {

    @Mock
    private SystemConfigService systemConfigService;

    @Mock
    private GeminiProperties geminiProperties;

    @InjectMocks
    private AdminConfigController adminConfigController;

    @BeforeEach
    void setUp() {
        org.mockito.Mockito.lenient().when(geminiProperties.getApiKey()).thenReturn("default-gemini-key");
        org.mockito.Mockito.lenient().when(geminiProperties.getChatModel()).thenReturn("gemini-1.5-pro");
        org.mockito.Mockito.lenient().when(geminiProperties.getEmbeddingModel()).thenReturn("text-embedding-004");
        org.mockito.Mockito.lenient().when(geminiProperties.getTimeoutSeconds()).thenReturn(60);
    }

    @Test
    void getAiConfig_shouldReturnFallbackDefaultsWhenDbEmpty() {
        when(systemConfigService.getAllConfigsByType("AI")).thenReturn(Map.of());

        ResponseEntity<Map<String, String>> response = adminConfigController.getAiConfig();

        assertEquals(200, response.getStatusCode().value());
        Map<String, String> body = response.getBody();
        assertNotNull(body);
        assertEquals("default-gemini-key", body.get("GEMINI_API_KEY"));
        assertEquals("gemini-1.5-pro", body.get("GEMINI_CHAT_MODEL"));
        assertEquals("text-embedding-004", body.get("GEMINI_EMBEDDING_MODEL"));
        assertEquals("60", body.get("GEMINI_TIMEOUT_SECONDS"));
        assertNotNull(body.get("AI_ASSISTANT_SYSTEM_PROMPT"));
        assertNotNull(body.get("AI_TRAINER_EXAM_CHAT_PROMPT"));
        assertNotNull(body.get("AI_TRAINER_EXAM_GENERATE_PROMPT"));
    }

    @Test
    void getAiConfig_shouldReturnCustomDbValuesWhenPresent() {
        Map<String, String> dbConfigs = new HashMap<>();
        dbConfigs.put("GEMINI_API_KEY", "custom-api-key");
        dbConfigs.put("GEMINI_CHAT_MODEL", "gemini-2.0-flash");
        dbConfigs.put("GEMINI_EMBEDDING_MODEL", "text-embedding-005");
        dbConfigs.put("GEMINI_TIMEOUT_SECONDS", "45");
        dbConfigs.put("AI_ASSISTANT_SYSTEM_PROMPT", "Custom prompt");
        dbConfigs.put("AI_TRAINER_EXAM_CHAT_PROMPT", "Custom chat prompt");
        dbConfigs.put("AI_TRAINER_EXAM_GENERATE_PROMPT", "Custom gen prompt");

        when(systemConfigService.getAllConfigsByType("AI")).thenReturn(dbConfigs);

        ResponseEntity<Map<String, String>> response = adminConfigController.getAiConfig();

        assertEquals(200, response.getStatusCode().value());
        Map<String, String> body = response.getBody();
        assertNotNull(body);
        assertEquals("custom-api-key", body.get("GEMINI_API_KEY"));
        assertEquals("gemini-2.0-flash", body.get("GEMINI_CHAT_MODEL"));
        assertEquals("text-embedding-005", body.get("GEMINI_EMBEDDING_MODEL"));
        assertEquals("45", body.get("GEMINI_TIMEOUT_SECONDS"));
        assertEquals("Custom prompt", body.get("AI_ASSISTANT_SYSTEM_PROMPT"));
        assertEquals("Custom chat prompt", body.get("AI_TRAINER_EXAM_CHAT_PROMPT"));
        assertEquals("Custom gen prompt", body.get("AI_TRAINER_EXAM_GENERATE_PROMPT"));
    }

    @Test
    void updateAiConfig_shouldDelegateToService() {
        Map<String, String> configs = Map.of(
                "GEMINI_API_KEY", "new-key",
                "GEMINI_CHAT_MODEL", "gemini-1.5-flash"
        );

        ResponseEntity<Void> response = adminConfigController.updateAiConfig(configs);

        assertEquals(200, response.getStatusCode().value());
        verify(systemConfigService).updateConfigs("AI", configs);
    }
}
