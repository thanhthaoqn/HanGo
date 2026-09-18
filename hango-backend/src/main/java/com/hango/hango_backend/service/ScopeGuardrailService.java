package com.hango.hango_backend.service;

import com.hango.hango_backend.config.AIAssistantProperties;
import com.hango.hango_backend.entity.Lesson;
import com.hango.hango_backend.util.VectorUtil;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;

import java.util.List;

/**
 * GUARDRAIL LỚP 3: Embedding similarity check.
 *
 * Đây là lớp lọc ĐỘC LẬP với việc gọi Gemini chat model - mục đích là chặn câu hỏi
 * ngoài phạm vi TRƯỚC KHI nó được gửi tới LLM, để:
 *   (a) tránh tốn chi phí gọi API cho câu hỏi rõ ràng không liên quan,
 *   (b) tránh trường hợp LLM "cố trả lời" một câu hỏi ngoài lề dù system prompt đã yêu cầu không làm vậy
 *       (prompt injection / jailbreak vẫn có thể xảy ra nếu chỉ dựa vào lớp 1).
 *
 * Cách hoạt động:
 *   1. Lấy embedding của nội dung bài học (đã cache - xem LessonEmbeddingService).
 *   2. Tính embedding của câu hỏi learner vừa gửi.
 *   3. Tính cosine similarity giữa 2 vector.
 *   4. Nếu similarity < ngưỡng (config: hango.ai-assistant.scope-similarity-threshold) -> NGOÀI PHẠM VI.
 *
 * Lưu ý: đây là 1 trong 3 lớp (cùng với prompt engineering ở GeminiClientService/PromptBuilder,
 * và việc bắt buộc conversation phải gắn với 1 Lesson cụ thể ở AIAssistantService).
 */
@Service
@RequiredArgsConstructor
@Slf4j
public class ScopeGuardrailService {

    private final GeminiClientService geminiClientService;
    private final LessonEmbeddingService lessonEmbeddingService;
    private final AIAssistantProperties aiAssistantProperties;

    public ScopeCheckResult checkScope(Lesson lesson, String userMessage, java.util.List<com.hango.hango_backend.dto.QuizQuestionDTO> practiceQuestions) {

        // Câu hỏi quá ngắn (vd "ok", "hi") thường là giao tiếp xã giao, không cần chặn -
        // để LLM tự xử lý lịch sự, tránh guardrail quá nhạy gây trải nghiệm xấu.
        if (userMessage.trim().length() < 8) {
            return new ScopeCheckResult(true, 1.0);
        }

        try {
            // TỐI ƯU: Sử dụng embedding đã cache sẵn trong DB (tính 1 lần khi bài học được tạo/sửa)
            // thay vì gọi API tính lại mỗi lần learner chat — tiết kiệm ~50% lượt gọi Gemini Embedding.
            // Bài tập luyện tập vẫn được bao phủ đầy đủ bởi Guardrail Lớp 1 (prompt engineering
            // trong AIPromptBuilder đã nhúng toàn bộ practice questions vào system prompt).
            List<Double> scopeVector = lessonEmbeddingService.getOrComputeEmbedding(lesson);
            List<Double> messageVector = geminiClientService.generateEmbedding(userMessage);

            // Buoc 3+4: tinh cosine similarity va so sanh voi nguong cau hinh
            double similarity = VectorUtil.cosineSimilarity(scopeVector, messageVector);
            boolean inScope = similarity >= aiAssistantProperties.getScopeSimilarityThreshold();

            log.debug("Scope check - lessonId={}, similarity={}, threshold={}, inScope={}",
                    lesson.getId(), similarity, aiAssistantProperties.getScopeSimilarityThreshold(), inScope);

            return new ScopeCheckResult(inScope, similarity);

        } catch (Exception e) {
            log.error("Lỗi tầng Guardrail Embedding: {}. Tạm thời bỏ qua để không làm sập luồng chat.", e.getMessage());
            // Khi API Embedding lỗi (404/429), trả về true để chuyển tiếp câu hỏi sang cho Gemini Chat tự từ chối khéo.
            return new ScopeCheckResult(true, 1.0);
        }
    }

    public ScopeCheckResult checkScope(Lesson lesson, String userMessage) {
        return checkScope(lesson, userMessage, java.util.List.of());
    }

    public record ScopeCheckResult(boolean inScope, double similarityScore) {}
}
