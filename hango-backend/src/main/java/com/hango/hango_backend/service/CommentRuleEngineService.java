package com.hango.hango_backend.service;

import java.text.Normalizer;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.regex.Pattern;

import org.springframework.stereotype.Service;

/**
 * Simple rule-based comment moderation: text normalization + blacklist keywords + regex patterns.
 * No AI involved (see HanGo v1.0 Comment Management spec).
 */
@Service
public class CommentRuleEngineService {

    public static final String STATUS_APPROVED = "APPROVED";
    public static final String STATUS_PENDING = "PENDING";
    public static final String STATUS_REJECTED = "REJECTED";

    /**
     * Offensive words/phrases -> immediate REJECTED. Matched as whole words/phrases on normalized
     * content (lowercase, accents stripped, leetspeak substitutions applied - see {@link #normalize}).
     * Words that collide heavily with common, non-offensive Vietnamese words after accent-stripping
     * (e.g. "đi" -> "di", "cho" -> "cho") are deliberately left out to avoid mass false-positives;
     * see the Edge Cases section of doc/specs/13-comment-management.md.
     */
    private static final List<String> BLACKLIST_KEYWORDS = List.of(
            // Vietnamese - abbreviations / teencode
            "dm", "dmm", "dcm", "dkm", "dkmm", "vcl", "vloz", "clgt", "clm", "cmm", "vl", "cc",
            // Vietnamese - full words/phrases
            "du me", "du ma", "dm may", "dit me", "dit con me", "dit cha",
            "lon", "buoi", "deo", "cak", "vai lon", "suc vat", "oc cho", "do cho", "con cho de",
            // English
            "fuck", "fucker", "fucking", "shit", "bullshit", "bitch", "asshole", "bastard", "cunt", "whore", "slut",
            "nigger", "nigga"
    );

    /** Milder insults/rudeness -> PENDING (queued for Admin review, not an automatic block). */
    private static final List<String> SUSPICIOUS_KEYWORDS = List.of(
            "ngu", "dien", "khung", "ngoc", "ngu si", "dot", "dumb", "stupid", "idiot", "moron"
    );

    /** Suspicious regex patterns -> PENDING for Admin review, keyed by human-readable reason. */
    private static final Map<String, Pattern> SUSPICIOUS_PATTERNS = new LinkedHashMap<>();
    static {
        SUSPICIOUS_PATTERNS.put("Contains a phone number", Pattern.compile("(?:\\+?84|0)\\d{9,10}"));
        SUSPICIOUS_PATTERNS.put("Contains a URL/link", Pattern.compile("https?://\\S+|www\\.\\S+"));
        SUSPICIOUS_PATTERNS.put("Contains an email address", Pattern.compile("[\\w.+-]+@[\\w-]+\\.[\\w.-]+"));
        SUSPICIOUS_PATTERNS.put("Solicits off-platform contact", Pattern.compile("\\b(zalo|inbox|lien he|sdt|so dien thoai)\\b"));
    }

    public CommentModerationResult evaluate(String rawContent) {
        String normalized = normalize(rawContent);

        String blacklisted = findMatch(normalized, BLACKLIST_KEYWORDS);
        if (blacklisted != null) {
            return new CommentModerationResult(STATUS_REJECTED, normalized, "Blacklist keyword detected: \"" + blacklisted + "\"");
        }

        String suspiciousKeyword = findMatch(normalized, SUSPICIOUS_KEYWORDS);
        if (suspiciousKeyword != null) {
            return new CommentModerationResult(STATUS_PENDING, normalized, "Suspicious keyword detected: \"" + suspiciousKeyword + "\"");
        }

        // Regex patterns rely on digits/symbols (phone, email, URL) so they run on the
        // whitespace-collapsed original text rather than the letter-substituted `normalized` form.
        String forPatternCheck = collapseWhitespace(rawContent == null ? "" : rawContent.toLowerCase());
        for (Map.Entry<String, Pattern> entry : SUSPICIOUS_PATTERNS.entrySet()) {
            if (entry.getValue().matcher(forPatternCheck).find()) {
                return new CommentModerationResult(STATUS_PENDING, normalized, entry.getKey());
            }
        }

        return new CommentModerationResult(STATUS_APPROVED, normalized, null);
    }

    private String findMatch(String normalized, List<String> keywords) {
        for (String keyword : keywords) {
            if (Pattern.compile("\\b" + Pattern.quote(keyword) + "\\b").matcher(normalized).find()) {
                return keyword;
            }
        }
        return null;
    }

    /** lowercase -> strip Vietnamese accents -> collapse whitespace -> normalize common special-character substitutions. */
    public String normalize(String input) {
        if (input == null) {
            return "";
        }
        String result = input.toLowerCase();
        result = Normalizer.normalize(result, Normalizer.Form.NFD)
                .replaceAll("\\p{InCombiningDiacriticalMarks}+", "");
        result = result.replace('đ', 'd');
        result = collapseWhitespace(result);
        result = result.replaceAll("[0@]", "o")
                .replaceAll("1", "i")
                .replaceAll("3", "e")
                .replaceAll("4", "a")
                .replaceAll("[5$]", "s")
                .replaceAll("7", "t");
        return result;
    }

    private String collapseWhitespace(String input) {
        return input.replaceAll("\\s+", " ").trim();
    }
}
