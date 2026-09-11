package com.hango.hango_backend.util;

import org.junit.jupiter.api.Test;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.ValueSource;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;

class PasswordPolicyTest {

    // =================================================================
    // valid passwords (must satisfy upper+lower+digit+special, 8-64 chars)
    // =================================================================

    @ParameterizedTest
    @ValueSource(strings = {
            "Pass1234!",
            "Aa1!aaaa",
            "Correct-Horse1",
            "P@ssw0rd",
            "ABCDEFGa1!",
    })
    void shouldMatchPasswordsSatisfyingAllFourCharacterClassesWithinLengthRange(String candidate) {
        assertTrue(candidate.matches(PasswordPolicy.PATTERN));
    }

    @Test
    void shouldMatchAtEightCharacterLowerBoundary() {
        String eightChars = "Aa1!aaaa";
        assertEquals(8, eightChars.length());
        assertTrue(eightChars.matches(PasswordPolicy.PATTERN));
    }

    @Test
    void shouldMatchAtSixtyFourCharacterUpperBoundary() {
        String sixtyFourChars = "Aa1!" + "a".repeat(60);
        assertEquals(64, sixtyFourChars.length());
        assertTrue(sixtyFourChars.matches(PasswordPolicy.PATTERN));
    }

    // =================================================================
    // invalid passwords: missing a required character class
    // =================================================================

    @ParameterizedTest
    @ValueSource(strings = {
            "pass1234!",   // no uppercase
            "PASS1234!",   // no lowercase
            "Password!",   // no digit
            "Password1",   // no special character
    })
    void shouldRejectPasswordsMissingARequiredCharacterClass(String candidate) {
        assertFalse(candidate.matches(PasswordPolicy.PATTERN));
    }

    // =================================================================
    // invalid passwords: length boundary violations
    // =================================================================

    @ParameterizedTest
    @ValueSource(strings = {
            "Aa1!aaa",   // 7 chars, one under the 8-char minimum
            "Aa1!",      // far too short
            "",          // empty
    })
    void shouldRejectPasswordsShorterThanEightCharacters(String candidate) {
        assertFalse(candidate.matches(PasswordPolicy.PATTERN));
    }

    @Test
    void shouldRejectPasswordLongerThanSixtyFourCharacters() {
        String sixtyFiveChars = "Aa1!" + "a".repeat(61);
        assertEquals(65, sixtyFiveChars.length());
        assertFalse(sixtyFiveChars.matches(PasswordPolicy.PATTERN));
    }

    // =================================================================
    // invalid passwords: null / whitespace-only are not this regex's job,
    // but confirm it doesn't crash and simply doesn't match
    // =================================================================

    @ParameterizedTest
    @ValueSource(strings = {" ", "        "})
    void shouldRejectWhitespaceOnlyInput(String candidate) {
        assertFalse(candidate.matches(PasswordPolicy.PATTERN));
    }
}
