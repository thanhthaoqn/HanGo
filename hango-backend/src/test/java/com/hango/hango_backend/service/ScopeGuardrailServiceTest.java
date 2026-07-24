package com.hango.hango_backend.service;

import com.hango.hango_backend.config.AIAssistantProperties;
import com.hango.hango_backend.dto.QuizQuestionDTO;
import com.hango.hango_backend.entity.Lesson;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.util.List;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class ScopeGuardrailServiceTest {

    @Mock
    private GeminiClientService geminiClientService;
    @Mock
    private LessonEmbeddingService lessonEmbeddingService;

    private ScopeGuardrailService service;

    private AIAssistantProperties properties(double threshold) {
        AIAssistantProperties props = new AIAssistantProperties();
        props.setScopeSimilarityThreshold(threshold);
        return props;
    }

    private Lesson lesson(String content) {
        return Lesson.builder().id(1L).title("Present Perfect").content(content).build();
    }

    // =================================================================
    // checkScope
    // =================================================================

    @Test
    void checkScopeShouldSkipEmbeddingCheckForVeryShortMessages() {
        service = new ScopeGuardrailService(geminiClientService, lessonEmbeddingService, properties(0.7));

        ScopeGuardrailService.ScopeCheckResult result = service.checkScope(lesson("content"), "hi");

        assertTrue(result.inScope());
        assertEquals(1.0, result.similarityScore());
        verify(geminiClientService, never()).generateEmbedding(anyString());
    }

    @Test
    void checkScopeShouldReturnInScopeWhenSimilarityAboveThreshold() {
        service = new ScopeGuardrailService(geminiClientService, lessonEmbeddingService, properties(0.7));
        when(geminiClientService.generateEmbedding("content")).thenReturn(List.of(1.0, 0.0));
        when(geminiClientService.generateEmbedding("What is present perfect tense?")).thenReturn(List.of(1.0, 0.0));

        ScopeGuardrailService.ScopeCheckResult result = service.checkScope(lesson("content"), "What is present perfect tense?");

        assertTrue(result.inScope());
        assertEquals(1.0, result.similarityScore(), 0.0001);
    }

    @Test
    void checkScopeShouldReturnOutOfScopeWhenSimilarityBelowThreshold() {
        service = new ScopeGuardrailService(geminiClientService, lessonEmbeddingService, properties(0.7));
        when(geminiClientService.generateEmbedding("content")).thenReturn(List.of(1.0, 0.0));
        when(geminiClientService.generateEmbedding("What's the weather today?")).thenReturn(List.of(0.0, 1.0));

        ScopeGuardrailService.ScopeCheckResult result = service.checkScope(lesson("content"), "What's the weather today?");

        assertFalse(result.inScope());
    }

    @Test
    void checkScopeShouldFallBackToInScopeWhenEmbeddingCallThrows() {
        service = new ScopeGuardrailService(geminiClientService, lessonEmbeddingService, properties(0.7));
        when(geminiClientService.generateEmbedding(anyString())).thenThrow(new RuntimeException("Gemini 429"));

        ScopeGuardrailService.ScopeCheckResult result = service.checkScope(lesson("content"), "What is present perfect tense?");

        assertTrue(result.inScope());
        assertEquals(1.0, result.similarityScore());
    }

    @Test
    void checkScopeShouldIncludePracticeQuestionTextInScopeEmbeddingInput() {
        service = new ScopeGuardrailService(geminiClientService, lessonEmbeddingService, properties(0.7));
        QuizQuestionDTO practiceQuestion = QuizQuestionDTO.builder()
                .questionText("Fill in the blank with correct tense")
                .passage("passage text")
                .options(List.of("A", "B"))
                .explanation("explanation text")
                .build();
        when(geminiClientService.generateEmbedding(anyString())).thenReturn(List.of(1.0, 0.0));

        service.checkScope(lesson("content"), "What is present perfect tense?", List.of(practiceQuestion));

        verify(geminiClientService).generateEmbedding(org.mockito.ArgumentMatchers.contains("Fill in the blank with correct tense"));
    }

    @Test
    void checkScopeTwoArgOverloadShouldUseEmptyPracticeQuestionsList() {
        service = new ScopeGuardrailService(geminiClientService, lessonEmbeddingService, properties(0.7));
        when(geminiClientService.generateEmbedding(anyString())).thenReturn(List.of(1.0, 0.0));

        ScopeGuardrailService.ScopeCheckResult result = service.checkScope(lesson("content"), "What is present perfect tense?");

        assertTrue(result.inScope());
    }

    @Test
    void checkScopeShouldTreatSimilarityExactlyAtThresholdAsInScope() {
        service = new ScopeGuardrailService(geminiClientService, lessonEmbeddingService, properties(1.0));
        when(geminiClientService.generateEmbedding(anyString())).thenReturn(List.of(1.0, 0.0));

        ScopeGuardrailService.ScopeCheckResult result = service.checkScope(lesson("content"), "What is present perfect tense?");

        assertTrue(result.inScope());
    }
}
