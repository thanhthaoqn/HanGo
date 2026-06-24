# TODO - HanGo AI assistant: đọc được practice exercise data

- [ ] Bước 1: Tìm entity/repository/DTO chứa “practice exercise data” (quiz/task/question) theo lesson.
- [ ] Bước 2: Đọc schema hiện tại (entity + field nào liên quan lessonId/examId/section).
- [ ] Bước 3: Thiết kế payload context cho AI: đề bài + dữ kiện cần thiết (đáp án/giải thích nếu có).
- [ ] Bước 4: Mở rộng `AIPromptBuilder` để nhúng practice data vào system prompt (hoặc prompt engineering cho từng practice).
- [ ] Bước 5: Mở rộng guardrail embedding similarity để tính scope theo (lý thuyết + practice) thay vì chỉ lý thuyết.
- [ ] Bước 6: Sửa `AIAssistantService.sendMessage()` để load practice data theo request.lessonId và truyền vào prompt/guardrail.
- [ ] Bước 7: Chạy build/test backend và thử nghiệm chat với câu hỏi thuộc phần practice.

