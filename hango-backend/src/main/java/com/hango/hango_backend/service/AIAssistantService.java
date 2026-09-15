package com.hango.hango_backend.service;

import com.hango.hango_backend.dto.SendMessageRequest;
import com.hango.hango_backend.dto.SendMessageResponse;
import com.hango.hango_backend.entity.*;
import com.hango.hango_backend.exception.ApiException;
import com.hango.hango_backend.repository.AIConversationRepository;
import com.hango.hango_backend.repository.LessonRepository;
import com.hango.hango_backend.repository.UserRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;

import com.hango.hango_backend.service.LessonService;

/**
 * AI Learning Assistant (FT-08 / UC-31) - service điều phối chính.
 *
 * Đây là nơi 3 lớp guardrail được áp dụng theo đúng thứ tự đã thống nhất:
 *
 * LỚP 2 (backend context check): bắt buộc mọi conversation phải gắn với 1
 * Lesson
 * tồn tại thật trong hệ thống. AI không bao giờ được hỏi "chat tự do không bối
 * cảnh".
 *
 * LỚP 3 (embedding similarity): trước khi gọi Gemini, kiểm tra câu hỏi của
 * learner
 * có liên quan ngữ nghĩa tới nội dung bài học không. Nếu không -> chặn ngay,
 * trả về câu trả lời "từ chối khéo léo" có sẵn, KHÔNG tốn lượt gọi LLM.
 *
 * LỚP 1 (prompt engineering): nếu qua được lớp 3, mới gọi Gemini với system
 * prompt
 * giới hạn phạm vi (xem AIPromptBuilder) - đây là lớp phòng thủ cuối, xử lý các
 * trường hợp tinh vi mà similarity check chưa bắt được hết.
 */
@Service
@RequiredArgsConstructor
@Slf4j
public class AIAssistantService {

        private final AIConversationRepository conversationRepository;
        private final LessonRepository lessonRepository;
        private final UserRepository userRepository;
        private final ScopeGuardrailService scopeGuardrailService;
        private final AIPromptBuilder promptBuilder;
        private final GeminiClientService geminiClientService;
        private final LessonService lessonService;

        @Transactional
        public SendMessageResponse sendMessage(Long learnerId, SendMessageRequest request) {
                // Kiểm tra an toàn chặn null learnerId
                if (learnerId == null) {
                        throw new ApiException("Người dùng chưa đăng nhập hoặc Token không hợp lệ",
                                        HttpStatus.UNAUTHORIZED);
                }

                // LỚP 2: Lesson phải tồn tại thật - đây là "phạm vi" mà mọi guardrail khác dựa
                // vào.
                Lesson lesson = lessonRepository.findById(request.getLessonId())
                                .orElseThrow(() -> new ApiException("Không tìm thấy bài học này",
                                                HttpStatus.NOT_FOUND));

                AIConversation conversation = getOrCreateConversation(learnerId, request, lesson);

                // Lưu message của learner trước (để có lịch sử đầy đủ dù bị chặn hay không)
                AIMessage userMessage = AIMessage.builder()
                                .conversation(conversation)
                                .role(AIMessage.MessageRole.USER)
                                .content(request.getMessage())
                                .build();

                // Lấy practice questions để nhúng vào scope + prompt
                // Practice data được trả về trong LessonDetailDTO.questions (từ
                // LessonServiceImpl).
                com.hango.hango_backend.dto.LessonDetailDTO lessonDetail = lessonService
                                .getLessonDetail(request.getLessonId(), learnerId);
                java.util.List<com.hango.hango_backend.dto.QuizQuestionDTO> practiceQuestions = (lessonDetail != null
                                && lessonDetail.getQuestions() != null)
                                                ? lessonDetail.getQuestions()
                                                : java.util.List.of();

                // LOP 3: Goi guardrail embedding de so sanh do tuong dong gi cau hoi va noi dung bai hoc
                // practiceQuestions duoc nap them de mo rong pham vi scope (AI doc duoc ca de bai tap)
                ScopeGuardrailService.ScopeCheckResult scopeCheck = scopeGuardrailService.checkScope(
                                lesson,
                                request.getMessage(),
                                practiceQuestions);

                String replyText;
                boolean outOfScope = !scopeCheck.inScope();

                if (outOfScope) {
                        // Bị chặn ở lớp 3 -> KHÔNG gọi Gemini, dùng câu trả lời từ chối có sẵn de tiet kiem chi phi LLM
                        replyText = promptBuilder.buildOutOfScopeFallback(lesson);
                        log.info("AI guardrail chặn câu hỏi ngoài phạm vi - learnerId={}, lessonId={}, similarity={}",
                                        learnerId, lesson.getId(), scopeCheck.similarityScore());
                } else {
                        // LỚP 1: Xây dựng mảng lịch sử chat (Chat History) gửi kèm sang Gemini
                        List<com.hango.hango_backend.dto.GeminiGenerateRequest.Content> geminiHistory = new java.util.ArrayList<>();

                        // 1. Map toàn bộ các tin nhắn cũ trong DB (Nếu có)
                        if (conversation.getMessages() != null) {
                                for (AIMessage oldMsg : conversation.getMessages()) {
                                        // Chỉ lấy những tin nhắn không bị guardrail chặn trước đó để tránh làm nhiễu AI
                                        if (Boolean.TRUE.equals(oldMsg.getWasOutOfScope())) {
                                                continue;
                                        }

                                        // Chuyển đổi Role từ Hệ thống của bạn sang định dạng Gemini ("user" hoặc
                                        // "model")
                                        String geminiRole = (oldMsg.getRole() == AIMessage.MessageRole.USER) ? "user"
                                                        : "model";

                                        geminiHistory.add(com.hango.hango_backend.dto.GeminiGenerateRequest.Content
                                                        .builder()
                                                        .role(geminiRole)
                                                        .parts(List.of(com.hango.hango_backend.dto.GeminiGenerateRequest.Part
                                                                        .builder()
                                                                        .text(oldMsg.getContent())
                                                                        .build()))
                                                        .build());
                                }
                        }

                        // 2. Thêm chính câu hỏi HIỆN TẠI của người dùng vào cuối mảng lịch sử
                        // Day la cau hoi moi nhat, dua vao de AI biet phai tra loi gi
                        geminiHistory.add(com.hango.hango_backend.dto.GeminiGenerateRequest.Content.builder()
                                        .role("user")
                                        .parts(List.of(com.hango.hango_backend.dto.GeminiGenerateRequest.Part
                                                        .builder()
                                                        .text(request.getMessage())
                                                        .build()))
                                        .build());

                        // 3. Goi Gemini voi System Prompt va toan bo lich su cuoc tro chuyen
                        // Nhung luon practiceQuestions de AI "doc duoc de bai".
                        String systemPrompt = promptBuilder.buildSystemPrompt(lesson, practiceQuestions);
                        // Day la diem duy nhat ton chi phi goi LLM trong flow chatbox
                        replyText = geminiClientService.generateChatResponse(systemPrompt, geminiHistory);
                }

                userMessage.setWasOutOfScope(outOfScope);

                // Sinh suggestedQuestions (3 câu) dựa theo ngữ cảnh bài học + câu trả lời vừa
                // tạo.
                // Nếu out-of-scope thì vẫn trả về null/empty để UI có thể ẩn.
                java.util.List<String> suggestedQuestions = new java.util.ArrayList<>();
                try {
                        if (!outOfScope) {
                                // Yêu cầu Gemini trả đúng 3 câu hỏi, mỗi câu 1 dòng.
                                String systemForSuggestions = """
                                                Bạn là trợ lý học tập AI.
                                                Dựa trên BÀI HỌC, CÂU HỎI NGƯỜI HỌC và đặc biệt là NỘI DUNG TRẢ LỜI của trợ lý (TRỢ LÝ ĐÃ TRẢ LỜI),
                                                hãy đề xuất đúng 3 câu hỏi tiếp theo (tiếng Việt hoặc tiếng Anh tùy vào câu trả lời trước đó của bạn)
                                                để người học tiếp tục đào sâu.

                                                QUAN TRỌNG (BẮT BUỘC):
                                                - 3 câu gợi ý này CHỈ LÀ CÂU HỎI (không phải đáp án).
                                                - TUYỆT ĐỐI KHÔNG kèm đáp án/giải thích đầy đủ cho quiz vừa được tạo trong đoạn chat.
                                                - Không được đưa các cụm như: "Đáp án là", "Correct answer", "đúng là", "A/B/C", hoặc các phương án kèm đáp án.
                                                - Không được trả lời luôn câu hỏi/quiz mà trước đó trợ lý vừa tạo.
                                                - Nếu trợ lý vừa tạo quiz trắc nghiệm nhiều lựa chọn, câu gợi ý phải hỏi một ý/khái niệm khác, ví dụ khác, hoặc
                                                yêu cầu luyện tập tương tự nhưng KHÔNG kèm đáp án.

                                                Mỗi câu hỏi phải:
                                                - bám sát TRỢ LÝ ĐÃ TRẢ LỜI (ví dụ: hỏi rõ một ý, hỏi ví dụ minh hoạ khác, hỏi bước tiếp theo, hỏi cách áp dụng)
                                                - liên quan trực tiếp đến bài học và có thể trả lời được trong phạm vi bài học
                                                - độ dài ngắn gọn (<= 80 ký tự)
                                                - không hỏi ngoài lề

                                                YÊU CẦU FORMAT BẮT BUỘC:
                                                Trả về JSON thuần, đúng như:
                                                {"suggestedQuestions":["...","...","..."]}
                                                """;

                                // Dùng promptbuilder hệ thống hiện tại cho scope, nhưng thêm ràng buộc format.
                                // Ta gửi: systemForSuggestions + history gồm câu hỏi hiện tại & replyText.
                                java.util.List<com.hango.hango_backend.dto.GeminiGenerateRequest.Content> history = new java.util.ArrayList<>();

                                // history.add(...) - sửa lỗi builder/parts để tránh IDE hiểu nhầm kiểu builder.
                                history.add(
                                                com.hango.hango_backend.dto.GeminiGenerateRequest.Content.builder()
                                                                .role("user")
                                                                .parts(
                                                                                java.util.List.of(
                                                                                                com.hango.hango_backend.dto.GeminiGenerateRequest.Part
                                                                                                                .builder()
                                                                                                                .text("Bài học: "
                                                                                                                                + lesson.getTitle()
                                                                                                                                + "\n\nNội dung: "
                                                                                                                                + lesson.getContentText()
                                                                                                                                + "\n\nCâu hỏi learner: "
                                                                                                                                + request.getMessage()
                                                                                                                                + "\n\nTrợ lý đã trả lời: "
                                                                                                                                + replyText)
                                                                                                                .build()))
                                                                .build());

                                // Gọi Gemini lấy JSON.
                                String raw = geminiClientService.generateChatResponse(systemForSuggestions, history);

                                // Parse JSON đơn giản: tìm mảng suggestedQuestions.
                                // Tránh dependency JSON mapper mới: parse thủ công thô theo pattern.
                                // (Trong thực tế nên dùng Jackson; nhưng để nhanh, dùng xử lý cơ bản)
                                int startArr = raw.indexOf("[");
                                int endArr = raw.lastIndexOf("]");
                                if (startArr != -1 && endArr != -1 && endArr > startArr) {
                                        String arr = raw.substring(startArr + 1, endArr);
                                        // match chuỗi trong dấu "..."
                                        java.util.regex.Matcher m = java.util.regex.Pattern.compile("\\\"(.*?)\\\"")
                                                        .matcher(arr);
                                        while (m.find()) {
                                                String q = m.group(1);
                                                if (q != null) {
                                                        q = q.trim();
                                                        if (!q.isEmpty())
                                                                suggestedQuestions.add(q);
                                                }
                                                if (suggestedQuestions.size() >= 3)
                                                        break;
                                        }
                                }

                                // fallback: đảm bảo đúng 3 phần tử (nếu Gemini trả ít)
                                if (suggestedQuestions.size() > 3)
                                        suggestedQuestions = suggestedQuestions.subList(0, 3);
                                if (suggestedQuestions.size() < 3) {
                                        // để empty/thiếu thì UI vẫn chạy; không ép thêm.
                                }
                        }
                } catch (Exception e) {
                        log.warn("Không sinh được suggestedQuestions, bỏ qua. cause={}", e.getMessage());
                }

                AIMessage assistantMessage = AIMessage.builder()
                                .conversation(conversation)
                                .role(AIMessage.MessageRole.ASSISTANT)
                                .content(replyText)
                                .wasOutOfScope(false)
                                .build();

                // Luu 2 tin nhan (user + assistant) vao DB trong cung 1 transaction
                // de lich su chat khong bi mat khi server loi giua chung
                conversation.getMessages().add(userMessage);
                conversation.getMessages().add(assistantMessage);
                conversationRepository.save(conversation);

                return SendMessageResponse.builder()
                                .conversationId(conversation.getId())
                                .reply(replyText)
                                .wasOutOfScope(outOfScope)
                                .suggestedQuestions(suggestedQuestions)
                                .build();

        }

        private AIConversation getOrCreateConversation(Long learnerId, SendMessageRequest request, Lesson lesson) {
                // 1. Kiểm tra an toàn: Chỉ tìm kiếm nếu conversationId thực sự tồn tại và hợp
                // lệ (> 0)
                if (request.getConversationId() != null && request.getConversationId() > 0) {
                        try {
                                return conversationRepository
                                                .findByIdAndLearnerIdWithMessages(request.getConversationId(),
                                                                learnerId)
                                                .orElseGet(() -> createNewConversation(learnerId, lesson)); // Fallback:
                                                                                                            // Nếu không
                                                                                                            // thấy ID
                                                                                                            // này, tự
                                                                                                            // tạo mới
                                                                                                            // luôn
                        } catch (Exception e) {
                                log.warn("Lỗi khi truy vấn cuộc hội thoại id={}, tự động fallback tạo cuộc hội thoại mới",
                                                request.getConversationId());
                                return createNewConversation(learnerId, lesson);
                        }
                }

                // 2. Trường hợp mặc định (Id bằng null hoặc bằng 0): Tạo mới cuộc hội thoại
                return createNewConversation(learnerId, lesson);
        }

        // Hàm helper tách biệt để tái sử dụng logic khởi tạo hội thoại mới sạch sẽ hơn
        private AIConversation createNewConversation(Long learnerId, Lesson lesson) {
                User learner = userRepository.findById(learnerId)
                                .orElseThrow(() -> new ApiException("Không tìm thấy người dùng", HttpStatus.NOT_FOUND));

                AIConversation newConversation = AIConversation.builder()
                                .learner(learner)
                                .lesson(lesson)
                                .messages(new java.util.ArrayList<>()) // Khởi tạo danh sách rỗng tránh lỗi NullPointer
                                                                       // sau này
                                .build();

                return conversationRepository.save(newConversation);
        }

        public List<AIConversation> getConversationHistory(Long learnerId) {
                return conversationRepository.findByLearnerIdOrderByStartedAtDesc(learnerId);
        }
}
