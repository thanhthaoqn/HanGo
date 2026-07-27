package com.hango.hango_backend.service;

import com.hango.hango_backend.dto.QuizQuestionDTO;
import com.hango.hango_backend.entity.Lesson;
import org.junit.jupiter.api.Test;

import java.util.List;

import static org.junit.jupiter.api.Assertions.assertTrue;

class AIPromptBuilderTest {

    private final AIPromptBuilder builder = new AIPromptBuilder();

    private Lesson lesson(String title, String content) {
        return Lesson.builder().id(1L).title(title).content(content).build();
    }

    // =================================================================
    // buildSystemPrompt
    // =================================================================

    @Test
    void buildSystemPromptShouldIncludeLessonTitleAndContent() {
        String prompt = builder.buildSystemPrompt(lesson("Present Perfect", "Grammar rules about present perfect tense."));

        assertTrue(prompt.contains("Present Perfect"));
        assertTrue(prompt.contains("Grammar rules about present perfect tense."));
    }

    @Test
    void buildSystemPromptShouldNoteNoPracticeQuestionsWhenListEmpty() {
        String prompt = builder.buildSystemPrompt(lesson("Present Perfect", "Content"), List.of());

        assertTrue(prompt.contains("Không có bài tập luyện tập cho bài học này"));
    }

    @Test
    void buildSystemPromptShouldIncludePracticeQuestionTextAndOptions() {
        QuizQuestionDTO question = QuizQuestionDTO.builder()
                .questionText("What is the correct form?")
                .options(List.of("has gone", "have goes"))
                .explanation("Use 'has' with third person singular.")
                .build();

        String prompt = builder.buildSystemPrompt(lesson("Present Perfect", "Content"), List.of(question));

        assertTrue(prompt.contains("What is the correct form?"));
        assertTrue(prompt.contains("has gone"));
        assertTrue(prompt.contains("Use 'has' with third person singular."));
    }

    @Test
    void buildSystemPromptShouldIncludePassageWhenPresent() {
        QuizQuestionDTO question = QuizQuestionDTO.builder()
                .questionText("Q1")
                .passage("Once upon a time...")
                .build();

        String prompt = builder.buildSystemPrompt(lesson("Reading", "Content"), List.of(question));

        assertTrue(prompt.contains("Once upon a time..."));
    }

    @Test
    void buildSystemPromptSingleArgOverloadShouldDelegateToListOverload() {
        String prompt = builder.buildSystemPrompt(lesson("Present Perfect", "Content"));

        assertTrue(prompt.contains("Không có bài tập luyện tập cho bài học này"));
    }

    // =================================================================
    // buildOutOfScopeFallback
    // =================================================================

    @Test
    void buildOutOfScopeFallbackShouldMentionLessonTitle() {
        String fallback = builder.buildOutOfScopeFallback(lesson("Present Perfect", "Content"));

        assertTrue(fallback.contains("Present Perfect"));
    }
}
