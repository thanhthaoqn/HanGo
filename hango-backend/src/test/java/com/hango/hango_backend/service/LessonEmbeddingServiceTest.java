package com.hango.hango_backend.service;

import com.hango.hango_backend.entity.Lesson;
import com.hango.hango_backend.repository.LessonRepository;
import com.hango.hango_backend.util.VectorUtil;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.util.List;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class LessonEmbeddingServiceTest {

    @Mock
    private LessonRepository lessonRepository;
    @Mock
    private GeminiClientService geminiClientService;

    @InjectMocks
    private LessonEmbeddingService service;

    // =================================================================
    // getOrComputeEmbedding
    // =================================================================

    @Test
    void getOrComputeEmbeddingShouldReturnCachedVectorWithoutCallingGeminiWhenEmbeddingAlreadyExists() {
        Lesson lesson = Lesson.builder().id(1L).contentEmbedding(VectorUtil.toJson(List.of(0.1, 0.2))).build();

        List<Double> result = service.getOrComputeEmbedding(lesson);

        assertEquals(List.of(0.1, 0.2), result);
        verify(geminiClientService, never()).generateEmbedding(any());
    }

    @Test
    void getOrComputeEmbeddingShouldComputeAndCacheWhenEmbeddingBlank() {
        Lesson lesson = Lesson.builder().id(1L).content("Some lesson content").contentEmbedding("  ").build();
        when(geminiClientService.generateEmbedding("Some lesson content")).thenReturn(List.of(0.5, 0.6));

        List<Double> result = service.getOrComputeEmbedding(lesson);

        assertEquals(List.of(0.5, 0.6), result);
        verify(lessonRepository).save(lesson);
    }

    @Test
    void getOrComputeEmbeddingShouldComputeWhenEmbeddingNull() {
        Lesson lesson = Lesson.builder().id(1L).content("Some lesson content").contentEmbedding(null).build();
        when(geminiClientService.generateEmbedding("Some lesson content")).thenReturn(List.of(0.5, 0.6));

        service.getOrComputeEmbedding(lesson);

        verify(geminiClientService).generateEmbedding("Some lesson content");
    }

    // =================================================================
    // recomputeEmbedding
    // =================================================================

    @Test
    void recomputeEmbeddingShouldOverwriteExistingEmbeddingAndPersist() {
        Lesson lesson = Lesson.builder().id(1L).content("Updated content").contentEmbedding(VectorUtil.toJson(List.of(0.9))).build();
        when(geminiClientService.generateEmbedding("Updated content")).thenReturn(List.of(0.1, 0.2, 0.3));

        List<Double> result = service.recomputeEmbedding(lesson);

        assertEquals(List.of(0.1, 0.2, 0.3), result);
        assertEquals(VectorUtil.toJson(List.of(0.1, 0.2, 0.3)), lesson.getContentEmbedding());
        verify(lessonRepository).save(lesson);
    }
}
