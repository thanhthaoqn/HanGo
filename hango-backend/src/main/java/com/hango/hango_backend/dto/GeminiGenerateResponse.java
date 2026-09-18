package com.hango.hango_backend.dto;

import com.fasterxml.jackson.annotation.JsonIgnoreProperties;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.util.List;

@Data
@JsonIgnoreProperties(ignoreUnknown = true)
public class GeminiGenerateResponse {

    private List<Candidate> candidates;

    @Data
    @JsonIgnoreProperties(ignoreUnknown = true)
    public static class Candidate {
        private Content content;
        private String finishReason;
        private GroundingMetadata groundingMetadata;
    }

    @Data
    @JsonIgnoreProperties(ignoreUnknown = true)
    public static class GroundingMetadata {
        private List<String> webSearchQueries;
        private List<GroundingChunk> groundingChunks;
    }

    @Data
    @JsonIgnoreProperties(ignoreUnknown = true)
    public static class GroundingChunk {
        private WebSource web;
    }

    @Data
    @Builder
    @NoArgsConstructor
    @AllArgsConstructor
    @JsonIgnoreProperties(ignoreUnknown = true)
    public static class WebSource {
        private String uri;
        private String title;
    }

    @Data
    @JsonIgnoreProperties(ignoreUnknown = true)
    public static class Content {
        private List<Part> parts;
        private String role;
    }

    @Data
    @JsonIgnoreProperties(ignoreUnknown = true)
    public static class Part {
        private String text;
    }

    /** Tiện ích lấy nhanh text trả lời đầu tiên, tránh null-check dài dòng ở nơi gọi. */
    public String extractText() {
        if (candidates == null || candidates.isEmpty()) return null;
        Content content = candidates.get(0).getContent();
        if (content == null || content.getParts() == null || content.getParts().isEmpty()) return null;
        return content.getParts().get(0).getText();
    }

    /** Tiện ích trích xuất danh sách nguồn tìm kiếm (Google Search Grounding). */
    public List<WebSource> extractGroundingSources() {
        if (candidates == null || candidates.isEmpty()) return List.of();
        GroundingMetadata metadata = candidates.get(0).getGroundingMetadata();
        if (metadata == null || metadata.getGroundingChunks() == null) return List.of();
        return metadata.getGroundingChunks().stream()
                .filter(java.util.Objects::nonNull)
                .map(c -> c.getWeb())
                .filter(java.util.Objects::nonNull)
                .toList();
    }
}
