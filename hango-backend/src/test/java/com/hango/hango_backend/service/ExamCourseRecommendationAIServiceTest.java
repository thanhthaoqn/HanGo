package com.hango.hango_backend.service;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.hango.hango_backend.dto.ExamCourseRecommendationAIResponseDTO;
import com.hango.hango_backend.dto.ExamResultAnalysisDTO;
import com.hango.hango_backend.entity.Course;
import com.hango.hango_backend.entity.ExamAttempt;
import com.hango.hango_backend.entity.SystemParameter;
import com.hango.hango_backend.exeption.ApiException;
import com.hango.hango_backend.repository.CourseRepository;
import com.hango.hango_backend.repository.ExamAttemptRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.http.HttpStatus;

import java.time.LocalDateTime;
import java.util.List;
import java.util.Map;
import java.util.Optional;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class ExamCourseRecommendationAIServiceTest {

    @Mock
    private ExamAttemptRepository examAttemptRepository;
    @Mock
    private CourseRepository courseRepository;
    @Mock
    private ExamResultAnalyzerService examResultAnalyzerService;
    @Mock
    private GeminiClientService geminiClientService;

    private ExamCourseRecommendationAIService service;

    @BeforeEach
    void setUp() {
        service = new ExamCourseRecommendationAIService(
                examAttemptRepository, courseRepository, examResultAnalyzerService, geminiClientService, new ObjectMapper());
    }

    private ExamAttempt attempt(Long id) {
        ExamAttempt a = new ExamAttempt();
        a.setId(id);
        return a;
    }

    private ExamResultAnalysisDTO analysis(Integer scoreAvg) {
        return ExamResultAnalysisDTO.builder()
                .hints(scoreAvg == null ? null : Map.of("score_avg", scoreAvg))
                .knowledgeGapsJson("{}")
                .build();
    }

    // =================================================================
    // recommendCoursesAI
    // =================================================================

    @Test
    void recommendCoursesAIShouldThrowBadRequestWhenExamAttemptIdIsNull() {
        ApiException ex = assertThrows(ApiException.class, () -> service.recommendCoursesAI(null));

        assertEquals(HttpStatus.BAD_REQUEST, ex.getStatus());
    }

    @Test
    void recommendCoursesAIShouldThrowNotFoundWhenExamAttemptDoesNotExist() {
        when(examAttemptRepository.findById(99L)).thenReturn(Optional.empty());

        ApiException ex = assertThrows(ApiException.class, () -> service.recommendCoursesAI(99L));

        assertEquals(HttpStatus.NOT_FOUND, ex.getStatus());
    }

    @Test
    void recommendCoursesAIShouldReturnAiRecommendationsMappedToExistingCourses() {
        when(examAttemptRepository.findById(1L)).thenReturn(Optional.of(attempt(1L)));
        when(examResultAnalyzerService.analyzeLatestExamAttempt(any())).thenReturn(analysis(6));
        Course course = Course.builder().id(10L).title("Grammar Basics").build();
        when(courseRepository.findAll()).thenReturn(List.of(course));
        String aiJson = "{\"weaknessSummary\":\"You're doing well overall.\","
                + "\"recommendedCourses\":[{\"courseId\":10,\"reasonWhy\":\"Matches your grammar gaps.\"}]}";
        when(geminiClientService.generateChatResponse(any(), any())).thenReturn(aiJson);

        ExamCourseRecommendationAIResponseDTO result = service.recommendCoursesAI(1L);

        assertEquals(1L, result.getExamAttemptId());
        assertEquals("You're doing well overall.", result.getWeaknessSummary());
        assertEquals(1, result.getRecommendedCourses().size());
        assertEquals(10L, result.getRecommendedCourses().get(0).getCourseId());
        assertEquals("Grammar Basics", result.getRecommendedCourses().get(0).getTitle());
        assertEquals("Matches your grammar gaps.", result.getRecommendedCourses().get(0).getReasonWhy());
    }

    @Test
    void recommendCoursesAIShouldStripMarkdownCodeFenceBeforeParsingAiResponse() {
        when(examAttemptRepository.findById(1L)).thenReturn(Optional.of(attempt(1L)));
        when(examResultAnalyzerService.analyzeLatestExamAttempt(any())).thenReturn(analysis(null));
        Course course = Course.builder().id(10L).title("Grammar Basics").build();
        when(courseRepository.findAll()).thenReturn(List.of(course));
        String fencedJson = "```json\n{\"weaknessSummary\":\"Great job!\","
                + "\"recommendedCourses\":[{\"courseId\":10,\"reasonWhy\":\"Keep it up.\"}]}\n```";
        when(geminiClientService.generateChatResponse(any(), any())).thenReturn(fencedJson);

        ExamCourseRecommendationAIResponseDTO result = service.recommendCoursesAI(1L);

        assertEquals("Great job!", result.getWeaknessSummary());
        assertEquals(1, result.getRecommendedCourses().size());
    }

    @Test
    void recommendCoursesAIShouldLimitRecommendedCoursesToAtMostThree() {
        when(examAttemptRepository.findById(1L)).thenReturn(Optional.of(attempt(1L)));
        when(examResultAnalyzerService.analyzeLatestExamAttempt(any())).thenReturn(analysis(5));
        when(courseRepository.findAll()).thenReturn(List.of(
                Course.builder().id(1L).title("Course 1").build(),
                Course.builder().id(2L).title("Course 2").build(),
                Course.builder().id(3L).title("Course 3").build(),
                Course.builder().id(4L).title("Course 4").build()));
        String aiJson = "{\"weaknessSummary\":\"Needs practice.\",\"recommendedCourses\":["
                + "{\"courseId\":1,\"reasonWhy\":\"r1\"},{\"courseId\":2,\"reasonWhy\":\"r2\"},"
                + "{\"courseId\":3,\"reasonWhy\":\"r3\"},{\"courseId\":4,\"reasonWhy\":\"r4\"}]}";
        when(geminiClientService.generateChatResponse(any(), any())).thenReturn(aiJson);

        ExamCourseRecommendationAIResponseDTO result = service.recommendCoursesAI(1L);

        assertEquals(3, result.getRecommendedCourses().size());
    }

    @Test
    void recommendCoursesAIShouldFallBackToEmptyResultWhenAiCallFails() {
        when(examAttemptRepository.findById(1L)).thenReturn(Optional.of(attempt(1L)));
        when(examResultAnalyzerService.analyzeLatestExamAttempt(any())).thenReturn(analysis(4));
        when(courseRepository.findAll()).thenReturn(List.of());
        when(geminiClientService.generateChatResponse(any(), any())).thenThrow(new RuntimeException("Gemini timeout"));

        ExamCourseRecommendationAIResponseDTO result = service.recommendCoursesAI(1L);

        assertEquals(1L, result.getExamAttemptId());
        assertEquals("", result.getWeaknessSummary());
        assertTrue(result.getRecommendedCourses().isEmpty());
    }

    @Test
    void recommendCoursesAIShouldFallBackToEmptyResultWhenAiResponseIsNotValidJson() {
        when(examAttemptRepository.findById(1L)).thenReturn(Optional.of(attempt(1L)));
        when(examResultAnalyzerService.analyzeLatestExamAttempt(any())).thenReturn(analysis(4));
        when(courseRepository.findAll()).thenReturn(List.of());
        when(geminiClientService.generateChatResponse(any(), any())).thenReturn("not valid json at all");

        ExamCourseRecommendationAIResponseDTO result = service.recommendCoursesAI(1L);

        assertTrue(result.getRecommendedCourses().isEmpty());
    }

    @Test
    void recommendCoursesAIShouldMapCourseCategoryAndDifficultyWhenCourseIsFound() {
        when(examAttemptRepository.findById(1L)).thenReturn(Optional.of(attempt(1L)));
        when(examResultAnalyzerService.analyzeLatestExamAttempt(any())).thenReturn(analysis(5));
        Course course = Course.builder().id(20L).title("Advanced Grammar")
                .category(SystemParameter.builder().paramValue("Grammar").build())
                .difficulty(SystemParameter.builder().paramValue("Advanced").build())
                .build();
        when(courseRepository.findAll()).thenReturn(List.of(course));
        String aiJson = "{\"weaknessSummary\":\"Focus on grammar.\","
                + "\"recommendedCourses\":[{\"courseId\":20,\"reasonWhy\":\"Deepens grammar skills.\"}]}";
        when(geminiClientService.generateChatResponse(any(), any())).thenReturn(aiJson);

        ExamCourseRecommendationAIResponseDTO result = service.recommendCoursesAI(1L);

        assertEquals("Advanced Grammar", result.getRecommendedCourses().get(0).getTitle());
        assertEquals("Grammar", result.getRecommendedCourses().get(0).getCategory());
        assertEquals("Advanced", result.getRecommendedCourses().get(0).getDifficulty());
    }

    @Test
    void recommendCoursesAIShouldReturnEmptyCourseFieldsWhenRecommendedCourseIdNotFound() {
        when(examAttemptRepository.findById(1L)).thenReturn(Optional.of(attempt(1L)));
        when(examResultAnalyzerService.analyzeLatestExamAttempt(any())).thenReturn(analysis(5));
        when(courseRepository.findAll()).thenReturn(List.of(Course.builder().id(10L).title("Grammar Basics").build()));
        String aiJson = "{\"weaknessSummary\":\"Keep going.\","
                + "\"recommendedCourses\":[{\"courseId\":55,\"reasonWhy\":\"Unknown course.\"}]}";
        when(geminiClientService.generateChatResponse(any(), any())).thenReturn(aiJson);

        ExamCourseRecommendationAIResponseDTO result = service.recommendCoursesAI(1L);

        assertEquals(55L, result.getRecommendedCourses().get(0).getCourseId());
        assertEquals("", result.getRecommendedCourses().get(0).getTitle());
        assertEquals("", result.getRecommendedCourses().get(0).getCategory());
        assertEquals("", result.getRecommendedCourses().get(0).getDifficulty());
    }

    @Test
    void recommendCoursesAIShouldExcludeSoftDeletedCoursesWhenResolvingRecommendations() {
        when(examAttemptRepository.findById(1L)).thenReturn(Optional.of(attempt(1L)));
        when(examResultAnalyzerService.analyzeLatestExamAttempt(any())).thenReturn(analysis(5));
        Course deletedCourse = Course.builder().id(99L).title("Old Course").deletedAt(LocalDateTime.now()).build();
        when(courseRepository.findAll()).thenReturn(List.of(deletedCourse));
        String aiJson = "{\"weaknessSummary\":\"Keep going.\","
                + "\"recommendedCourses\":[{\"courseId\":99,\"reasonWhy\":\"Stale reference.\"}]}";
        when(geminiClientService.generateChatResponse(any(), any())).thenReturn(aiJson);

        ExamCourseRecommendationAIResponseDTO result = service.recommendCoursesAI(1L);

        assertEquals("", result.getRecommendedCourses().get(0).getTitle());
    }

    @Test
    void recommendCoursesAIShouldParseCourseIdWhenAiReturnsItAsString() {
        when(examAttemptRepository.findById(1L)).thenReturn(Optional.of(attempt(1L)));
        when(examResultAnalyzerService.analyzeLatestExamAttempt(any())).thenReturn(analysis(5));
        when(courseRepository.findAll()).thenReturn(List.of(Course.builder().id(10L).title("Grammar Basics").build()));
        String aiJson = "{\"weaknessSummary\":\"Nice.\","
                + "\"recommendedCourses\":[{\"courseId\":\"10\",\"reasonWhy\":\"String id.\"}]}";
        when(geminiClientService.generateChatResponse(any(), any())).thenReturn(aiJson);

        ExamCourseRecommendationAIResponseDTO result = service.recommendCoursesAI(1L);

        assertEquals(10L, result.getRecommendedCourses().get(0).getCourseId());
        assertEquals("Grammar Basics", result.getRecommendedCourses().get(0).getTitle());
    }

    @Test
    void recommendCoursesAIShouldReturnEmptyRecommendedCoursesWhenFieldMissingFromAiResponse() {
        when(examAttemptRepository.findById(1L)).thenReturn(Optional.of(attempt(1L)));
        when(examResultAnalyzerService.analyzeLatestExamAttempt(any())).thenReturn(analysis(5));
        when(courseRepository.findAll()).thenReturn(List.of());
        String aiJson = "{\"weaknessSummary\":\"Good job overall.\"}";
        when(geminiClientService.generateChatResponse(any(), any())).thenReturn(aiJson);

        ExamCourseRecommendationAIResponseDTO result = service.recommendCoursesAI(1L);

        assertEquals("Good job overall.", result.getWeaknessSummary());
        assertTrue(result.getRecommendedCourses().isEmpty());
    }

    @Test
    void recommendCoursesAIShouldDefaultWeaknessSummaryToEmptyWhenMissingFromAiResponse() {
        when(examAttemptRepository.findById(1L)).thenReturn(Optional.of(attempt(1L)));
        when(examResultAnalyzerService.analyzeLatestExamAttempt(any())).thenReturn(analysis(5));
        when(courseRepository.findAll()).thenReturn(List.of(Course.builder().id(10L).title("Grammar Basics").build()));
        String aiJson = "{\"recommendedCourses\":[{\"courseId\":10,\"reasonWhy\":\"Solid pick.\"}]}";
        when(geminiClientService.generateChatResponse(any(), any())).thenReturn(aiJson);

        ExamCourseRecommendationAIResponseDTO result = service.recommendCoursesAI(1L);

        assertEquals("", result.getWeaknessSummary());
        assertEquals(1, result.getRecommendedCourses().size());
    }

    @Test
    void recommendCoursesAIShouldDiscardEntireResponseWhenOneRecommendedCourseHasInvalidCourseId() {
        when(examAttemptRepository.findById(1L)).thenReturn(Optional.of(attempt(1L)));
        when(examResultAnalyzerService.analyzeLatestExamAttempt(any())).thenReturn(analysis(5));
        when(courseRepository.findAll()).thenReturn(List.of(Course.builder().id(10L).title("Grammar Basics").build()));
        String aiJson = "{\"weaknessSummary\":\"You're doing great.\",\"recommendedCourses\":["
                + "{\"courseId\":10,\"reasonWhy\":\"r1\"},{\"courseId\":null,\"reasonWhy\":\"r2\"}]}";
        when(geminiClientService.generateChatResponse(any(), any())).thenReturn(aiJson);

        ExamCourseRecommendationAIResponseDTO result = service.recommendCoursesAI(1L);

        assertEquals("", result.getWeaknessSummary());
        assertTrue(result.getRecommendedCourses().isEmpty());
    }
}
