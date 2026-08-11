package com.hango.hango_backend.service;

import com.hango.hango_backend.config.GeminiProperties;
import com.hango.hango_backend.dto.AiHealthResponse;
import com.hango.hango_backend.dto.GeminiEmbeddingDto;
import com.hango.hango_backend.dto.GeminiFileResponse;
import com.hango.hango_backend.dto.GeminiGenerateRequest;
import com.hango.hango_backend.dto.GeminiGenerateResponse;
import com.hango.hango_backend.entity.AiUsageLog;
import com.hango.hango_backend.exception.ApiException;
import com.hango.hango_backend.repository.AiUsageLogRepository;
import jakarta.annotation.PostConstruct;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.web.reactive.function.client.WebClient;
import org.springframework.web.reactive.function.client.WebClientResponseException;
import reactor.util.retry.Retry;
import org.springframework.cache.annotation.Cacheable;

import java.time.Duration;
import java.util.List;

/**
 * The single service in the entire system that directly calls the Gemini API.
 * Automatically initializes an internal WebClient to prevent domain routing
 * errors.
 */
@Service
@Slf4j
public class GeminiClientService {

        private WebClient webClient;
        private final GeminiProperties geminiProperties;
        private final AiUsageLogRepository aiUsageLogRepository;

        // Use manual constructor injection instead of @RequiredArgsConstructor
        public GeminiClientService(GeminiProperties geminiProperties, AiUsageLogRepository aiUsageLogRepository) {
                this.geminiProperties = geminiProperties;
                this.aiUsageLogRepository = aiUsageLogRepository;
        }

        /**
         * Records usage for FR-RBAC-07 (AI Usage Monitoring) — used by both real Gemini
         * call sites below.
         */
        private void recordUsage(String callType, boolean success, long durationMs, String errorMessage) {
                try {
                        String safeErrorMessage = errorMessage;
                        if (safeErrorMessage != null && safeErrorMessage.length() > 255) {
                                safeErrorMessage = safeErrorMessage.substring(0, 250) + "...";
                        }
                        Long userId = null;
                        try {
                                userId = com.hango.hango_backend.security.SecurityUtil.getCurrentUserId();
                        } catch (Exception ignored) {
                        }

                        aiUsageLogRepository.save(AiUsageLog.builder()
                                        .callType(callType)
                                        .success(success)
                                        .durationMs(durationMs)
                                        .errorMessage(safeErrorMessage)
                                        .userId(userId != null ? userId : 0L)
                                        .build());
                } catch (Exception e) {
                        log.warn("Failed to record AI usage log (non-fatal)", e);
                }
        }

        /**
         * Automatically runs on application startup to set up WebClient with the
         * correct Base URL
         * and inject the x-goog-api-key header for AQ-type keys.
         */
        @PostConstruct
        public void init() {
                // Get configured baseUrl from properties, fallback to Google's default URL if
                // empty
                String baseUrl = geminiProperties.getBaseUrl();
                if (baseUrl == null || baseUrl.isBlank()) {
                        baseUrl = "https://generativelanguage.googleapis.com";
                }

                // Ensure baseUrl ends with a slash so WebClient can build paths without errors
                if (!baseUrl.endsWith("/")) {
                        baseUrl = baseUrl + "/";
                }

                // Configure shared WebClient: Attach the API Key header for Google AI Studio
                this.webClient = WebClient.builder()
                                .baseUrl(baseUrl)
                                .defaultHeader("Content-Type", "application/json")
                                // THIS IS IMPORTANT: Inject the new generation API Key directly into headers
                                .defaultHeader("x-goog-api-key", geminiProperties.getApiKey())
                                .build();
                log.info("Gemini WebClient successfully initialized with URL: {}", baseUrl);
        }

        @Cacheable(value = "geminiStatus")
        public AiHealthResponse checkAvailability() {
                if (geminiProperties.getApiKey() == null || geminiProperties.getApiKey().isBlank()) {
                        return buildHealth(false, "GEMINI_API_KEY is not configured");
                }

                GeminiGenerateRequest request = GeminiGenerateRequest.builder()
                                .contents(List.of(GeminiGenerateRequest.Content.builder()
                                                .role("user")
                                                .parts(List.of(GeminiGenerateRequest.Part.builder()
                                                                .text("Reply with OK only.").build()))
                                                .build()))
                                .generationConfig(GeminiGenerateRequest.GenerationConfig.builder()
                                                .temperature(0.0)
                                                .maxOutputTokens(8)
                                                .build())
                                .build();

                // ✅ ĐÃ SỬA: Loại bỏ hoàn toàn tham số `?key=` gây lỗi 403 trên URL
                String path = String.format("v1beta/models/%s:generateContent", geminiProperties.getChatModel());

                try {
                        GeminiGenerateResponse response = webClient.post()
                                        .uri(path)
                                        .bodyValue(request)
                                        .retrieve()
                                        .bodyToMono(GeminiGenerateResponse.class)
                                        .timeout(Duration.ofSeconds(geminiProperties.getTimeoutSeconds()))
                                        .block();

                        String text = response != null ? response.extractText() : null;
                        if (text == null || text.isBlank()) {
                                return buildHealth(false, "Gemini responded but without valid content");
                        }
                        return buildHealth(true, "Online");
                } catch (Exception e) {
                        log.warn("Gemini health check failed", e);
                        return buildHealth(false, "Failed to call Gemini API: " + e.getClass().getSimpleName());
                }
        }

        private AiHealthResponse buildHealth(boolean available, String message) {
                return AiHealthResponse.builder()
                                .available(available)
                                .message(message)
                                .chatModel(geminiProperties.getChatModel())
                                .embeddingModel(geminiProperties.getEmbeddingModel())
                                .build();
        }

        /**
         * Calls the Gemini chat model to generate a response, including the ENTIRE chat
         * history.
         */
        public String generateChatResponse(String systemPrompt, List<GeminiGenerateRequest.Content> chatHistory) {
                GeminiGenerateRequest request = GeminiGenerateRequest.builder()
                                .systemInstruction(GeminiGenerateRequest.SystemInstruction.builder()
                                                .parts(List.of(GeminiGenerateRequest.Part.builder().text(systemPrompt)
                                                                .build()))
                                                .build())
                                .contents(chatHistory) // Send the entire history array including the new question at
                                                       // the end
                                .generationConfig(GeminiGenerateRequest.GenerationConfig.builder()
                                                .temperature(0.4)
                                                .maxOutputTokens(800)
                                                .build())
                                .build();

                // FIXED: Completely removed `?key=` param from URL to avoid 403 errors
                String path = String.format("v1beta/models/%s:generateContent", geminiProperties.getChatModel());
                long startedAt = System.currentTimeMillis();

                try {
                        GeminiGenerateResponse response = webClient.post()
                                        .uri(path)
                                        .bodyValue(request)
                                        .retrieve()
                                        .bodyToMono(GeminiGenerateResponse.class)

                                        // AUTOMATICALLY RETRY WHEN HITTING 429 TOO MANY REQUESTS
                                        .retryWhen(Retry.backoff(2, Duration.ofSeconds(2))
                                                        .filter(throwable -> throwable instanceof WebClientResponseException.TooManyRequests))

                                        .timeout(Duration.ofSeconds(geminiProperties.getTimeoutSeconds()))
                                        .block();

                        String text = response != null ? response.extractText() : null;

                        if (text == null || text.isBlank()) {
                                recordUsage("CHAT", false, System.currentTimeMillis() - startedAt, "Empty response");
                                throw new ApiException("AI returned an invalid response", HttpStatus.BAD_GATEWAY);
                        }
                        recordUsage("CHAT", true, System.currentTimeMillis() - startedAt, null);
                        return text;

                } catch (ApiException e) {
                        throw e;
                } catch (Exception e) {
                        log.error("Error calling Gemini chat API", e);
                        recordUsage("CHAT", false, System.currentTimeMillis() - startedAt,
                                        e.getClass().getSimpleName());
                        throw new ApiException("Không thể kết nối đến Trợ lý AI vào lúc này, vui lòng thử lại sau",
                                        HttpStatus.SERVICE_UNAVAILABLE);
                }
        }

        /**
         * Calls the Gemini embedding model to convert a text string into a numerical
         * vector.
         */
        public List<Double> generateEmbedding(String text) {

                GeminiEmbeddingDto.Request request = GeminiEmbeddingDto.Request.builder()
                                .content(GeminiEmbeddingDto.Request.Content.builder()
                                                .parts(List.of(GeminiEmbeddingDto.Request.Part.builder().text(text)
                                                                .build()))
                                                .build())
                                .build();

                // FIXED: Completely removed `?key=` param from URL to avoid 403 errors
                String path = String.format("v1beta/models/%s:embedContent", geminiProperties.getEmbeddingModel());
                long startedAt = System.currentTimeMillis();

                try {
                        GeminiEmbeddingDto.Response response = webClient.post()
                                        .uri(path)
                                        .bodyValue(request)
                                        .retrieve()
                                        .bodyToMono(GeminiEmbeddingDto.Response.class)

                                        // AUTOMATICALLY RETRY WHEN HITTING 429 TOO MANY REQUESTS
                                        .retryWhen(Retry.backoff(2, Duration.ofSeconds(2))
                                                        .filter(throwable -> throwable instanceof WebClientResponseException.TooManyRequests))

                                        .timeout(Duration.ofSeconds(geminiProperties.getTimeoutSeconds()))
                                        .block();

                        if (response == null || response.getEmbedding() == null) {
                                recordUsage("EMBEDDING", false, System.currentTimeMillis() - startedAt,
                                                "Empty response");
                                throw new ApiException("Could not generate embedding for this content",
                                                HttpStatus.BAD_GATEWAY);
                        }
                        recordUsage("EMBEDDING", true, System.currentTimeMillis() - startedAt, null);
                        return response.getEmbedding().getValues();

                } catch (ApiException e) {
                        throw e;
                } catch (Exception e) {
                        log.error("Error calling Gemini embedding API", e);
                        recordUsage("EMBEDDING", false, System.currentTimeMillis() - startedAt,
                                        e.getClass().getSimpleName());
                        throw new ApiException("Cannot process content at this time, please try again later",
                                        HttpStatus.SERVICE_UNAVAILABLE);
                }
        }

        /**
         * Auto-generate transcript for a video using Gemini 1.5 Flash Audio/Video
         * capability.
         */
        public String generateVideoTranscript(String videoUrl) {
                long startedAt = System.currentTimeMillis();
                java.io.File tempFile = null;
                try {
                        // 1. Download file from Cloudinary to temp file
                        tempFile = java.io.File.createTempFile("video", ".mp4");
                        try (java.io.InputStream in = new java.net.URL(videoUrl).openStream()) {
                                java.nio.file.Files.copy(in, tempFile.toPath(),
                                                java.nio.file.StandardCopyOption.REPLACE_EXISTING);
                        }

                        // 2. Upload to Gemini File API
                        String uploadUrl = "https://generativelanguage.googleapis.com/upload/v1beta/files?uploadType=media";

                        WebClient uploadClient = WebClient.builder()
                                        .defaultHeader("x-goog-api-key", geminiProperties.getApiKey())
                                        .defaultHeader("Content-Type", "video/mp4")
                                        .build();

                        byte[] fileBytes = java.nio.file.Files.readAllBytes(tempFile.toPath());

                        GeminiFileResponse uploadResponse = uploadClient.post()
                                        .uri(uploadUrl)
                                        .bodyValue(fileBytes)
                                        .retrieve()
                                        .bodyToMono(GeminiFileResponse.class)
                                        .block();

                        if (uploadResponse == null || uploadResponse.getFile() == null) {
                                throw new ApiException("Could not upload video to AI", HttpStatus.BAD_GATEWAY);
                        }

                        String fileUri = uploadResponse.getFile().getUri();
                        String fileName = uploadResponse.getFile().getName();

                        // 2.5 Poll for ACTIVE state since video processing takes time
                        boolean isActive = false;
                        for (int i = 0; i < 60; i++) {
                                String getUrl = "https://generativelanguage.googleapis.com/v1beta/" + fileName;
                                GeminiFileResponse.FileInfo getResponse = uploadClient.get()
                                                .uri(getUrl)
                                                .retrieve()
                                                .bodyToMono(GeminiFileResponse.FileInfo.class)
                                                .block();
                                                
                                if (getResponse != null) {
                                        String state = getResponse.getState();
                                        if ("ACTIVE".equalsIgnoreCase(state)) {
                                                isActive = true;
                                                break;
                                        } else if ("FAILED".equalsIgnoreCase(state)) {
                                                throw new ApiException("AI video processing failed", HttpStatus.BAD_GATEWAY);
                                        }
                                }
                                try {
                                        Thread.sleep(2000);
                                } catch (InterruptedException ie) {
                                        Thread.currentThread().interrupt();
                                        break;
                                }
                        }

                        if (!isActive) {
                                throw new ApiException("AI video processing timed out", HttpStatus.GATEWAY_TIMEOUT);
                        }

                        // 3. Call Gemini to transcribe
                        GeminiGenerateRequest request = GeminiGenerateRequest.builder()
                                        .contents(List.of(GeminiGenerateRequest.Content.builder()
                                                        .role("user")
                                                        .parts(List.of(
                                                                        GeminiGenerateRequest.Part.builder()
                                                                                        .fileData(GeminiGenerateRequest.FileData
                                                                                                        .builder()
                                                                                                        .mimeType("video/mp4")
                                                                                                        .fileUri(fileUri)
                                                                                                        .build())
                                                                                        .build(),
                                                                        GeminiGenerateRequest.Part.builder()
                                                                                        .text("Please generate a detailed transcript in the language of this video. Answer with the direct content only, without any greetings or additional explanations.")
                                                                                        .build()))
                                                        .build()))
                                        .generationConfig(GeminiGenerateRequest.GenerationConfig.builder()
                                                        .temperature(0.2)
                                                        .maxOutputTokens(8000)
                                                        .build())
                                        .build();

                        String path = String.format("v1beta/models/%s:generateContent", geminiProperties.getChatModel());

                        GeminiGenerateResponse response = webClient.post()
                                        .uri(path)
                                        .bodyValue(request)
                                        .retrieve()
                                        .bodyToMono(GeminiGenerateResponse.class)
                                        .timeout(Duration.ofSeconds(60))
                                        .block();

                        String text = response != null ? response.extractText() : null;
                        if (text == null || text.isBlank()) {
                                throw new ApiException("AI could not generate a transcript for this video",
                                                HttpStatus.BAD_GATEWAY);
                        }

                        recordUsage("TRANSCRIPT", true, System.currentTimeMillis() - startedAt, null);
                        return text;
                } catch (Exception e) {
                        log.error("Error calling Gemini transcript API", e);
                        recordUsage("TRANSCRIPT", false, System.currentTimeMillis() - startedAt,
                                        e.getClass().getSimpleName());
                        throw new ApiException("Could not generate transcript at this time: " + e.getMessage(),
                                        HttpStatus.SERVICE_UNAVAILABLE);
                } finally {
                        if (tempFile != null && tempFile.exists()) {
                                tempFile.delete();
                        }
                }
        }
}
