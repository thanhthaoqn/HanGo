package com.hango.hango_backend.service;

public record CommentModerationResult(String status, String normalizedContent, String detectionReason) {
}
