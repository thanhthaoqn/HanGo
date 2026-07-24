package com.hango.hango_backend.service;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.hango.hango_backend.dto.CreateTrainerQuestionAIRequestDTO;
import com.hango.hango_backend.dto.CreateTrainerQuestionAIResponseDTO;
import com.hango.hango_backend.exeption.ApiException;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class TrainerQuestionAIServiceTest {

    @Mock
    private GeminiClientService geminiClientService;

    private TrainerQuestionAIService service;

    @BeforeEach
    void setUp() {
        service = new TrainerQuestionAIService(geminiClientService, new ObjectMapper());
    }

    private CreateTrainerQuestionAIRequestDTO request(String mode, String topicSeed, Integer quantity) {
        return CreateTrainerQuestionAIRequestDTO.builder()
                .mode(mode)
                .topicSeed(topicSeed)
                .quantity(quantity)
                .sectionId(1L)
                .build();
    }

    // =================================================================
    // generatePayload
    // =================================================================

    @Test
    void generatePayloadShouldThrowWhenRequestNull() {
        ApiException ex = assertThrows(ApiException.class, () -> service.generatePayload(null));
        assertEquals(400, ex.getStatus().value());
    }

    @Test
    void generatePayloadShouldThrowWhenModeBlank() {
        assertThrows(ApiException.class, () -> service.generatePayload(request("  ", "Grammar tenses", 1)));
    }

    @Test
    void generatePayloadShouldThrowWhenTopicSeedBlank() {
        assertThrows(ApiException.class, () -> service.generatePayload(request("SINGLE", "  ", 1)));
    }

    @Test
    void generatePayloadShouldDefaultQuantityToOneWhenNullOrNonPositive() {
        String json = "{\"mode\":\"SINGLE\",\"questions\":[]}";
        when(geminiClientService.generateChatResponse(anyString(), any())).thenReturn(json);

        service.generatePayload(request("SINGLE", "Grammar tenses", -5));

        ArgumentCaptor<String> promptCaptor = ArgumentCaptor.forClass(String.class);
        org.mockito.Mockito.verify(geminiClientService).generateChatResponse(promptCaptor.capture(), any());
        assertTrue(promptCaptor.getValue().contains("Generate exactly 1 questions"));
    }

    @Test
    void generatePayloadShouldStripMarkdownJsonCodeFenceFromAiResponse() {
        String fenced = "```json\n{\"mode\":\"SINGLE\",\"questions\":[]}\n```";
        when(geminiClientService.generateChatResponse(anyString(), any())).thenReturn(fenced);

        CreateTrainerQuestionAIResponseDTO result = service.generatePayload(request("SINGLE", "Grammar tenses", 2));

        assertEquals("SINGLE", result.getMode());
    }

    @Test
    void generatePayloadShouldThrowBadGatewayWhenAiReturnsInvalidJson() {
        when(geminiClientService.generateChatResponse(anyString(), any())).thenReturn("not json at all");

        ApiException ex = assertThrows(ApiException.class, () -> service.generatePayload(request("SINGLE", "Grammar tenses", 1)));
        assertEquals(502, ex.getStatus().value());
    }

    @Test
    void generatePayloadShouldParseSingleModeQuestionsWithOptions() {
        String json = "{\"mode\":\"SINGLE\",\"questions\":[{\"questionText\":\"2+2?\",\"explanation\":\"basic math\","
                + "\"categoryId\":1,\"difficultyId\":14,\"options\":["
                + "{\"optionText\":\"3\",\"isCorrect\":false},{\"optionText\":\"4\",\"isCorrect\":true}]}]}";
        when(geminiClientService.generateChatResponse(anyString(), any())).thenReturn(json);

        CreateTrainerQuestionAIResponseDTO result = service.generatePayload(request("SINGLE", "Basic math", 1));

        assertEquals(1, result.getQuestions().size());
        assertEquals("2+2?", result.getQuestions().get(0).getQuestionText());
        assertEquals(2, result.getQuestions().get(0).getOptions().size());
    }

    @Test
    void generatePayloadShouldParseMultipleModeGroupWithSubQuestions() {
        String json = "{\"mode\":\"MULTIPLE\",\"questions\":[],\"group\":{\"passageText\":\"Once upon a time...\","
                + "\"categoryId\":1,\"difficultyId\":14,\"subQuestions\":["
                + "{\"questionText\":\"Who is the main character?\",\"options\":[{\"optionText\":\"A\",\"isCorrect\":true}]}]}}";
        when(geminiClientService.generateChatResponse(anyString(), any())).thenReturn(json);

        CreateTrainerQuestionAIResponseDTO result = service.generatePayload(request("MULTIPLE", "A short story", 2));

        assertEquals("MULTIPLE", result.getMode());
        assertEquals("Once upon a time...", result.getGroup().getPassageText());
        assertEquals(1, result.getGroup().getSubQuestions().size());
    }

    @Test
    void generatePayloadShouldSendNullCategoryAndDifficultyToPromptWhenNotProvidedDespiteComputingFallbackDefaults() {
        String json = "{\"mode\":\"SINGLE\",\"questions\":[]}";
        when(geminiClientService.generateChatResponse(anyString(), any())).thenReturn(json);

        CreateTrainerQuestionAIRequestDTO req = request("SINGLE", "Grammar tenses", 1);
        req.setCategoryId(null);
        req.setDifficultyId(null);
        service.generatePayload(req);

        ArgumentCaptor<java.util.List> historyCaptor = ArgumentCaptor.forClass(java.util.List.class);
        org.mockito.Mockito.verify(geminiClientService).generateChatResponse(anyString(), historyCaptor.capture());
        String userInput = ((com.hango.hango_backend.dto.GeminiGenerateRequest.Content) historyCaptor.getValue().get(0))
                .getParts().get(0).getText();
        assertTrue(userInput.contains("CATEGORY_ID(DEFAULT): null"),
                "GAP-QB-01: generatePayload computes categoryId/difficultyId fallback locals (1L/14L default) "
                        + "but buildUserInput() uses req.getCategoryId()/getDifficultyId() directly, so the computed "
                        + "fallback is dead code — the AI prompt gets the raw null instead of the intended default.");
        assertTrue(userInput.contains("DIFFICULTY_ID(DEFAULT): null"));
    }

    @Test
    void generatePayloadShouldUppercaseModeCaseInsensitively() {
        String json = "{\"mode\":\"SINGLE\",\"questions\":[]}";
        when(geminiClientService.generateChatResponse(anyString(), any())).thenReturn(json);

        service.generatePayload(request("single", "Grammar tenses", 1));

        ArgumentCaptor<String> promptCaptor = ArgumentCaptor.forClass(String.class);
        org.mockito.Mockito.verify(geminiClientService).generateChatResponse(promptCaptor.capture(), any());
        assertTrue(promptCaptor.getValue().contains("SINGLE multiple-choice questions"));
    }

    @Test
    void generatePayloadShouldTreatUnknownModeAsMultipleModeBranch() {
        String json = "{\"mode\":\"MULTIPLE\",\"questions\":[],\"group\":{\"passageText\":\"p\",\"subQuestions\":[]}}";
        when(geminiClientService.generateChatResponse(anyString(), any())).thenReturn(json);

        service.generatePayload(request("BOGUS", "Grammar tenses", 1));

        ArgumentCaptor<String> promptCaptor = ArgumentCaptor.forClass(String.class);
        org.mockito.Mockito.verify(geminiClientService).generateChatResponse(promptCaptor.capture(), any());
        assertTrue(promptCaptor.getValue().contains("reading comprehension"),
                "mode is only validated for blank, not for a known enum value — any non-SINGLE string silently falls through to the MULTIPLE prompt branch");
    }
}
