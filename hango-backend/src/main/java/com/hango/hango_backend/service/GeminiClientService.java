package com.hango.hango_backend.service;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.node.ArrayNode;
import com.fasterxml.jackson.databind.node.ObjectNode;
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
import java.text.Normalizer;
import java.time.Duration;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import lombok.extern.slf4j.Slf4j;
import org.springframework.cache.annotation.Cacheable;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.web.reactive.function.client.WebClient;
import org.springframework.web.reactive.function.client.WebClientResponseException;
import reactor.util.retry.Retry;
/**
 * Centralized service for invoking Gemini API endpoints.
 * Initializes an internal WebClient with Base URL and API Key header.
 */
@Service
@Slf4j
public class GeminiClientService {
        private static final ObjectMapper OBJECT_MAPPER = new ObjectMapper();
        private static final String DOC_TYPE_PEDAGOGICAL_DEGREE = "PEDAGOGICAL_DEGREE";
        private static final String DOC_TYPE_TEACHING_CERTIFICATE = "TEACHING_CERTIFICATE";
        private static final String DOC_TYPE_LANGUAGE_PROFICIENCY = "LANGUAGE_PROFICIENCY";
        private static final String DOC_TYPE_ACADEMIC_TRANSCRIPT = "ACADEMIC_TRANSCRIPT";
        private static final String DOC_TYPE_TEACHING_CV = "TEACHING_CV";
        private static final String DOC_TYPE_OTHER = "OTHER";

        private WebClient webClient;
        private final GeminiProperties geminiProperties;
        private final AiUsageLogRepository aiUsageLogRepository;
        private final SystemConfigService systemConfigService;

        public GeminiClientService(GeminiProperties geminiProperties, AiUsageLogRepository aiUsageLogRepository, SystemConfigService systemConfigService) {
                this.geminiProperties = geminiProperties;
                this.aiUsageLogRepository = aiUsageLogRepository;
                this.systemConfigService = systemConfigService;
        }

        public String getApiKey() {
            return systemConfigService.getConfigValue("AI", "GEMINI_API_KEY", geminiProperties.getApiKey());
        }

        public String getChatModel() {
            return systemConfigService.getConfigValue("AI", "GEMINI_CHAT_MODEL", geminiProperties.getChatModel());
        }

        public String getEmbeddingModel() {
            return systemConfigService.getConfigValue("AI", "GEMINI_EMBEDDING_MODEL", geminiProperties.getEmbeddingModel());
        }

        public int getTimeoutSeconds() {
            return Integer.parseInt(systemConfigService.getConfigValue("AI", "GEMINI_TIMEOUT_SECONDS", String.valueOf(geminiProperties.getTimeoutSeconds())));
        }

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
         * Hàm khởi tạo (Lifecycle hook): Chạy ngay khi Spring Boot vừa khởi động.
         * Tác dụng: Cấu hình sẵn WebClient với BaseURL (địa chỉ máy chủ Google) 
         * và tự động nhúng API_KEY vào Header (x-goog-api-key) để dùng chung cho mọi cuộc gọi mạng sau này.
         */
        @PostConstruct
        public void init() {
                String baseUrl = geminiProperties.getBaseUrl();
                if (baseUrl == null || baseUrl.isBlank()) {
                        baseUrl = "https://generativelanguage.googleapis.com";
                }

                if (!baseUrl.endsWith("/")) {
                        baseUrl = baseUrl + "/";
                }

                this.webClient = WebClient.builder()
                                .baseUrl(baseUrl)
                                .defaultHeader("Content-Type", "application/json")
                                .filter((request, next) -> {
                                    org.springframework.web.reactive.function.client.ClientRequest newRequest = org.springframework.web.reactive.function.client.ClientRequest.from(request)
                                            .header("x-goog-api-key", getApiKey())
                                            .build();
                                    return next.exchange(newRequest);
                                })
                                .build();
                log.info("Gemini WebClient initialized successfully with base URL: {}", baseUrl);
        }

        /**
         * Hàm Bắt Mạch (Health Check): Dùng để ping kiểm tra Google Gemini xem có bị sập không.
         * Cơ chế: Gửi một câu lệnh siêu ngắn "Reply with OK only." để thử.
         * Cải tiến: Kết quả được Cache (lưu tạm) lại để tránh gọi API liên tục gây tốn tiền.
         */
        @Cacheable(value = "geminiStatus")
        public AiHealthResponse checkAvailability() {
                String apiKey = getApiKey();
                if (apiKey == null || apiKey.isBlank()) {
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

                String chatModel = getChatModel();
                String path = String.format("v1beta/models/%s:generateContent", chatModel);

                try {
                        GeminiGenerateResponse response = webClient.post()
                                        .uri(path)
                                        .bodyValue(request)
                                        .retrieve()
                                        .bodyToMono(GeminiGenerateResponse.class)
                                        .timeout(Duration.ofSeconds(getTimeoutSeconds()))
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
                                .chatModel(getChatModel())
                                .embeddingModel(getEmbeddingModel())
                                .build();
        }

        @lombok.Data
        @lombok.Builder
        @lombok.NoArgsConstructor
        @lombok.AllArgsConstructor
        public static class GeminiChatResult {
                private String text;
                private List<GeminiGenerateResponse.WebSource> sources;
        }

        /**
         * Hàm Giao Tiếp Chính (Chat Completion): Nơi chính thức "nói chuyện" với con bot Gemini.
         * Đầu vào: Lời nhắc hệ thống (System Prompt - Ép AI làm giáo viên) và Toàn bộ Lịch sử Chat.
         */
        public String generateChatResponse(String systemPrompt, List<GeminiGenerateRequest.Content> chatHistory) {
                return generateChatResponse(systemPrompt, chatHistory, false);
        }

        public String generateChatResponse(String systemPrompt, List<GeminiGenerateRequest.Content> chatHistory, boolean enableSearchGrounding) {
                return generateChatResponseDetailed(systemPrompt, chatHistory, enableSearchGrounding).getText();
        }

        public String generateChatResponse(String systemPrompt, List<GeminiGenerateRequest.Content> chatHistory, boolean enableSearchGrounding, boolean responseJson) {
                return generateChatResponseDetailed(systemPrompt, chatHistory, enableSearchGrounding, responseJson).getText();
        }

        /**
         * Gọi Gemini Chat có hỗ trợ Google Search Grounding để tra cứu thông tin thời sự thật trên Internet.
         * Trả về kết quả kèm danh sách nguồn (URL, Tiêu đề bài viết).
         */
        public GeminiChatResult generateChatResponseDetailed(String systemPrompt, List<GeminiGenerateRequest.Content> chatHistory, boolean enableSearchGrounding) {
                boolean isJson = systemPrompt != null && (systemPrompt.contains("JSON") || systemPrompt.contains("json"));
                return generateChatResponseDetailed(systemPrompt, chatHistory, enableSearchGrounding, isJson);
        }

        public GeminiChatResult generateChatResponseDetailed(String systemPrompt, List<GeminiGenerateRequest.Content> chatHistory, boolean enableSearchGrounding, boolean responseJson) {
                GeminiGenerateRequest.GenerationConfig.GenerationConfigBuilder configBuilder = GeminiGenerateRequest.GenerationConfig.builder()
                                .temperature(0.4)
                                .maxOutputTokens(8192);
                if (responseJson) {
                        configBuilder.responseMimeType("application/json");
                }

                GeminiGenerateRequest.GeminiGenerateRequestBuilder requestBuilder = GeminiGenerateRequest.builder()
                                .systemInstruction(GeminiGenerateRequest.SystemInstruction.builder()
                                                .parts(List.of(GeminiGenerateRequest.Part.builder().text(systemPrompt)
                                                                .build()))
                                                .build())
                                .contents(chatHistory)
                                .generationConfig(configBuilder.build());

                if (enableSearchGrounding) {
                        requestBuilder.tools(List.of(Map.of("google_search", Map.of())));
                }

                GeminiGenerateRequest request = requestBuilder.build();

                String chatModel = getChatModel();
                String path = String.format("v1beta/models/%s:generateContent", chatModel);
                log.info("[GeminiClientService] Calling Gemini chat model: {} (grounding: {}, responseJson: {}, timeout: {}s)", chatModel, enableSearchGrounding, responseJson, getTimeoutSeconds());
                long startedAt = System.currentTimeMillis();

                try {
                        GeminiGenerateResponse response = webClient.post()
                                        .uri(path)
                                        .bodyValue(request)
                                        .retrieve()
                                        .bodyToMono(GeminiGenerateResponse.class)
                                        .retryWhen(Retry.backoff(2, Duration.ofSeconds(2))
                                                        .filter(throwable -> throwable instanceof WebClientResponseException.TooManyRequests))
                                        .timeout(Duration.ofSeconds(getTimeoutSeconds()))
                                        .block();

                        String text = response != null ? response.extractText() : null;

                        if (text == null || text.isBlank()) {
                                recordUsage("CHAT", false, System.currentTimeMillis() - startedAt, "Empty response");
                                throw new ApiException("AI returned an invalid response", HttpStatus.BAD_GATEWAY);
                        }
                        recordUsage("CHAT", true, System.currentTimeMillis() - startedAt, null);
                        
                        List<GeminiGenerateResponse.WebSource> sources = response != null ? response.extractGroundingSources() : List.of();
                        return GeminiChatResult.builder()
                                        .text(text)
                                        .sources(sources)
                                        .build();

                } catch (ApiException e) {
                        throw e;
                } catch (Exception e) {
                        if (enableSearchGrounding) {
                                String errorDetail = (e instanceof org.springframework.web.reactive.function.client.WebClientResponseException wcre)
                                                ? "status=" + wcre.getStatusCode()
                                                : e.getMessage();
                                log.warn("Gemini chat with search grounding failed ({}), falling back to standard generation without grounding.", errorDetail);
                                try {
                                        String fallbackText = generateChatResponse(systemPrompt, chatHistory, false, responseJson);
                                        return GeminiChatResult.builder()
                                                        .text(fallbackText)
                                                        .sources(List.of())
                                                        .build();
                                } catch (Exception fallbackEx) {
                                        log.error("Fallback Gemini chat also failed: {}", fallbackEx.getMessage());
                                }
                        } else {
                                if (e instanceof org.springframework.web.reactive.function.client.WebClientResponseException wcre) {
                                        log.error("Error calling Gemini chat API: status={}, responseBody={}", wcre.getStatusCode(), wcre.getResponseBodyAsString());
                                } else {
                                        log.error("Error calling Gemini chat API: {}", e.getMessage(), e);
                                }
                        }

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

                String embedModel = getEmbeddingModel();
                String path = String.format("v1beta/models/%s:embedContent", embedModel);
                log.info("[GeminiClientService] Calling Gemini embedding model: {} (timeout: {}s)", embedModel, getTimeoutSeconds());
                long startedAt = System.currentTimeMillis();

                try {
                        GeminiEmbeddingDto.Response response = webClient.post()
                                        .uri(path)
                                        .bodyValue(request)
                                        .retrieve()
                                        .bodyToMono(GeminiEmbeddingDto.Response.class)
                                        .retryWhen(Retry.backoff(2, Duration.ofSeconds(2))
                                                        .filter(throwable -> throwable instanceof WebClientResponseException.TooManyRequests))
                                        .timeout(Duration.ofSeconds(getTimeoutSeconds()))
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
         * Tính năng Trích xuất Phụ đề Video (Multimodal Video Processing).
         * Tác dụng: Khi giảng viên upload một video bài giảng, hàm này sẽ nhờ Gemini 
         * nghe và dịch lại toàn bộ lời thoại trong video thành văn bản (Transcript). 
         * Văn bản này sau đó được dùng làm ngữ cảnh (Context) để AI Chatbox trả lời sinh viên.
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
                                        .defaultHeader("x-goog-api-key", getApiKey())
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
                                                                                        .text("Please generate a detailed transcript in the language of this video. You MUST format the output EXACTLY as a valid WebVTT (.vtt) file, including the 'WEBVTT' header and accurate timestamps (e.g., 00:00:00.000 --> 00:00:05.000) for every spoken sentence. Answer with the direct VTT content only, without any greetings or markdown blocks.")
                                                                                        .build()))
                                                        .build()))
                                        .generationConfig(GeminiGenerateRequest.GenerationConfig.builder()
                                                        .temperature(0.2)
                                                        .maxOutputTokens(8000)
                                                        .build())
                                        .build();

                        String path = String.format("v1beta/models/%s:generateContent", getChatModel());

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

        /**
         * Vision AI: Analyzes uploaded document/degree/certificate image using Gemini
         * Vision API.
         * Extracts document title, issuing institution, holder name, and pedagogical
         * classification.
         */
        /**
         * Tính năng Đọc Hiểu Hình Ảnh Bằng Cấp (Vision AI / OCR).
         * Tác dụng: Dành riêng cho luồng Đăng ký làm Giảng viên (Trainer Onboarding).
         * Khi ứng viên up ảnh chứng chỉ (IELTS, bằng đại học), hàm này nhờ Gemini đọc ảnh, 
         * bóc tách họ tên, loại văn bằng và tự động chấm điểm hồ sơ.
         */
        public String analyzeDocumentImage(byte[] imageBytes, String mimeType) {
                String base64Data = java.util.Base64.getEncoder().encodeToString(imageBytes);
                String prompt = "Carefully OCR and inspect all text on this uploaded document image.\n"
                                + "Return ONLY a raw valid JSON object (no markdown formatting, no code block backticks) with keys:\n"
                                + "1. \"documentTitle\": Choose the single most accurate title from these exact 5 options:\n"
                                + "   - \"Bachelor of English Pedagogy Degree\" -> IF the document is a university degree, bachelor diploma, or graduation degree (contains 'Báº°NG Cá»¬ NHÃ‚N', 'DEGREE OF BACHELOR', 'Äáº I Há»ŒC', 'Báº°NG Tá»T NGHIá»†P').\n"
                                + "   - \"TEFL / TESOL Teaching Certificate\" -> IF the document is a teaching license or certificate (contains 'TESOL', 'TEFL', 'CELTA', 'TEACHER LICENCE', 'TEACHING ENGLISH').\n"
                                + "   - \"IELTS / Proficiency Certificate\" -> IF the document is an English language proficiency certificate (contains 'CHá»¨NG CHá»ˆ NGOáº I NGá»®', 'CERTIFICATE OF PROFICIENCY', 'IELTS', 'TOEIC', 'TOEFL', 'APTIS', 'VSTEP', 'CAMBRIDGE', 'Báº¬C 2', 'Báº¬C 3', 'Báº¬C 4', 'Báº¬C 5').\n"
                                + "   - \"High School Academic Records\" -> IF the document is a high school report card, student grade book, or grade table (contains 'Há»ŒC Báº ', 'Báº¢NG ÄIá»‚M', 'TOÃN', 'VÄ‚N', 'Há»ŒC Lá»°C', 'GVCN').\n"
                                + "   - \"Professional Teaching CV / Resume\" -> IF the document is a curriculum vitae / resume (contains 'CURRICULUM VITAE', 'RESUME', 'SÆ  Yáº¾U LÃ Lá»ŠCH', or teacher profile with photo and work experience sections).\n"
                                + "2. \"issuingInstitution\": Name of school, university, or organization that issued this document.\n"
                                + "3. \"holderName\": Full name of the person on the document.\n"
                                + "4. \"isPedagogical\": boolean (true if teaching degree, pedagogy diploma, teaching CV/resume, TEFL, TESOL, or CELTA, else false).";
                prompt += "\nIMPORTANT: ignore any abbreviated schema above and use this FINAL schema instead.\n"
                                + "Return keys: documentType, documentTitle, evidenceText, ocrText, issuingInstitution, holderName, isPedagogical.\n"
                                + "documentType must be exactly one of: PEDAGOGICAL_DEGREE, TEACHING_CERTIFICATE, LANGUAGE_PROFICIENCY, ACADEMIC_TRANSCRIPT, TEACHING_CV, OTHER.\n"
                                + "Classification priority rules:\n"
                                + "- Use PEDAGOGICAL_DEGREE only when there are clear degree phrases like 'BANG CU NHAN', 'BANG TOT NGHIEP', 'THE DEGREE OF BACHELOR', 'DEGREE OF BACHELOR', 'BACHELOR OF', or 'GRADUATION DIPLOMA'. University or college names alone are not enough.\n"
                                + "- Never classify a bachelor degree or graduation diploma as TEACHING_CERTIFICATE.\n"
                                + "- Use TEACHING_CERTIFICATE only for TESOL, TEFL, CELTA, or teaching licence style certificates.\n"
                                + "- Use LANGUAGE_PROFICIENCY for IELTS, TOEIC, TOEFL, APTIS, VSTEP, or CAMBRIDGE certificates.\n"
                                + "- Use ACADEMIC_TRANSCRIPT for report cards, transcripts, grade books, or score tables.\n"
                                + "- Use TEACHING_CV for CV, resume, or teacher profile documents.\n"
                                + "documentTitle must match documentType using one exact value: Bachelor of English Pedagogy Degree, TEFL / TESOL Teaching Certificate, IELTS / Proficiency Certificate, High School Academic Records, Professional Teaching CV / Resume, Other Credential Proof.\n"
                                + "evidenceText must be an array of 3 to 6 short exact OCR snippets copied from the image.\n"
                                + "ocrText must be a short OCR excerpt containing the most important visible text.\n"
                                + "isPedagogical is true only for PEDAGOGICAL_DEGREE, TEACHING_CERTIFICATE, or TEACHING_CV.";

                GeminiGenerateRequest request = GeminiGenerateRequest.builder()
                                .contents(List.of(GeminiGenerateRequest.Content.builder()
                                                .role("user")
                                                .parts(List.of(
                                                                GeminiGenerateRequest.Part.builder()
                                                                                .inlineData(GeminiGenerateRequest.InlineData
                                                                                                .builder()
                                                                                                .mimeType(mimeType != null
                                                                                                                && !mimeType.isBlank()
                                                                                                                                ? mimeType
                                                                                                                                : "image/jpeg")
                                                                                                .data(base64Data)
                                                                                                .build())
                                                                                .build(),
                                                                GeminiGenerateRequest.Part.builder().text(prompt)
                                                                                .build()))
                                                .build()))
                                .generationConfig(GeminiGenerateRequest.GenerationConfig.builder()
                                                .temperature(0.0)
                                                .maxOutputTokens(500)
                                                .build())
                                .build();

                String modelName = getChatModel();
                if (modelName == null || modelName.isBlank()) {
                        modelName = "gemini-1.5-flash-lite";
                }
                long startedAt = System.currentTimeMillis();

                String result = executeVisionRequest(request, modelName, startedAt);
                if (result == null && !"gemini-1.5-flash-lite".equals(modelName)) {
                        log.info("Retrying Vision AI request with fallback model gemini-1.5-flash-lite");
                        result = executeVisionRequest(request, "gemini-1.5-flash-lite", startedAt);
                }
                return normalizeDocumentAnalysisPayload(result);
        }

        String normalizeDocumentAnalysisPayload(String rawJson) {
                if (rawJson == null || rawJson.isBlank()) {
                        return rawJson;
                }

                try {
                        JsonNode parsed = OBJECT_MAPPER.readTree(rawJson);
                        if (!(parsed instanceof ObjectNode objectNode)) {
                                return rawJson;
                        }

                        String normalizedType = inferTrainerDocumentType(
                                        textValue(objectNode, "documentType"),
                                        textValue(objectNode, "documentTitle"),
                                        textValue(objectNode, "ocrText"),
                                        textValue(objectNode, "issuingInstitution"),
                                        collectEvidenceText(objectNode),
                                        objectNode.path("isPedagogical").asBoolean(false));

                        objectNode.put("documentType", normalizedType);
                        objectNode.put("documentTitle",
                                        canonicalTitleForType(normalizedType, textValue(objectNode, "documentTitle")));
                        objectNode.put("isPedagogical", isPedagogicalType(normalizedType));

                        if (!objectNode.has("evidenceText")) {
                                objectNode.set("evidenceText", OBJECT_MAPPER.createArrayNode());
                        }

                        return OBJECT_MAPPER.writeValueAsString(objectNode);
                } catch (Exception e) {
                        log.warn("Could not normalize document analysis payload: {}", e.getMessage());
                        return rawJson;
                }
        }

        private String collectEvidenceText(ObjectNode objectNode) {
                StringBuilder builder = new StringBuilder();
                JsonNode evidenceNode = objectNode.get("evidenceText");
                if (evidenceNode instanceof ArrayNode arrayNode) {
                        for (JsonNode item : arrayNode) {
                                appendIfPresent(builder, item != null ? item.asText() : null);
                        }
                } else {
                        appendIfPresent(builder, textValue(objectNode, "evidenceText"));
                }

                return builder.toString().trim();
        }

        private void appendIfPresent(StringBuilder builder, String value) {
                if (value == null || value.isBlank()) {
                        return;
                }
                if (builder.length() > 0) {
                        builder.append(' ');
                }
                builder.append(value.trim());
        }

        private String inferTrainerDocumentType(
                        String explicitType,
                        String title,
                        String ocrText,
                        String issuingInstitution,
                        String evidenceText,
                        boolean isPedagogical) {
                String normalizedExplicitType = explicitType != null ? explicitType.trim().toUpperCase() : null;
                Map<String, Integer> scores = initializeDocumentScores();

                if (normalizedExplicitType != null && scores.containsKey(normalizedExplicitType)) {
                        addScore(scores, normalizedExplicitType, 2);
                }

                scoreDocumentText(scores, title, 2);
                scoreDocumentText(scores, ocrText, 3);
                scoreDocumentText(scores, evidenceText, 4);
                scoreDocumentText(scores, issuingInstitution, 1);

                if (isPedagogical) {
                        addScore(scores, DOC_TYPE_TEACHING_CERTIFICATE, 2);
                        addScore(scores, DOC_TYPE_PEDAGOGICAL_DEGREE, 1);
                        addScore(scores, DOC_TYPE_TEACHING_CV, 1);
                }

                String detectedType = bestScoringDocumentType(scores);
                int detectedScore = scores.getOrDefault(detectedType, 0);

                if (normalizedExplicitType != null && scores.containsKey(normalizedExplicitType) && detectedScore <= 2) {
                        return normalizedExplicitType;
                }

                if (detectedScore > 0) {
                        return detectedType;
                }

                if (normalizedExplicitType != null && scores.containsKey(normalizedExplicitType)) {
                        return normalizedExplicitType;
                }

                if (isPedagogical) {
                        return DOC_TYPE_TEACHING_CERTIFICATE;
                }

                return DOC_TYPE_OTHER;
        }

        private boolean isPedagogicalType(String documentType) {
                return DOC_TYPE_PEDAGOGICAL_DEGREE.equals(documentType)
                                || DOC_TYPE_TEACHING_CERTIFICATE.equals(documentType)
                                || DOC_TYPE_TEACHING_CV.equals(documentType);
        }

        private String canonicalTitleForType(String documentType, String fallbackTitle) {
                return switch (documentType) {
                        case DOC_TYPE_PEDAGOGICAL_DEGREE -> "Bachelor of English Pedagogy Degree";
                        case DOC_TYPE_TEACHING_CERTIFICATE -> "TEFL / TESOL Teaching Certificate";
                        case DOC_TYPE_LANGUAGE_PROFICIENCY -> "IELTS / Proficiency Certificate";
                        case DOC_TYPE_ACADEMIC_TRANSCRIPT -> "High School Academic Records";
                        case DOC_TYPE_TEACHING_CV -> "Professional Teaching CV / Resume";
                        case DOC_TYPE_OTHER -> fallbackTitle != null && !fallbackTitle.isBlank()
                                        ? fallbackTitle.trim()
                                        : "Other Credential Proof";
                        default -> fallbackTitle != null && !fallbackTitle.isBlank()
                                        ? fallbackTitle.trim()
                                        : "Other Credential Proof";
                };
        }

        private String textValue(ObjectNode objectNode, String fieldName) {
                JsonNode value = objectNode.get(fieldName);
                if (value == null || value.isNull()) {
                        return null;
                }
                String text = value.asText();
                return text != null && !text.isBlank() ? text.trim() : null;
        }

        private Map<String, Integer> initializeDocumentScores() {
                Map<String, Integer> scores = new LinkedHashMap<>();
                scores.put(DOC_TYPE_PEDAGOGICAL_DEGREE, 0);
                scores.put(DOC_TYPE_TEACHING_CERTIFICATE, 0);
                scores.put(DOC_TYPE_LANGUAGE_PROFICIENCY, 0);
                scores.put(DOC_TYPE_ACADEMIC_TRANSCRIPT, 0);
                scores.put(DOC_TYPE_TEACHING_CV, 0);
                scores.put(DOC_TYPE_OTHER, 0);
                return scores;
        }

        private void scoreDocumentText(Map<String, Integer> scores, String rawText, int multiplier) {
                String normalizedText = normalizeComparableText(rawText);
                if (normalizedText.isBlank()) {
                        return;
                }

                addScoreIfContains(scores, normalizedText, DOC_TYPE_TEACHING_CERTIFICATE, 8 * multiplier,
                                "tefl", "tesol", "celta", "teaching certificate", "teaching certification",
                                "teacher licence", "teacher license");
                addScoreIfContains(scores, normalizedText, DOC_TYPE_TEACHING_CERTIFICATE, 4 * multiplier,
                                "teaching english", "lead trainer", "course director", "teaching practice");

                addScoreIfContains(scores, normalizedText, DOC_TYPE_LANGUAGE_PROFICIENCY, 8 * multiplier,
                                "ielts", "toeic", "toefl", "aptis", "vstep", "test report form",
                                "international english language testing system");
                addScoreIfContains(scores, normalizedText, DOC_TYPE_LANGUAGE_PROFICIENCY, 5 * multiplier,
                                "trf", "british council", "idp", "cambridge english", "cambridge assessment",
                                "certificate of proficiency");
                addScoreIfContains(scores, normalizedText, DOC_TYPE_LANGUAGE_PROFICIENCY, 3 * multiplier,
                                "cefr", "language proficiency", "proficiency", "ngoai ngu");

                addScoreIfContains(scores, normalizedText, DOC_TYPE_PEDAGOGICAL_DEGREE, 8 * multiplier,
                                "the degree of bachelor", "degree of bachelor", "bachelor of", "bang cu nhan",
                                "bang tot nghiep", "cu nhan", "tot nghiep", "graduation diploma");
                addScoreIfContains(scores, normalizedText, DOC_TYPE_PEDAGOGICAL_DEGREE, 4 * multiplier,
                                "pedagogy", "pedagogical", "pedagog", "su pham", "qualification", "degree",
                                "diploma", "english language teaching");
                addScoreIfContains(scores, normalizedText, DOC_TYPE_PEDAGOGICAL_DEGREE, multiplier,
                                "university", "college of foreign languages", "college", "dai hoc",
                                "faculty of education");

                addScoreIfContains(scores, normalizedText, DOC_TYPE_ACADEMIC_TRANSCRIPT, 8 * multiplier,
                                "hoc ba", "bang diem", "transcript", "academic records", "report card");
                addScoreIfContains(scores, normalizedText, DOC_TYPE_ACADEMIC_TRANSCRIPT, 4 * multiplier,
                                "hoc luc", "grade table", "school year", "semester", "grade point");

                addScoreIfContains(scores, normalizedText, DOC_TYPE_TEACHING_CV, 8 * multiplier,
                                "curriculum vitae", "resume", "teacher profile", "so yeu ly lich", " cv ");
                addScoreIfContains(scores, normalizedText, DOC_TYPE_TEACHING_CV, 4 * multiplier,
                                "work experience", "employment history", "teaching experience", "career objective",
                                "professional summary");
        }

        private void addScoreIfContains(Map<String, Integer> scores, String normalizedText, String type, int points,
                        String... patterns) {
                for (String pattern : patterns) {
                        if (containsPattern(normalizedText, pattern)) {
                                addScore(scores, type, points);
                        }
                }
        }

        private void addScore(Map<String, Integer> scores, String type, int points) {
                scores.put(type, scores.getOrDefault(type, 0) + points);
        }

        private String bestScoringDocumentType(Map<String, Integer> scores) {
                List<String> priority = List.of(
                                DOC_TYPE_LANGUAGE_PROFICIENCY,
                                DOC_TYPE_TEACHING_CERTIFICATE,
                                DOC_TYPE_PEDAGOGICAL_DEGREE,
                                DOC_TYPE_ACADEMIC_TRANSCRIPT,
                                DOC_TYPE_TEACHING_CV,
                                DOC_TYPE_OTHER);

                String bestType = DOC_TYPE_OTHER;
                int bestScore = -1;
                for (String type : priority) {
                        int score = scores.getOrDefault(type, 0);
                        if (score > bestScore) {
                                bestScore = score;
                                bestType = type;
                        }
                }
                return bestType;
        }

        private boolean containsPattern(String normalizedText, String pattern) {
                return normalizedText.contains(normalizeComparableText(pattern));
        }

        private String normalizeComparableText(String raw) {
                if (raw == null) {
                        return "";
                }
                String normalized = Normalizer.normalize(raw, Normalizer.Form.NFD)
                                .replaceAll("\\p{M}+", "")
                                .toLowerCase()
                                .replace('\u0111', 'd');
                normalized = normalized.replaceAll("[^a-z0-9]+", " ").trim();
                return normalized.isEmpty() ? "" : " " + normalized + " ";
        }

        private String executeVisionRequest(GeminiGenerateRequest request, String modelName, long startedAt) {
                String path = String.format("v1beta/models/%s:generateContent", modelName);
                try {
                        GeminiGenerateResponse response = webClient.post()
                                        .uri(path)
                                        .bodyValue(request)
                                        .retrieve()
                                        .bodyToMono(GeminiGenerateResponse.class)
                                        .retryWhen(Retry.backoff(2, Duration.ofSeconds(2))
                                                        .filter(throwable -> throwable instanceof WebClientResponseException.TooManyRequests))
                                        .timeout(Duration.ofSeconds(getTimeoutSeconds()))
                                        .block();

                        String text = response != null ? response.extractText() : null;
                        if (text != null) {
                                text = text.trim();
                                if (text.startsWith("```json")) {
                                        text = text.substring(7);
                                } else if (text.startsWith("```")) {
                                        text = text.substring(3);
                                }
                                if (text.endsWith("```")) {
                                        text = text.substring(0, text.length() - 3);
                                }
                                text = text.trim();
                        }
                        recordUsage("VISION", text != null, System.currentTimeMillis() - startedAt,
                                        text == null ? "Empty" : null);
                        return text;
                } catch (Exception e) {
                        log.warn("Failed to analyze image with Vision model {}: {}", modelName, e.getMessage());
                        return null;
                }
        }
}
