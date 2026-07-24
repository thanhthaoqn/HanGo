package com.hango.hango_backend.service;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertTrue;
import org.junit.jupiter.api.Test;

class CommentRuleEngineServiceTest {

    private final CommentRuleEngineService ruleEngine = new CommentRuleEngineService();

    // =================================================================
    // normalize
    // =================================================================

    @Test
    void normalizeShouldLowercaseStripAccentsAndCollapseWhitespace() {
        assertEquals("dit me may", ruleEngine.normalize("  Địt   Mẹ   Mày  "));
    }

    @Test
    void normalizeShouldMapDStrokeAndCollapseLeetspeakSubstitutions() {
        assertEquals("dep", ruleEngine.normalize("Đẹp"));
        assertEquals("hello world", ruleEngine.normalize("h3ll0 w0rld"));
    }

    // =================================================================
    // evaluate - REJECTED
    // =================================================================

    @Test
    void evaluateShouldRejectVietnameseProfanityPhraseRegardlessOfAccents() {
        CommentModerationResult result = ruleEngine.evaluate("Địt mẹ mày ngu vừa thôi");

        assertEquals(CommentRuleEngineService.STATUS_REJECTED, result.status());
        assertTrue(result.detectionReason().contains("dit me"));
    }

    @Test
    void evaluateShouldRejectVietnameseSlangAbbreviation() {
        assertEquals(CommentRuleEngineService.STATUS_REJECTED,
                ruleEngine.evaluate("vcl bài này khó vậy").status());
    }

    @Test
    void evaluateShouldRejectEnglishProfanity() {
        assertEquals(CommentRuleEngineService.STATUS_REJECTED,
                ruleEngine.evaluate("This lesson is fucking useless").status());
    }

    @Test
    void evaluateShouldNotFalsePositiveOnBlacklistedSubstringInsideAnUnrelatedWord() {
        // "cc" is blacklisted as a whole word, but must not fire mid-word (e.g. "success").
        assertEquals(CommentRuleEngineService.STATUS_APPROVED,
                ruleEngine.evaluate("I really appreciate your success in this course").status());
    }

    // =================================================================
    // evaluate - PENDING
    // =================================================================

    @Test
    void evaluateShouldFlagMildInsultAsPendingNotRejected() {
        assertEquals(CommentRuleEngineService.STATUS_PENDING,
                ruleEngine.evaluate("Bài giảng này ngu vãi").status());
    }

    @Test
    void evaluateShouldFlagPhoneNumberAsPending() {
        CommentModerationResult result = ruleEngine.evaluate("Liên hệ mình qua 0987654321 nhé");

        assertEquals(CommentRuleEngineService.STATUS_PENDING, result.status());
        assertEquals("Contains a phone number", result.detectionReason());
    }

    @Test
    void evaluateShouldFlagUrlAsPending() {
        assertEquals(CommentRuleEngineService.STATUS_PENDING,
                ruleEngine.evaluate("Check this out: https://example.com/promo").status());
    }

    // =================================================================
    // evaluate - APPROVED
    // =================================================================

    @Test
    void evaluateShouldApproveCleanComment() {
        CommentModerationResult result = ruleEngine.evaluate("Bài giảng rất hay, cảm ơn thầy cô!");

        assertEquals(CommentRuleEngineService.STATUS_APPROVED, result.status());
        assertNull(result.detectionReason());
    }
}
