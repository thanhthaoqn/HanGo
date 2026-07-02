# TODO - FT-15 (AI Interactive Learning Pathway) - AI Mentor Vietnamese

## Mục tiêu
- Chuẩn hóa phần AI Mentor trong Learning Roadmap về **toàn bộ tiếng Việt**.
- Sửa logic để **AI Mentor không trả lời vượt phạm vi**, hoạt động đúng trong learning roadmap (không “chat tự do”).
- Bảo đảm response có cơ chế `wasOutOfScope` đồng bộ frontend.

## Các phần cần làm tiếp
- [ ] 1) Xác định toàn bộ prompt đang còn tiếng Anh ở phần AI Mentor của learning pathway (backend).
- [ ] 2) Chuẩn hóa `systemPrompt` cho hàm chat mentor trong `LearningPathwayService.chatWithMentor(...)` sang tiếng Việt hoàn toàn.
- [ ] 3) Thay `generateChatResponse` trong `LearningPathwayService.chatWithMentor` để dùng guardrail giống `AIAssistantService`:
  - [ ] 3.1 Bắt buộc conversation gắn với `Lesson` (hoặc tạo cơ chế scope theo course/node) thay vì chat tự do.
  - [ ] 3.2 Tạo embedding similarity guardrail cho câu hỏi ngoài phạm vi roadmap (node tree) hoặc ít nhất theo course hiện tại.
  - [ ] 3.3 Bổ sung fallback `wasOutOfScope=true` thay vì chỉ “prompt bảo không vượt scope”.
- [ ] 4) Tạo/điều chỉnh DTO/Response endpoint để trả về `wasOutOfScope` (nếu endpoint phía FE đang cần).
- [ ] 5) Kiểm tra frontend AI chatbox (nếu có) để render label/chế độ từ chối khi `wasOutOfScope=true`.
- [ ] 6) Cập nhật unit test:
  - [ ] Thêm test cho `chatWithMentor`/endpoint đảm bảo prompt tiếng Việt + không trả lời ngoài phạm vi.
- [ ] 7) Chạy build & tests backend + chạy flutter analyze (nếu có thay FE).

- [ ] 8) (Tool) Tạo Service parse/chuẩn hóa “lỗ hổng kiến thức” từ `ExamAttempt.answersJson` để AI Mentor/Agent có đầu vào đúng.
  - [ ] 8.1 Tạo thêm `ExamResultAnalyzerService` (hoặc tương tự) làm “tool” cho roadmap.
- [ ] 8.2 Tích hợp tool vào `LearningPathwayService.generatePathway(...)` để AI phân tích “lỗ hổng kiến thức” dựa trên `ExamAttempt.answersJson` và nhúng vào prompt.

- [ ] 9) Xác nhận AI đã phân tích dữ liệu của bài làm gần nhất (latest examAttempt) trước khi gọi Gemini:
  - [ ] Đảm bảo luồng `generatePathway` dùng đúng `examAttemptId` truyền vào.
  - [ ] Nhúng kết quả `ExamResultAnalysisDTO` vào system prompt (mentor_summary/nodes lý do...).



