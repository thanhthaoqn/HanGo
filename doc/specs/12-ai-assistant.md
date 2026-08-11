# Feature Specification: FE-12 — AI Assistant

> Ref: [HanGo_Documentation.md](../HanGo_Documentation.md) §7.12 (AI). Pathway-level mentor chat/recommendation is a separate module — see [11-ai-recommendation.md](11-ai-recommendation.md) (FE-11). Renumbered from `09-ai-assistant.md` 2026-08-10.

> ⚠️ **Kiến trúc thật chi tiết hơn thiết kế ban đầu.** Nhà cung cấp AI thật là **Google Gemini** (`GeminiClientService`, model chat `gemini-3.1-flash-lite`), không phải "OpenAI GPT-4 hoặc Gemini" chung chung. Class thật là `AIAssistantService`, entity thật là `AIConversation`/`AIMessage`. Có 3 lớp guardrail thật (xem §3) — **lớp 3 (embedding similarity) hiện gần như no-op** vì ngưỡng `scopeSimilarityThreshold` không được set ở file config nào tìm thấy trong repo (mặc định Java `double` = `0.0`).

## 1. Business Context
AI Assistant là chat trong lúc học **1 Lesson cụ thể** — giải thích khái niệm/câu hỏi/đáp án, trả lời câu hỏi liên quan tới bài học. Mọi cuộc hội thoại **bắt buộc** gắn với 1 `lessonId` — không có chat "chung chung" ngoài phạm vi Lesson (khác với AI Mentor Chat ở module Pathway, vốn nói về lộ trình học chứ không trả lời câu hỏi học thuật).

## 2. Acceptance Criteria

**Frontend (Flutter):**
- [ ] `lesson_ai_chatbox.dart` — panel chat nhúng trong `lesson_detail_page.dart` (không phải bubble nổi toàn app).
- [ ] `lesson_ai_chatbox_empty_state.dart` + `lesson_ai_chatbox_default_questions.dart` — gợi ý câu hỏi mở đầu khi chưa có hội thoại.
- [ ] `lesson_ai_chatbox_quick_questions.dart` — hàng chip gợi ý 3 câu hỏi tiếp theo sau mỗi câu trả lời.
- [ ] Loading indicator trong lúc chờ AI trả lời; render Markdown cho câu trả lời dài.

**Backend (Spring Boot, `AIAssistantController` base `/api/v1/ai-assistant`):**
- [ ] `POST /messages` (gate `hasAuthority('AI_LEARNING_ASSISTANT')`) — nhận `message` + `lessonId`.
- [ ] `GET /conversations` (cùng gate) — lịch sử hội thoại.
- [ ] `GET /status` (public) — health check Gemini, phục vụ `checkAiStatus`.
- [ ] `AIAssistantService.sendMessage`: pull câu hỏi luyện tập của Lesson vào prompt, dựng full lịch sử chat từ `AIMessage` chưa bị chặn, gọi Gemini 2 lần (trả lời chính + sinh 3 câu hỏi gợi ý tiếp theo).

## 3. Technical Constraints
- **3 lớp guardrail:** (1) system prompt (`AIPromptBuilder`) yêu cầu từ chối lịch sự câu hỏi ngoài phạm vi; (2) bắt buộc gắn `lessonId` hợp lệ; (3) so khớp embedding similarity (`ScopeGuardrailService`, ngưỡng `hango.ai-assistant.scope-similarity-threshold`) — **hiện chưa được cấu hình ở đâu trong repo**, cần xác nhận với đội vận hành có set qua biến môi trường ngoài repo hay không trước khi coi lớp này đang hoạt động đúng thiết kế.
- **`LessonEmbeddingService` (cache embedding Lesson) có code đầy đủ nhưng không được gọi ở đâu** — `ScopeGuardrailService` tính lại embedding qua Gemini **mỗi lần** có tin nhắn mới, không cache như comment code của chính nó mô tả.
- **Timeout:** 15s (`hango.gemini.timeout-seconds`), retry 2 lần khi Gemini trả 429.
- **`AIAssistantProperties.maxPromptLength` khai báo nhưng không được enforce ở đâu cả** — chưa có giới hạn độ dài prompt thật.

## 4. Edge Cases
- **Gemini lỗi/quá hạn mức:** trả fallback message thân thiện, không để lộ lỗi kỹ thuật.
- **Câu hỏi dưới 8 ký tự:** tự động qua guardrail lớp 3 mà không cần tính embedding (short-circuit).
- **Prompt injection ("bỏ qua hướng dẫn trước đó..."):** system prompt có chỉ dẫn từ chối rõ ràng — chưa có test tự động xác nhận độ hiệu quả.
- **Usage volume:** v1 **không** có rate-limit/quota cứng theo user (chỉ có retry-backoff khi Gemini 429) — mọi lượt gọi vẫn được log qua `AiUsageLog` để phục vụ giám sát, không phải để giới hạn.

## 5. Non-functional Requirements
- **Content Security:** không nhúng PII của user vào prompt gửi Gemini.
- **Experience:** câu trả lời dài render Markdown ở Flutter (`flutter_markdown`).
