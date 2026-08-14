package com.hango.hango_backend.service;

import com.hango.hango_backend.config.GeminiProperties;
import com.hango.hango_backend.repository.AiUsageLogRepository;
import org.junit.jupiter.api.Test;

import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.Mockito.mock;

class GeminiClientServiceTest {

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
