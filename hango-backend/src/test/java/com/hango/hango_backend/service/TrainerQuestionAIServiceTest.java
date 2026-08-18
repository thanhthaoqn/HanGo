package com.hango.hango_backend.service;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.hango.hango_backend.dto.CreateTrainerExamAIResponseDTO;
import com.hango.hango_backend.dto.CreateTrainerQuestionAIRequestDTO;
import com.hango.hango_backend.dto.CreateTrainerQuestionAIResponseDTO;
import com.hango.hango_backend.dto.TrainerExamChatRequestDTO;
import com.hango.hango_backend.entity.SystemParameter;
import com.hango.hango_backend.exception.ApiException;
import com.hango.hango_backend.repository.SystemParameterRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.util.List;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class TrainerQuestionAIServiceTest {

    @Mock
    private GeminiClientService geminiClientService;

    @Mock
    private SystemParameterRepository systemParameterRepository;

    @Mock
    private SystemConfigService systemConfigService;

    private TrainerQuestionAIService service;

    @BeforeEach
    void setUp() {
        org.mockito.Mockito.lenient().when(systemConfigService.getConfigValue(org.mockito.ArgumentMatchers.anyString(), org.mockito.ArgumentMatchers.anyString(), org.mockito.ArgumentMatchers.anyString()))
                .thenAnswer(invocation -> invocation.getArgument(2));
        service = new TrainerQuestionAIService(geminiClientService, new ObjectMapper(), systemParameterRepository, systemConfigService);
    }

    private SystemParameter param(long id, String value) {
        return SystemParameter.builder().id(id).paramType("SKILL_TYPE").paramValue(value).isActive(true).build();
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

    // =================================================================
    // MULTIPLE mode sub-question skillParamId / difficultyId auto-population
    // =================================================================

    @Test
    void generatePayloadShouldFallBackToFirstActiveSkillAndDifficultyWhenAiOmitsSubQuestionIds() {
        when(systemParameterRepository.findByParamTypeAndIsActiveTrue("SKILL_TYPE"))
                .thenReturn(List.of(param(101, "Main idea"), param(102, "Inference question")));
        when(systemParameterRepository.findByParamTypeAndIsActiveTrue("DIFFICULTY"))
                .thenReturn(List.of(param(14, "Easy"), param(15, "Medium")));

        String json = "{\"mode\":\"MULTIPLE\",\"questions\":[],\"group\":{\"passageText\":\"p\",\"difficultyId\":14,"
                + "\"subQuestions\":[{\"questionText\":\"Q1\",\"options\":[]}]}}";
        when(geminiClientService.generateChatResponse(anyString(), any())).thenReturn(json);

        CreateTrainerQuestionAIResponseDTO result = service.generatePayload(request("MULTIPLE", "A short story", 1));

        CreateTrainerQuestionAIResponseDTO.SubQuestionDTO sub = result.getGroup().getSubQuestions().get(0);
        assertEquals(101L, sub.getSkillParamId());
        assertEquals(14L, sub.getDifficultyId());
    }

    @Test
    void generatePayloadShouldReplaceHallucinatedSubQuestionSkillIdWithFallback() {
        when(systemParameterRepository.findByParamTypeAndIsActiveTrue("SKILL_TYPE"))
                .thenReturn(List.of(param(101, "Main idea")));
        when(systemParameterRepository.findByParamTypeAndIsActiveTrue("DIFFICULTY"))
                .thenReturn(List.of(param(14, "Easy")));

        String json = "{\"mode\":\"MULTIPLE\",\"questions\":[],\"group\":{\"passageText\":\"p\","
                + "\"subQuestions\":[{\"questionText\":\"Q1\",\"skillParamId\":9999,\"difficultyId\":9999,\"options\":[]}]}}";
        when(geminiClientService.generateChatResponse(anyString(), any())).thenReturn(json);

        CreateTrainerQuestionAIResponseDTO result = service.generatePayload(request("MULTIPLE", "A short story", 1));

        CreateTrainerQuestionAIResponseDTO.SubQuestionDTO sub = result.getGroup().getSubQuestions().get(0);
        assertEquals(101L, sub.getSkillParamId());
        assertEquals(14L, sub.getDifficultyId());
    }

    @Test
    void generatePayloadShouldKeepValidPerSubQuestionSkillAndDifficultyChosenByAi() {
        when(systemParameterRepository.findByParamTypeAndIsActiveTrue("SKILL_TYPE"))
                .thenReturn(List.of(param(101, "Main idea"), param(102, "Inference question")));
        when(systemParameterRepository.findByParamTypeAndIsActiveTrue("DIFFICULTY"))
                .thenReturn(List.of(param(14, "Easy"), param(15, "Medium")));

        String json = "{\"mode\":\"MULTIPLE\",\"questions\":[],\"group\":{\"passageText\":\"p\","
                + "\"subQuestions\":["
                + "{\"questionText\":\"Q1\",\"skillParamId\":102,\"difficultyId\":15,\"options\":[]},"
                + "{\"questionText\":\"Q2\",\"skillParamId\":101,\"difficultyId\":14,\"options\":[]}"
                + "]}}";
        when(geminiClientService.generateChatResponse(anyString(), any())).thenReturn(json);

        CreateTrainerQuestionAIResponseDTO result = service.generatePayload(request("MULTIPLE", "A short story", 2));

        assertEquals(102L, result.getGroup().getSubQuestions().get(0).getSkillParamId());
        assertEquals(15L, result.getGroup().getSubQuestions().get(0).getDifficultyId());
        assertEquals(101L, result.getGroup().getSubQuestions().get(1).getSkillParamId());
        assertEquals(14L, result.getGroup().getSubQuestions().get(1).getDifficultyId());
    }

    @Test
    void generatePayloadShouldLeaveSkillAndDifficultyNullWhenNoActiveSystemParametersExist() {
        when(systemParameterRepository.findByParamTypeAndIsActiveTrue("SKILL_TYPE")).thenReturn(List.of());
        when(systemParameterRepository.findByParamTypeAndIsActiveTrue("DIFFICULTY")).thenReturn(List.of());

        String json = "{\"mode\":\"MULTIPLE\",\"questions\":[],\"group\":{\"passageText\":\"p\","
                + "\"subQuestions\":[{\"questionText\":\"Q1\",\"options\":[]}]}}";
        when(geminiClientService.generateChatResponse(anyString(), any())).thenReturn(json);

        CreateTrainerQuestionAIResponseDTO result = service.generatePayload(request("MULTIPLE", "A short story", 1));

        CreateTrainerQuestionAIResponseDTO.SubQuestionDTO sub = result.getGroup().getSubQuestions().get(0);
        assertNull(sub.getSkillParamId());
        assertNull(sub.getDifficultyId());
    }

    @Test
    void generatePayloadShouldIncludeSkillAndDifficultyOptionsInMultiplePrompt() {
        when(systemParameterRepository.findByParamTypeAndIsActiveTrue("SKILL_TYPE"))
                .thenReturn(List.of(param(101, "Main idea")));
        when(systemParameterRepository.findByParamTypeAndIsActiveTrue("DIFFICULTY"))
                .thenReturn(List.of(param(14, "Easy")));

        String json = "{\"mode\":\"MULTIPLE\",\"questions\":[],\"group\":{\"passageText\":\"p\",\"subQuestions\":[]}}";
        when(geminiClientService.generateChatResponse(anyString(), any())).thenReturn(json);

        service.generatePayload(request("MULTIPLE", "A short story", 2));

        ArgumentCaptor<String> promptCaptor = ArgumentCaptor.forClass(String.class);
        org.mockito.Mockito.verify(geminiClientService).generateChatResponse(promptCaptor.capture(), any());
        String prompt = promptCaptor.getValue();
        assertTrue(prompt.contains("101=Main idea"));
        assertTrue(prompt.contains("14=Easy"));
        assertTrue(prompt.contains("skillParamId"));
    }

    @Test
    void generatePayloadShouldNotQuerySystemParametersForSingleMode() {
        String json = "{\"mode\":\"SINGLE\",\"questions\":[]}";
        when(geminiClientService.generateChatResponse(anyString(), any())).thenReturn(json);

        service.generatePayload(request("SINGLE", "Grammar tenses", 1));

        org.mockito.Mockito.verify(systemParameterRepository, org.mockito.Mockito.never())
                .findByParamTypeAndIsActiveTrue(anyString());
    }

    private TrainerExamChatRequestDTO.Message message(String role, String text) {
        return TrainerExamChatRequestDTO.Message.builder().role(role).text(text).build();
    }

    // =================================================================
    // handleExamChat
    // =================================================================

    @Test
    void handleExamChatShouldThrowWhenRequestNull() {
        assertThrows(ApiException.class, () -> service.handleExamChat(null));
    }

    @Test
    void handleExamChatShouldThrowWhenHistoryNullOrEmpty() {
        assertThrows(ApiException.class,
                () -> service.handleExamChat(TrainerExamChatRequestDTO.builder().history(List.of()).build()));
    }

    @Test
    void handleExamChatShouldForwardHistoryAndReturnRawAiReply() {
        when(geminiClientService.generateChatResponse(anyString(), any())).thenReturn("What's the exam title?");

        String reply = service.handleExamChat(TrainerExamChatRequestDTO.builder()
                .history(List.of(message("user", "I want to create a grammar exam"))).build());

        assertEquals("What's the exam title?", reply);
    }

    @Test
    void handleExamChatShouldUseSystemPromptFromConfigServiceWhenOverridden() {
        when(systemConfigService.getConfigValue("AI", "AI_TRAINER_EXAM_CHAT_PROMPT", TrainerQuestionAIService.DEFAULT_CHAT_PROMPT))
                .thenReturn("CUSTOM CHAT PROMPT");
        when(geminiClientService.generateChatResponse(anyString(), any())).thenReturn("ok");

        service.handleExamChat(TrainerExamChatRequestDTO.builder()
                .history(List.of(message("user", "hi"))).build());

        ArgumentCaptor<String> promptCaptor = ArgumentCaptor.forClass(String.class);
        org.mockito.Mockito.verify(geminiClientService).generateChatResponse(promptCaptor.capture(), any());
        assertEquals("CUSTOM CHAT PROMPT", promptCaptor.getValue());
    }

    @Test
    void handleExamChatShouldMapUnknownRoleToUserRole() {
        when(geminiClientService.generateChatResponse(anyString(), any())).thenReturn("ok");

        service.handleExamChat(TrainerExamChatRequestDTO.builder()
                .history(List.of(message("system", "weird role"))).build());

        ArgumentCaptor<List> historyCaptor = ArgumentCaptor.forClass(List.class);
        org.mockito.Mockito.verify(geminiClientService).generateChatResponse(anyString(), historyCaptor.capture());
        String role = ((com.hango.hango_backend.dto.GeminiGenerateRequest.Content) historyCaptor.getValue().get(0)).getRole();
        assertEquals("user", role);
    }

    // =================================================================
    // generateExamFromChat
    // =================================================================

    @Test
    void generateExamFromChatShouldThrowWhenRequestNull() {
        assertThrows(ApiException.class, () -> service.generateExamFromChat(null));
    }

    @Test
    void generateExamFromChatShouldThrowWhenHistoryEmpty() {
        assertThrows(ApiException.class,
                () -> service.generateExamFromChat(TrainerExamChatRequestDTO.builder().history(List.of()).build()));
    }

    @Test
    void generateExamFromChatShouldAppendFinalGenerateJsonPromptToHistory() {
        String json = "{\"title\":\"Grammar Basics\",\"description\":\"d\",\"durationMinutes\":30,"
                + "\"passingScore\":50.0,\"expectedQuestionCount\":5,\"blocks\":[]}";
        when(geminiClientService.generateChatResponse(anyString(), any())).thenReturn(json);

        service.generateExamFromChat(TrainerExamChatRequestDTO.builder()
                .history(List.of(message("user", "Make a 5-question grammar exam"))).build());

        ArgumentCaptor<List> historyCaptor = ArgumentCaptor.forClass(List.class);
        org.mockito.Mockito.verify(geminiClientService).generateChatResponse(anyString(), historyCaptor.capture());
        assertEquals(2, historyCaptor.getValue().size());
        String lastText = ((com.hango.hango_backend.dto.GeminiGenerateRequest.Content) historyCaptor.getValue().get(1))
                .getParts().get(0).getText();
        assertTrue(lastText.contains("Please generate the JSON"));
    }

    @Test
    void generateExamFromChatShouldStripMarkdownFenceAndParseExamJson() {
        String fenced = "```json\n{\"title\":\"Grammar Basics\",\"description\":\"d\",\"durationMinutes\":30,"
                + "\"passingScore\":50.0,\"expectedQuestionCount\":1,\"blocks\":["
                + "{\"isQuestionGroup\":false,\"passageText\":\"\",\"categoryId\":1,\"difficultyId\":14,"
                + "\"questions\":[{\"questionText\":\"2+2?\",\"options\":[]}]}]}\n```";
        when(geminiClientService.generateChatResponse(anyString(), any())).thenReturn(fenced);

        CreateTrainerExamAIResponseDTO result = service.generateExamFromChat(TrainerExamChatRequestDTO.builder()
                .history(List.of(message("user", "go"))).build());

        assertEquals("Grammar Basics", result.getTitle());
        assertEquals(1, result.getBlocks().size());
        assertEquals("2+2?", result.getBlocks().get(0).getQuestions().get(0).getQuestionText());
    }

    @Test
    void generateExamFromChatShouldUseCustomBaseSystemPromptFromConfigService() {
        when(systemConfigService.getConfigValue("AI", "AI_TRAINER_EXAM_GENERATE_PROMPT", TrainerQuestionAIService.DEFAULT_GENERATE_PROMPT))
                .thenReturn("CUSTOM GENERATE PROMPT BASE");
        String json = "{\"title\":\"t\",\"description\":\"d\",\"durationMinutes\":30,"
                + "\"passingScore\":50.0,\"expectedQuestionCount\":1,\"blocks\":[]}";
        when(geminiClientService.generateChatResponse(anyString(), any())).thenReturn(json);

        service.generateExamFromChat(TrainerExamChatRequestDTO.builder()
                .history(List.of(message("user", "go"))).build());

        ArgumentCaptor<String> promptCaptor = ArgumentCaptor.forClass(String.class);
        org.mockito.Mockito.verify(geminiClientService).generateChatResponse(promptCaptor.capture(), any());
        assertTrue(promptCaptor.getValue().startsWith("CUSTOM GENERATE PROMPT BASE"));
    }

    @Test
    void generateExamFromChatShouldThrowBadGatewayWhenAiReturnsInvalidJson() {
        when(geminiClientService.generateChatResponse(anyString(), any())).thenReturn("not json");

        ApiException ex = assertThrows(ApiException.class, () -> service.generateExamFromChat(
                TrainerExamChatRequestDTO.builder().history(List.of(message("user", "go"))).build()));
        assertEquals(502, ex.getStatus().value());
    }
}
