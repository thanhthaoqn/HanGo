package com.hango.hango_backend.dto;

import com.fasterxml.jackson.annotation.JsonIgnoreProperties;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.util.List;

/**
 * DTO cho Gemini Embedding API (embedContent endpoint).
 * Model được chỉ định qua URL path (ví dụ: /models/text-embedding-004:embedContent),
 * nên request body chỉ cần chứa "content".
 */
public class GeminiEmbeddingDto {

    @Data
    @Builder
    @NoArgsConstructor
    @AllArgsConstructor
    public static class Request {
        private Content content;

        @Data
        @Builder
        @NoArgsConstructor
        @AllArgsConstructor
        public static class Content {
            private List<Part> parts;
        }

        @Data
        @Builder
        @NoArgsConstructor
        @AllArgsConstructor
        public static class Part {
            private String text;
        }
    }

    @Data
    @JsonIgnoreProperties(ignoreUnknown = true)
    public static class Response {
        private Embedding embedding;

        @Data
        @JsonIgnoreProperties(ignoreUnknown = true)
        public static class Embedding {
            private List<Double> values;
        }
    }
}