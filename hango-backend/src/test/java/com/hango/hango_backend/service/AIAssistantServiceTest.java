package com.hango.hango_backend.service;

import com.hango.hango_backend.dto.GeminiGenerateRequest;
import com.hango.hango_backend.dto.LessonDetailDTO;
import com.hango.hango_backend.dto.QuizQuestionDTO;
import com.hango.hango_backend.dto.SendMessageRequest;
import com.hango.hango_backend.dto.SendMessageResponse;
import com.hango.hango_backend.entity.AIConversation;
import com.hango.hango_backend.entity.AIMessage;
import com.hango.hango_backend.entity.Lesson;
import com.hango.hango_backend.entity.User;
import com.hango.hango_backend.exception.ApiException;
import com.hango.hango_backend.repository.AIConversationRepository;
import com.hango.hango_backend.repository.LessonRepository;
import com.hango.hango_backend.repository.UserRepository;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.http.HttpStatus;

import java.util.List;
import java.util.Optional;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyLong;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class AIAssistantServiceTest {

    @Mock
    private AIConversationRepository conversationRepository;
    @Mock
    private LessonRepository lessonRepository;
    @Mock
    private UserRepository userRepository;
    @Mock
    private ScopeGuardrailService scopeGuardrailService;
    @Mock
    private AIPromptBuilder promptBuilder;
    @Mock
    private GeminiClientService geminiClientService;
    @Mock
    private LessonService lessonService;

    @InjectMocks
    private AIAssistantService service;

    private Lesson lesson(Long id) {
        return Lesson.builder().id(id).title("Present Perfect").content("Grammar content").build();
    }

    private User learner(Long id) {
        return User.builder().id(id).email("learner@example.com").build();
    }

    private SendMessageRequest request(Long conversationId, Long lessonId, String message) {
        SendMessageRequest req = new SendMessageRequest();
        req.setConversationId(conversationId);
        req.setLessonId(lessonId);
        req.setMessage(message);
        return req;
    }

    private void stubNoLessonDetail(Long lessonId, Long learnerId) {
        when(lessonService.getLessonDetail(lessonId, learnerId)).thenReturn(
                LessonDetailDTO.builder().id(lessonId).questions(List.of()).build());
    }

    // =================================================================
    // sendMessage
    // =================================================================

    @Test
    void sendMessageShouldThrowUnauthorizedWhenLearnerIdNull() {
        ApiException ex = assertThrows(ApiException.class, () -> service.sendMessage(null, request(null, 1L, "Hello there!")));
        assertEquals(HttpStatus.UNAUTHORIZED, ex.getStatus());
    }

    @Test
    void sendMessageShouldThrowNotFoundWhenLessonMissing() {
        when(lessonRepository.findById(1L)).thenReturn(Optional.empty());

        ApiException ex = assertThrows(ApiException.class, () -> service.sendMessage(1L, request(null, 1L, "Hello there!")));
        assertEquals(HttpStatus.NOT_FOUND, ex.getStatus());
    }

    @Test
    void sendMessageShouldThrowNotFoundWhenLearnerMissingDuringNewConversationCreation() {
        Lesson l = lesson(1L);
        when(lessonRepository.findById(1L)).thenReturn(Optional.of(l));
        when(userRepository.findById(1L)).thenReturn(Optional.empty());

        ApiException ex = assertThrows(ApiException.class, () -> service.sendMessage(1L, request(null, 1L, "Hello there!")));
        assertEquals(HttpStatus.NOT_FOUND, ex.getStatus());
    }

    private AIConversation newConversation(Long id, Lesson l, User learner) {
        AIConversation c = AIConversation.builder().id(id).lesson(l).learner(learner).messages(new java.util.ArrayList<>()).build();
        return c;
    }

    @Test
    void sendMessageShouldCreateNewConversationWhenConversationIdNull() {
        Lesson l = lesson(1L);
        User u = learner(1L);
        when(lessonRepository.findById(1L)).thenReturn(Optional.of(l));
        when(userRepository.findById(1L)).thenReturn(Optional.of(u));
        AIConversation saved = newConversation(500L, l, u);
        when(conversationRepository.save(any(AIConversation.class))).thenReturn(saved).thenReturn(saved);
        stubNoLessonDetail(1L, 1L);
        when(scopeGuardrailService.checkScope(eq(l), anyString(), any())).thenReturn(
                new ScopeGuardrailService.ScopeCheckResult(false, 0.1));
        when(promptBuilder.buildOutOfScopeFallback(l)).thenReturn("Out of scope reply");

        SendMessageResponse response = service.sendMessage(1L, request(null, 1L, "Hello there!"));

        assertEquals(500L, response.getConversationId());
        verify(userRepository).findById(1L);
    }

    @Test
    void sendMessageShouldReuseExistingConversationWhenValidConversationIdProvided() {
        Lesson l = lesson(1L);
        User u = learner(1L);
        AIConversation existing = newConversation(10L, l, u);
        when(lessonRepository.findById(1L)).thenReturn(Optional.of(l));
        when(conversationRepository.findByIdAndLearnerIdWithMessages(10L, 1L)).thenReturn(Optional.of(existing));
        when(conversationRepository.save(any(AIConversation.class))).thenReturn(existing);
        stubNoLessonDetail(1L, 1L);
        when(scopeGuardrailService.checkScope(eq(l), anyString(), any())).thenReturn(
                new ScopeGuardrailService.ScopeCheckResult(false, 0.1));
        when(promptBuilder.buildOutOfScopeFallback(l)).thenReturn("Out of scope reply");

        SendMessageResponse response = service.sendMessage(1L, request(10L, 1L, "Hello there!"));

        assertEquals(10L, response.getConversationId());
        verify(userRepository, never()).findById(any());
    }

    @Test
    void sendMessageShouldFallBackToNewConversationWhenConversationIdNotFound() {
        Lesson l = lesson(1L);
        User u = learner(1L);
        when(lessonRepository.findById(1L)).thenReturn(Optional.of(l));
        when(conversationRepository.findByIdAndLearnerIdWithMessages(99L, 1L)).thenReturn(Optional.empty());
        when(userRepository.findById(1L)).thenReturn(Optional.of(u));
        AIConversation created = newConversation(501L, l, u);
        when(conversationRepository.save(any(AIConversation.class))).thenReturn(created);
        stubNoLessonDetail(1L, 1L);
        when(scopeGuardrailService.checkScope(eq(l), anyString(), any())).thenReturn(
                new ScopeGuardrailService.ScopeCheckResult(false, 0.1));
        when(promptBuilder.buildOutOfScopeFallback(l)).thenReturn("Out of scope reply");

        SendMessageResponse response = service.sendMessage(1L, request(99L, 1L, "Hello there!"));

        assertEquals(501L, response.getConversationId());
    }

    @Test
    void sendMessageShouldFallBackToNewConversationWhenRepositoryLookupThrows() {
        Lesson l = lesson(1L);
        User u = learner(1L);
        when(lessonRepository.findById(1L)).thenReturn(Optional.of(l));
        when(conversationRepository.findByIdAndLearnerIdWithMessages(10L, 1L)).thenThrow(new RuntimeException("DB error"));
        when(userRepository.findById(1L)).thenReturn(Optional.of(u));
        AIConversation created = newConversation(502L, l, u);
        when(conversationRepository.save(any(AIConversation.class))).thenReturn(created);
        stubNoLessonDetail(1L, 1L);
        when(scopeGuardrailService.checkScope(eq(l), anyString(), any())).thenReturn(
                new ScopeGuardrailService.ScopeCheckResult(false, 0.1));
        when(promptBuilder.buildOutOfScopeFallback(l)).thenReturn("Out of scope reply");

        SendMessageResponse response = service.sendMessage(1L, request(10L, 1L, "Hello there!"));

        assertEquals(502L, response.getConversationId());
    }

    @Test
    void sendMessageShouldTreatZeroConversationIdAsNewConversation() {
        Lesson l = lesson(1L);
        User u = learner(1L);
        when(lessonRepository.findById(1L)).thenReturn(Optional.of(l));
        when(userRepository.findById(1L)).thenReturn(Optional.of(u));
        AIConversation created = newConversation(503L, l, u);
        when(conversationRepository.save(any(AIConversation.class))).thenReturn(created);
        stubNoLessonDetail(1L, 1L);
        when(scopeGuardrailService.checkScope(eq(l), anyString(), any())).thenReturn(
                new ScopeGuardrailService.ScopeCheckResult(false, 0.1));
        when(promptBuilder.buildOutOfScopeFallback(l)).thenReturn("Out of scope reply");

        service.sendMessage(1L, request(0L, 1L, "Hello there!"));

        verify(conversationRepository, never()).findByIdAndLearnerIdWithMessages(any(), any());
    }

    @Test
    void sendMessageShouldUseOutOfScopeFallbackAndSkipGeminiChatWhenOutOfScope() {
        Lesson l = lesson(1L);
        User u = learner(1L);
        AIConversation existing = newConversation(10L, l, u);
        when(lessonRepository.findById(1L)).thenReturn(Optional.of(l));
        when(conversationRepository.findByIdAndLearnerIdWithMessages(10L, 1L)).thenReturn(Optional.of(existing));
        when(conversationRepository.save(any(AIConversation.class))).thenReturn(existing);
        stubNoLessonDetail(1L, 1L);
        when(scopeGuardrailService.checkScope(eq(l), anyString(), any())).thenReturn(
                new ScopeGuardrailService.ScopeCheckResult(false, 0.2));
        when(promptBuilder.buildOutOfScopeFallback(l)).thenReturn("This is out of scope.");

        SendMessageResponse response = service.sendMessage(1L, request(10L, 1L, "What's the weather today?"));

        assertTrue(response.isWasOutOfScope());
        assertEquals("This is out of scope.", response.getReply());
        assertTrue(response.getSuggestedQuestions().isEmpty());
        verify(geminiClientService, never()).generateChatResponse(anyString(), any());
    }

    @Test
    void sendMessageShouldCallGeminiWithBuiltPromptWhenInScope() {
        Lesson l = lesson(1L);
        User u = learner(1L);
        AIConversation existing = newConversation(10L, l, u);
        when(lessonRepository.findById(1L)).thenReturn(Optional.of(l));
        when(conversationRepository.findByIdAndLearnerIdWithMessages(10L, 1L)).thenReturn(Optional.of(existing));
        when(conversationRepository.save(any(AIConversation.class))).thenReturn(existing);
        stubNoLessonDetail(1L, 1L);
        when(scopeGuardrailService.checkScope(eq(l), anyString(), any())).thenReturn(
                new ScopeGuardrailService.ScopeCheckResult(true, 0.9));
        when(promptBuilder.buildSystemPrompt(eq(l), any())).thenReturn("SYSTEM_PROMPT");
        when(geminiClientService.generateChatResponse(eq("SYSTEM_PROMPT"), any())).thenReturn("Here is the answer.");

        SendMessageResponse response = service.sendMessage(1L, request(10L, 1L, "Explain present perfect."));

        assertFalse(response.isWasOutOfScope());
        assertEquals("Here is the answer.", response.getReply());
    }

    @Test
    void sendMessageShouldExcludePreviouslyOutOfScopeMessagesFromGeminiHistory() {
        Lesson l = lesson(1L);
        User u = learner(1L);
        AIConversation existing = newConversation(10L, l, u);
        AIMessage blockedMsg = AIMessage.builder().role(AIMessage.MessageRole.USER).content("irrelevant question").wasOutOfScope(true).build();
        AIMessage keptMsg = AIMessage.builder().role(AIMessage.MessageRole.ASSISTANT).content("previous answer").wasOutOfScope(false).build();
        existing.getMessages().add(blockedMsg);
        existing.getMessages().add(keptMsg);
        when(lessonRepository.findById(1L)).thenReturn(Optional.of(l));
        when(conversationRepository.findByIdAndLearnerIdWithMessages(10L, 1L)).thenReturn(Optional.of(existing));
        when(conversationRepository.save(any(AIConversation.class))).thenReturn(existing);
        stubNoLessonDetail(1L, 1L);
        when(scopeGuardrailService.checkScope(eq(l), anyString(), any())).thenReturn(
                new ScopeGuardrailService.ScopeCheckResult(true, 0.9));
        when(promptBuilder.buildSystemPrompt(eq(l), any())).thenReturn("SYSTEM_PROMPT");
        when(geminiClientService.generateChatResponse(eq("SYSTEM_PROMPT"), any())).thenReturn("Here is the answer.");

        service.sendMessage(1L, request(10L, 1L, "Follow-up question"));

        @SuppressWarnings("unchecked")
        ArgumentCaptor<List<GeminiGenerateRequest.Content>> historyCaptor = ArgumentCaptor.forClass(List.class);
        verify(geminiClientService).generateChatResponse(eq("SYSTEM_PROMPT"), historyCaptor.capture());
        List<GeminiGenerateRequest.Content> history = historyCaptor.getValue();
        // blocked message excluded; kept message (as "model") + current user message included = 2 entries
        assertEquals(2, history.size());
        assertEquals("model", history.get(0).getRole());
    }

    @Test
    void sendMessageShouldSaveBothUserAndAssistantMessagesToConversation() {
        Lesson l = lesson(1L);
        User u = learner(1L);
        AIConversation existing = newConversation(10L, l, u);
        when(lessonRepository.findById(1L)).thenReturn(Optional.of(l));
        when(conversationRepository.findByIdAndLearnerIdWithMessages(10L, 1L)).thenReturn(Optional.of(existing));
        when(conversationRepository.save(any(AIConversation.class))).thenReturn(existing);
        stubNoLessonDetail(1L, 1L);
        when(scopeGuardrailService.checkScope(eq(l), anyString(), any())).thenReturn(
                new ScopeGuardrailService.ScopeCheckResult(true, 0.9));
        when(promptBuilder.buildSystemPrompt(eq(l), any())).thenReturn("SYSTEM_PROMPT");
        when(geminiClientService.generateChatResponse(anyString(), any())).thenReturn("Here is the answer.");

        service.sendMessage(1L, request(10L, 1L, "Explain present perfect."));

        assertEquals(2, existing.getMessages().size());
        assertEquals(AIMessage.MessageRole.USER, existing.getMessages().get(0).getRole());
        assertEquals(AIMessage.MessageRole.ASSISTANT, existing.getMessages().get(1).getRole());
        verify(conversationRepository, org.mockito.Mockito.atLeastOnce()).save(existing);
    }

    @Test
    void sendMessageShouldParseSuggestedQuestionsFromGeminiJsonResponse() {
        Lesson l = lesson(1L);
        User u = learner(1L);
        AIConversation existing = newConversation(10L, l, u);
        when(lessonRepository.findById(1L)).thenReturn(Optional.of(l));
        when(conversationRepository.findByIdAndLearnerIdWithMessages(10L, 1L)).thenReturn(Optional.of(existing));
        when(conversationRepository.save(any(AIConversation.class))).thenReturn(existing);
        stubNoLessonDetail(1L, 1L);
        when(scopeGuardrailService.checkScope(eq(l), anyString(), any())).thenReturn(
                new ScopeGuardrailService.ScopeCheckResult(true, 0.9));
        when(promptBuilder.buildSystemPrompt(eq(l), any())).thenReturn("SYSTEM_PROMPT");
        when(geminiClientService.generateChatResponse(eq("SYSTEM_PROMPT"), any())).thenReturn("Here is the answer.");
        when(geminiClientService.generateChatResponse(org.mockito.ArgumentMatchers.contains("gợi ý"), any()))
                .thenReturn("{\"suggestedQuestions\":[\"Q1?\",\"Q2?\",\"Q3?\"]}");

        SendMessageResponse response = service.sendMessage(1L, request(10L, 1L, "Explain present perfect."));

        assertEquals(List.of("Q1?", "Q2?", "Q3?"), response.getSuggestedQuestions());
    }

    @Test
    void sendMessageShouldCapSuggestedQuestionsAtThreeWhenGeminiReturnsMore() {
        Lesson l = lesson(1L);
        User u = learner(1L);
        AIConversation existing = newConversation(10L, l, u);
        when(lessonRepository.findById(1L)).thenReturn(Optional.of(l));
        when(conversationRepository.findByIdAndLearnerIdWithMessages(10L, 1L)).thenReturn(Optional.of(existing));
        when(conversationRepository.save(any(AIConversation.class))).thenReturn(existing);
        stubNoLessonDetail(1L, 1L);
        when(scopeGuardrailService.checkScope(eq(l), anyString(), any())).thenReturn(
                new ScopeGuardrailService.ScopeCheckResult(true, 0.9));
        when(promptBuilder.buildSystemPrompt(eq(l), any())).thenReturn("SYSTEM_PROMPT");
        when(geminiClientService.generateChatResponse(eq("SYSTEM_PROMPT"), any())).thenReturn("Here is the answer.");
        when(geminiClientService.generateChatResponse(org.mockito.ArgumentMatchers.contains("gợi ý"), any()))
                .thenReturn("{\"suggestedQuestions\":[\"Q1?\",\"Q2?\",\"Q3?\",\"Q4?\",\"Q5?\"]}");

        SendMessageResponse response = service.sendMessage(1L, request(10L, 1L, "Explain present perfect."));

        assertEquals(3, response.getSuggestedQuestions().size());
    }

    @Test
    void sendMessageShouldReturnEmptySuggestedQuestionsWhenSuggestionCallThrows() {
        Lesson l = lesson(1L);
        User u = learner(1L);
        AIConversation existing = newConversation(10L, l, u);
        when(lessonRepository.findById(1L)).thenReturn(Optional.of(l));
        when(conversationRepository.findByIdAndLearnerIdWithMessages(10L, 1L)).thenReturn(Optional.of(existing));
        when(conversationRepository.save(any(AIConversation.class))).thenReturn(existing);
        stubNoLessonDetail(1L, 1L);
        when(scopeGuardrailService.checkScope(eq(l), anyString(), any())).thenReturn(
                new ScopeGuardrailService.ScopeCheckResult(true, 0.9));
        when(promptBuilder.buildSystemPrompt(eq(l), any())).thenReturn("SYSTEM_PROMPT");
        when(geminiClientService.generateChatResponse(eq("SYSTEM_PROMPT"), any())).thenReturn("Here is the answer.");
        when(geminiClientService.generateChatResponse(org.mockito.ArgumentMatchers.contains("gợi ý"), any()))
                .thenThrow(new RuntimeException("Gemini down"));

        SendMessageResponse response = service.sendMessage(1L, request(10L, 1L, "Explain present perfect."));

        assertEquals("Here is the answer.", response.getReply());
        assertTrue(response.getSuggestedQuestions().isEmpty());
    }

    @Test
    void sendMessageShouldReturnEmptySuggestedQuestionsWhenGeminiResponseHasNoJsonArray() {
        Lesson l = lesson(1L);
        User u = learner(1L);
        AIConversation existing = newConversation(10L, l, u);
        when(lessonRepository.findById(1L)).thenReturn(Optional.of(l));
        when(conversationRepository.findByIdAndLearnerIdWithMessages(10L, 1L)).thenReturn(Optional.of(existing));
        when(conversationRepository.save(any(AIConversation.class))).thenReturn(existing);
        stubNoLessonDetail(1L, 1L);
        when(scopeGuardrailService.checkScope(eq(l), anyString(), any())).thenReturn(
                new ScopeGuardrailService.ScopeCheckResult(true, 0.9));
        when(promptBuilder.buildSystemPrompt(eq(l), any())).thenReturn("SYSTEM_PROMPT");
        when(geminiClientService.generateChatResponse(eq("SYSTEM_PROMPT"), any())).thenReturn("Here is the answer.");
        when(geminiClientService.generateChatResponse(org.mockito.ArgumentMatchers.contains("gợi ý"), any()))
                .thenReturn("Sorry, I cannot help with that right now.");

        SendMessageResponse response = service.sendMessage(1L, request(10L, 1L, "Explain present perfect."));

        assertEquals("Here is the answer.", response.getReply());
        assertTrue(response.getSuggestedQuestions().isEmpty());
    }

    @Test
    void sendMessageShouldReturnFewerThanThreeSuggestedQuestionsWhenGeminiReturnsFewer() {
        Lesson l = lesson(1L);
        User u = learner(1L);
        AIConversation existing = newConversation(10L, l, u);
        when(lessonRepository.findById(1L)).thenReturn(Optional.of(l));
        when(conversationRepository.findByIdAndLearnerIdWithMessages(10L, 1L)).thenReturn(Optional.of(existing));
        when(conversationRepository.save(any(AIConversation.class))).thenReturn(existing);
        stubNoLessonDetail(1L, 1L);
        when(scopeGuardrailService.checkScope(eq(l), anyString(), any())).thenReturn(
                new ScopeGuardrailService.ScopeCheckResult(true, 0.9));
        when(promptBuilder.buildSystemPrompt(eq(l), any())).thenReturn("SYSTEM_PROMPT");
        when(geminiClientService.generateChatResponse(eq("SYSTEM_PROMPT"), any())).thenReturn("Here is the answer.");
        when(geminiClientService.generateChatResponse(org.mockito.ArgumentMatchers.contains("gợi ý"), any()))
                .thenReturn("{\"suggestedQuestions\":[\"Q1?\"]}");

        SendMessageResponse response = service.sendMessage(1L, request(10L, 1L, "Explain present perfect."));

        assertEquals(List.of("Q1?"), response.getSuggestedQuestions());
    }

    @Test
    void sendMessageShouldDefaultToEmptyPracticeQuestionsWhenLessonDetailIsNull() {
        Lesson l = lesson(1L);
        User u = learner(1L);
        AIConversation existing = newConversation(10L, l, u);
        when(lessonRepository.findById(1L)).thenReturn(Optional.of(l));
        when(conversationRepository.findByIdAndLearnerIdWithMessages(10L, 1L)).thenReturn(Optional.of(existing));
        when(conversationRepository.save(any(AIConversation.class))).thenReturn(existing);
        when(lessonService.getLessonDetail(1L, 1L)).thenReturn(null);
        when(scopeGuardrailService.checkScope(eq(l), anyString(), eq(List.of()))).thenReturn(
                new ScopeGuardrailService.ScopeCheckResult(true, 0.9));
        when(promptBuilder.buildSystemPrompt(eq(l), eq(List.of()))).thenReturn("SYSTEM_PROMPT");
        when(geminiClientService.generateChatResponse(eq("SYSTEM_PROMPT"), any())).thenReturn("Here is the answer.");

        SendMessageResponse response = service.sendMessage(1L, request(10L, 1L, "Explain present perfect."));

        assertEquals("Here is the answer.", response.getReply());
        verify(scopeGuardrailService).checkScope(eq(l), anyString(), eq(List.of()));
    }

    @Test
    void sendMessageShouldForwardNonEmptyPracticeQuestionsFromLessonDetailToScopeCheckAndPromptBuilder() {
        Lesson l = lesson(1L);
        User u = learner(1L);
        AIConversation existing = newConversation(10L, l, u);
        List<QuizQuestionDTO> questions = List.of(QuizQuestionDTO.builder().questionText("What is present perfect?").build());
        when(lessonRepository.findById(1L)).thenReturn(Optional.of(l));
        when(conversationRepository.findByIdAndLearnerIdWithMessages(10L, 1L)).thenReturn(Optional.of(existing));
        when(conversationRepository.save(any(AIConversation.class))).thenReturn(existing);
        when(lessonService.getLessonDetail(1L, 1L)).thenReturn(LessonDetailDTO.builder().id(1L).questions(questions).build());
        when(scopeGuardrailService.checkScope(eq(l), anyString(), eq(questions))).thenReturn(
                new ScopeGuardrailService.ScopeCheckResult(true, 0.9));
        when(promptBuilder.buildSystemPrompt(eq(l), eq(questions))).thenReturn("SYSTEM_PROMPT");
        when(geminiClientService.generateChatResponse(eq("SYSTEM_PROMPT"), any())).thenReturn("Here is the answer.");

        service.sendMessage(1L, request(10L, 1L, "Explain present perfect."));

        verify(scopeGuardrailService).checkScope(eq(l), anyString(), eq(questions));
        verify(promptBuilder).buildSystemPrompt(eq(l), eq(questions));
    }

    // =================================================================
    // getConversationHistory
    // =================================================================

    @Test
    void getConversationHistoryShouldDelegateToRepository() {
        when(conversationRepository.findByLearnerIdOrderByStartedAtDesc(1L)).thenReturn(List.of());

        List<AIConversation> result = service.getConversationHistory(1L);

        assertTrue(result.isEmpty());
        verify(conversationRepository).findByLearnerIdOrderByStartedAtDesc(1L);
    }
}
