package com.hango.hango_backend.service;

import com.hango.hango_backend.config.GeminiProperties;
import com.hango.hango_backend.repository.AiUsageLogRepository;
import org.junit.jupiter.api.Test;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

class GeminiClientServiceTest {

    // =================================================================
    // getApiKey / getChatModel / getEmbeddingModel / getTimeoutSeconds
    // =================================================================

    @Test
    void getApiKeyShouldReturnValueFromSystemConfigServiceWhenOverridePresent() {
        GeminiProperties properties = new GeminiProperties();
        properties.setApiKey("fallback-key");
        SystemConfigService systemConfigService = mock(SystemConfigService.class);
        when(systemConfigService.getConfigValue("AI", "GEMINI_API_KEY", "fallback-key")).thenReturn("override-key");
        GeminiClientService service = new GeminiClientService(properties, mock(AiUsageLogRepository.class), systemConfigService);

        assertEquals("override-key", service.getApiKey());
    }

    @Test
    void getChatModelShouldFallBackToGeminiPropertiesWhenNoOverrideConfigured() {
        GeminiProperties properties = new GeminiProperties();
        properties.setChatModel("gemini-1.5-flash");
        SystemConfigService systemConfigService = mock(SystemConfigService.class);
        when(systemConfigService.getConfigValue(eq("AI"), eq("GEMINI_CHAT_MODEL"), anyString()))
                .thenAnswer(invocation -> invocation.getArgument(2));
        GeminiClientService service = new GeminiClientService(properties, mock(AiUsageLogRepository.class), systemConfigService);

        assertEquals("gemini-1.5-flash", service.getChatModel());
    }

    @Test
    void getEmbeddingModelShouldFallBackToGeminiPropertiesWhenNoOverrideConfigured() {
        GeminiProperties properties = new GeminiProperties();
        properties.setEmbeddingModel("text-embedding-004");
        SystemConfigService systemConfigService = mock(SystemConfigService.class);
        when(systemConfigService.getConfigValue(eq("AI"), eq("GEMINI_EMBEDDING_MODEL"), anyString()))
                .thenAnswer(invocation -> invocation.getArgument(2));
        GeminiClientService service = new GeminiClientService(properties, mock(AiUsageLogRepository.class), systemConfigService);

        assertEquals("text-embedding-004", service.getEmbeddingModel());
    }

    @Test
    void getTimeoutSecondsShouldParseOverrideValueFromSystemConfigService() {
        GeminiProperties properties = new GeminiProperties();
        properties.setTimeoutSeconds(30);
        SystemConfigService systemConfigService = mock(SystemConfigService.class);
        when(systemConfigService.getConfigValue("AI", "GEMINI_TIMEOUT_SECONDS", "30")).thenReturn("60");
        GeminiClientService service = new GeminiClientService(properties, mock(AiUsageLogRepository.class), systemConfigService);

        assertEquals(60, service.getTimeoutSeconds());
    }

    // =================================================================
    // normalizeDocumentAnalysisPayload
    // =================================================================

    @Test
    void normalizeDocumentAnalysisPayloadShouldOverrideWrongTeachingCertificateWhenEvidenceShowsBachelorDegree() {
        GeminiProperties properties = new GeminiProperties();
        GeminiClientService service = new GeminiClientService(properties, mock(AiUsageLogRepository.class), mock(SystemConfigService.class));

        String rawJson = """
                {
                  "documentTitle": "TEFL / TESOL Teaching Certificate",
                  "issuingInstitution": "Vietnam National University, Hanoi",
                  "holderName": "Nguyen Thi Thuong Tra",
                  "isPedagogical": true,
                  "evidenceText": [
                    "THE DEGREE OF BACHELOR",
                    "BANG CU NHAN",
                    "College of Foreign Languages"
                  ],
                  "ocrText": "THE DEGREE OF BACHELOR BANG CU NHAN Vietnam National University, Hanoi"
                }
                """;

        String normalized = service.normalizeDocumentAnalysisPayload(rawJson);

        assertTrue(normalized.contains("\"documentType\":\"PEDAGOGICAL_DEGREE\""));
        assertTrue(normalized.contains("\"documentTitle\":\"Bachelor of English Pedagogy Degree\""));
    }

    @Test
    void normalizeDocumentAnalysisPayloadShouldInferIeltsFromIssuerAndEvidence() {
        GeminiProperties properties = new GeminiProperties();
        GeminiClientService service = new GeminiClientService(properties, mock(AiUsageLogRepository.class), mock(SystemConfigService.class));

        String rawJson = """
                {
                  "documentTitle": "Other Credential Proof",
                  "issuingInstitution": "British Council",
                  "holderName": "Nguyen Van A",
                  "isPedagogical": false,
                  "evidenceText": [
                    "IELTS",
                    "Test Report Form",
                    "British Council"
                  ]
                }
                """;

        String normalized = service.normalizeDocumentAnalysisPayload(rawJson);

        assertTrue(normalized.contains("\"documentType\":\"LANGUAGE_PROFICIENCY\""));
        assertTrue(normalized.contains("\"documentTitle\":\"IELTS / Proficiency Certificate\""));
    }

    @Test
    void normalizeDocumentAnalysisPayloadShouldPreferTeflEvidenceOverWrongDegreeGuess() {
        GeminiProperties properties = new GeminiProperties();
        GeminiClientService service = new GeminiClientService(properties, mock(AiUsageLogRepository.class), mock(SystemConfigService.class));

        String rawJson = """
                {
                  "documentType": "PEDAGOGICAL_DEGREE",
                  "documentTitle": "Bachelor of English Pedagogy Degree",
                  "issuingInstitution": "Harvard University",
                  "holderName": "Huynh Thi Que Chau",
                  "isPedagogical": true,
                  "evidenceText": [
                    "TEFL International",
                    "TESOL Certification",
                    "Lead Trainer",
                    "Course Director"
                  ],
                  "ocrText": "TEFL International TESOL Certification"
                }
                """;

        String normalized = service.normalizeDocumentAnalysisPayload(rawJson);

        assertTrue(normalized.contains("\"documentType\":\"TEACHING_CERTIFICATE\""));
        assertTrue(normalized.contains("\"documentTitle\":\"TEFL / TESOL Teaching Certificate\""));
    }
}
