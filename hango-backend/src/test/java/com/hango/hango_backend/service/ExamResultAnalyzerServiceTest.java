package com.hango.hango_backend.service;

import java.math.BigDecimal;
import java.util.List;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertTrue;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.hango.hango_backend.dto.ExamResultAnalysisDTO;
import com.hango.hango_backend.entity.ExamAttempt;
import static org.mockito.Mockito.mock;

class ExamResultAnalyzerServiceTest {

    private ObjectMapper objectMapper;
    private SkillCategoryMappingService skillCategoryMappingService;
    private ExamResultAnalyzerService service;

    @BeforeEach
    void setUp() {
        objectMapper = new ObjectMapper();
        skillCategoryMappingService = mock(SkillCategoryMappingService.class);
        service = new ExamResultAnalyzerService(objectMapper, skillCategoryMappingService);
    }

    private ExamAttempt attempt(Long id, BigDecimal score, String answersJson) {
        ExamAttempt a = new ExamAttempt();
        a.setId(id);
        a.setScore(score);
        a.setAnswersJson(answersJson);
        return a;
    }

    private static final String ONE_INCORRECT_READING_ANSWER =
            "[{\"questionId\":1,\"topic\":\"Detail\",\"skill\":\"Reading\",\"isCorrect\":false,\"userAnswer\":\"A\"},"
          + "{\"questionId\":2,\"topic\":\"Grammar\",\"skill\":\"Grammar\",\"isCorrect\":true,\"userAnswer\":\"B\"}]";

    // =================================================================
    // analyzeLatestExamAttempt
    // =================================================================

    @Test
    void analyzeLatestExamAttemptShouldMapScoreAndRawAnswersJson() {
        ExamAttempt a = attempt(1L, new BigDecimal("7"), ONE_INCORRECT_READING_ANSWER);

        ExamResultAnalysisDTO result = service.analyzeLatestExamAttempt(a);

        assertEquals(1L, result.getExamAttemptId());
        assertEquals(7, result.getScore());
        assertEquals(ONE_INCORRECT_READING_ANSWER, result.getRawAnswersJson());
    }

    @Test
    void analyzeLatestExamAttemptShouldReturnNullScoreWhenAttemptScoreIsNull() {
        ExamAttempt a = attempt(1L, null, ONE_INCORRECT_READING_ANSWER);

        ExamResultAnalysisDTO result = service.analyzeLatestExamAttempt(a);

        assertNull(result.getScore());
        assertTrue(!result.getHints().containsKey("score"));
    }

    @Test
    void analyzeLatestExamAttemptShouldExtractWeakSkillsAndCriticalTopicsFromIncorrectAnswers() {
        ExamAttempt a = attempt(1L, new BigDecimal("6"), ONE_INCORRECT_READING_ANSWER);

        ExamResultAnalysisDTO result = service.analyzeLatestExamAttempt(a);

        assertTrue(result.getKnowledgeGapsJson().contains("Reading"));
        assertTrue(result.getKnowledgeGapsJson().contains("\"incorrect_count\":1"));
        assertTrue(!result.getKnowledgeGapsJson().contains("Grammar"));
    }

    @Test
    void analyzeLatestExamAttemptShouldFallbackToRawJsonWhenAnswersJsonNotAJsonArray() {
        ExamAttempt a = attempt(1L, new BigDecimal("6"), "{}");

        ExamResultAnalysisDTO result = service.analyzeLatestExamAttempt(a);

        assertEquals("{}", result.getKnowledgeGapsJson());
    }

    @Test
    void analyzeLatestExamAttemptShouldReturnEmptyPlaceholderWhenAnswersJsonNull() {
        ExamAttempt a = attempt(1L, new BigDecimal("6"), null);

        ExamResultAnalysisDTO result = service.analyzeLatestExamAttempt(a);

        assertEquals("{}", result.getKnowledgeGapsJson());
    }

    // =================================================================
    // analyzeLearnerAttempts
    // =================================================================

    @Test
    void analyzeLearnerAttemptsShouldReturnEmptyPlaceholderWhenAttemptsListIsEmpty() {
        ExamResultAnalysisDTO result = service.analyzeLearnerAttempts(1L, List.of());

        assertNull(result.getExamAttemptId());
        assertEquals("{}", result.getKnowledgeGapsJson());
        assertEquals(0, result.getHints().get("attemptsUsed"));
    }

    @Test
    void analyzeLearnerAttemptsShouldReturnEmptyPlaceholderWhenAttemptsListIsNull() {
        ExamResultAnalysisDTO result = service.analyzeLearnerAttempts(1L, null);

        assertEquals("{}", result.getKnowledgeGapsJson());
    }

    @Test
    void analyzeLearnerAttemptsShouldComputeAverageMinMaxScoreAcrossAttempts() {
        ExamAttempt a1 = attempt(1L, new BigDecimal("4"), ONE_INCORRECT_READING_ANSWER);
        ExamAttempt a2 = attempt(2L, new BigDecimal("8"), ONE_INCORRECT_READING_ANSWER);

        ExamResultAnalysisDTO result = service.analyzeLearnerAttempts(1L, List.of(a1, a2));

        assertEquals(6.0, result.getHints().get("score_avg"));
        assertTrue(result.getKnowledgeGapsJson().contains("\"score_min\":4"));
        assertTrue(result.getKnowledgeGapsJson().contains("\"score_max\":8"));
    }

    @Test
    void analyzeLearnerAttemptsShouldMergeWeakSkillsAcrossMultipleAttemptsByFrequency() {
        String readingWeak = "[{\"questionId\":1,\"topic\":\"Detail\",\"skill\":\"Reading\",\"isCorrect\":false}]";
        String listeningWeak = "[{\"questionId\":2,\"topic\":\"Audio\",\"skill\":\"Listening\",\"isCorrect\":false}]";
        ExamAttempt a1 = attempt(1L, new BigDecimal("5"), readingWeak);
        ExamAttempt a2 = attempt(2L, new BigDecimal("5"), readingWeak);
        ExamAttempt a3 = attempt(3L, new BigDecimal("5"), listeningWeak);

        ExamResultAnalysisDTO result = service.analyzeLearnerAttempts(1L, List.of(a3, a2, a1));

        assertTrue(result.getKnowledgeGapsJson().indexOf("Reading") < result.getKnowledgeGapsJson().indexOf("Listening"),
                "Reading appears in 2 attempts vs Listening's 1 — should be sorted first by frequency");
    }

    @Test
    void analyzeLearnerAttemptsShouldUseFirstAttemptInListAsLatestForRawAnswersJson() {
        ExamAttempt latest = attempt(9L, new BigDecimal("7"), ONE_INCORRECT_READING_ANSWER);
        ExamAttempt older = attempt(1L, new BigDecimal("3"), "[]");

        ExamResultAnalysisDTO result = service.analyzeLearnerAttempts(1L, List.of(latest, older));

        assertEquals(9L, result.getExamAttemptId());
        assertEquals(ONE_INCORRECT_READING_ANSWER, result.getRawAnswersJson());
    }

    @Test
    void analyzeLearnerAttemptsShouldSkipAttemptsWithNullScoreInAverageCalculation() {
        ExamAttempt scored = attempt(1L, new BigDecimal("10"), "[]");
        ExamAttempt unscored = attempt(2L, null, "[]");

        ExamResultAnalysisDTO result = service.analyzeLearnerAttempts(1L, List.of(scored, unscored));

        assertEquals(10.0, result.getHints().get("score_avg"));
    }
}
