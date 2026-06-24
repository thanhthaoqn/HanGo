package com.hango.hango_backend.service;

import com.hango.hango_backend.config.GeminiProperties;
import com.hango.hango_backend.dto.AiHealthResponse;
import com.hango.hango_backend.dto.GeminiEmbeddingDto;
import com.hango.hango_backend.dto.GeminiGenerateRequest;
import com.hango.hango_backend.dto.GeminiGenerateResponse;
import com.hango.hango_backend.exeption.ApiException;
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
 * Lớp duy nhất trong toàn hệ thống gọi trực tiếp tới Gemini API.
 * Tự động khởi tạo WebClient nội bộ để tránh lỗi định tuyến nhầm domain.
 */
@Service
@Slf4j
public class GeminiClientService {

        private WebClient webClient;
        private final GeminiProperties geminiProperties;

        // Sử dụng Constructor injection thủ công thay cho @RequiredArgsConstructor
        public GeminiClientService(GeminiProperties geminiProperties) {
                this.geminiProperties = geminiProperties;
        }

        /**
         * Tự động chạy ngay khi ứng dụng khởi động để thiết lập WebClient với Base URL
         * chính xác và tích hợp bảo mật Header x-goog-api-key cho khóa dạng AQ.
         */
        @PostConstruct
        public void init() {
                // Lấy baseUrl cấu hình từ file properties, nếu trống thì dùng URL gốc của Google làm dự phòng
                String baseUrl = geminiProperties.getBaseUrl();
                if (baseUrl == null || baseUrl.isBlank()) {
                        baseUrl = "https://generativelanguage.googleapis.com";
                }
                
                // Đảm bảo baseUrl kết thúc bằng dấu gạch chéo để WebClient ghép path không lỗi
                if (!baseUrl.endsWith("/")) {
                        baseUrl = baseUrl + "/";
                }

                // Cấu hình WebClient dùng chung: Đính kèm sẵn Header nhận diện API Key cho Google AI Studio
                this.webClient = WebClient.builder()
                                .baseUrl(baseUrl)
                                .defaultHeader("Content-Type", "application/json")
                                // 🔥 ĐÂY LÀ DÒNG QUAN TRỌNG: Đưa trực tiếp API Key thế hệ mới vào Header hệ thống
                                .defaultHeader("x-goog-api-key", geminiProperties.getApiKey())
                                .build();
                log.info("Gemini WebClient khởi tạo thành công với địa chỉ: {}", baseUrl);
        }

        @Cacheable(value = "geminiStatus")
        public AiHealthResponse checkAvailability() {
                if (geminiProperties.getApiKey() == null || geminiProperties.getApiKey().isBlank()) {
                        return buildHealth(false, "GEMINI_API_KEY chua duoc cau hinh");
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
                                return buildHealth(false, "Gemini da phan hoi nhung khong co noi dung hop le");
                        }
                        return buildHealth(true, "Gemini API san sang");
                } catch (Exception e) {
                        log.warn("Gemini health check failed", e);
                        return buildHealth(false, "Khong goi duoc Gemini API: " + e.getClass().getSimpleName());
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
         * Gọi Gemini chat model để sinh câu trả lời, kèm theo TOÀN BỘ LỊCH SỬ cuộc trò chuyện.
         */
        public String generateChatResponse(String systemPrompt, List<GeminiGenerateRequest.Content> chatHistory) {
                GeminiGenerateRequest request = GeminiGenerateRequest.builder()
                                .systemInstruction(GeminiGenerateRequest.SystemInstruction.builder()
                                                .parts(List.of(GeminiGenerateRequest.Part.builder().text(systemPrompt)
                                                                .build()))
                                                .build())
                                .contents(chatHistory) // Gửi toàn bộ mảng lịch sử bao gồm cả câu hỏi mới ở cuối
                                .generationConfig(GeminiGenerateRequest.GenerationConfig.builder()
                                                .temperature(0.4)
                                                .maxOutputTokens(800)
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

                                        // 🛡️ TỰ ĐỘNG THỬ LẠI KHI DÍNH LỖI NGHẼN MẠCH 429
                                        .retryWhen(Retry.backoff(2, Duration.ofSeconds(2))
                                                        .filter(throwable -> throwable instanceof WebClientResponseException.TooManyRequests))

                                        .timeout(Duration.ofSeconds(geminiProperties.getTimeoutSeconds()))
                                        .block();

                        String text = response != null ? response.extractText() : null;

                        if (text == null || text.isBlank()) {
                                throw new ApiException("AI không trả về nội dung hợp lệ", HttpStatus.BAD_GATEWAY);
                        }
                        return text;

                } catch (ApiException e) {
                        throw e;
                } catch (Exception e) {
                        log.error("Lỗi khi gọi Gemini chat API", e);
                        throw new ApiException("Không thể kết nối tới AI Assistant lúc này, vui lòng thử lại sau",
                                        HttpStatus.SERVICE_UNAVAILABLE);
                }
        }

        /**
         * Gọi Gemini embedding model để chuyển 1 đoạn text thành vector số.
         */
        public List<Double> generateEmbedding(String text) {

                GeminiEmbeddingDto.Request request = GeminiEmbeddingDto.Request.builder()
                                .content(GeminiEmbeddingDto.Request.Content.builder()
                                                .parts(List.of(GeminiEmbeddingDto.Request.Part.builder().text(text)
                                                                .build()))
                                                .build())
                                .build();

                // ✅ ĐÃ SỬA: Loại bỏ hoàn toàn tham số `?key=` gây lỗi 403 trên URL
                String path = String.format("v1beta/models/%s:embedContent", geminiProperties.getEmbeddingModel());

                try {
                        GeminiEmbeddingDto.Response response = webClient.post()
                                        .uri(path)
                                        .bodyValue(request)
                                        .retrieve()
                                        .bodyToMono(GeminiEmbeddingDto.Response.class)

                                        // 🛡️ TỰ ĐỘNG THỬ LẠI KHI DÍNH LỖI NGHẼN MẠCH 429
                                        .retryWhen(Retry.backoff(2, Duration.ofSeconds(2))
                                                        .filter(throwable -> throwable instanceof WebClientResponseException.TooManyRequests))

                                        .timeout(Duration.ofSeconds(geminiProperties.getTimeoutSeconds()))
                                        .block();

                        if (response == null || response.getEmbedding() == null) {
                                throw new ApiException("Không thể tạo embedding cho nội dung này",
                                                HttpStatus.BAD_GATEWAY);
                        }
                        return response.getEmbedding().getValues();

                } catch (ApiException e) {
                        throw e;
                } catch (Exception e) {
                        log.error("Lỗi khi gọi Gemini embedding API", e);
                        throw new ApiException("Không thể xử lý nội dung lúc này, vui lòng thử lại sau",
                                        HttpStatus.SERVICE_UNAVAILABLE);
                }
        }
}