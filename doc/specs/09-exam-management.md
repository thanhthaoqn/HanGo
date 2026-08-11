# Feature Specification: FE-09 — Exam Management

> Ref: [HanGo_Documentation.md](../HanGo_Documentation.md) §7.9 (EXM). Exam Matrix (blueprint sinh Exam) is a separate module — see [10-exam-matrix-management.md](10-exam-matrix-management.md) (FE-10). Renumbered from `08-exam-management.md` 2026-08-10.

> ⚠️ **Hiệu chỉnh quan trọng so với thiết kế trước:** **không có** hằng số "40 câu/50 phút/thang 10" áp dụng cho mọi Exam. `Exam.durationMinutes`/`expectedQuestionCount`/`passingScore` hoàn toàn tự do, do Trainer/Course Manager/Exam Matrix quyết định per-Exam. Con số 40/50/10 chỉ đúng cho **1 Exam duy nhất seed sẵn** (`EntryExamDataInitializer`, id=999, "Global Entry Placement Test") — dùng làm bài kiểm tra đầu vào sinh Learning Pathway lần đầu, không phải khuôn mẫu bắt buộc.

## 1. Business Context
Exam độc lập với Course, được tạo bởi **Trainer hoặc Course Manager**; Exam Question soạn **riêng** cho Exam, không dùng chung/tái sử dụng với Question Bank của Quiz. Không có pass/fail threshold — chỉ có điểm số (0–10). Learner làm bài có đếm giờ + auto-submit khi hết giờ, làm lại không giới hạn.

## 2. Acceptance Criteria

**Frontend (Flutter):**
- [ ] `list_exams_page.dart` — catalog, filter type/duration/status.
- [ ] Trainer/Course Manager: `course_manager_create_exam_page.dart` (4 cách tạo: thủ công/Excel/AI-chat/từ Exam Matrix), `course_manager_edit_exam_page.dart`, `course_manager_exams_page.dart` (queue theo status).
- [ ] `entry_exam_instruction_page.dart` → `take_exam_page.dart` (đếm giờ đồng bộ server, câu hỏi nhóm theo passage).
- [ ] `exam_result_page.dart` — điểm, phân tích theo skill, AI weakness summary + gợi ý Course.
- [ ] `exam_review_page.dart` — xem lại từng câu (đáp án đã chọn vs đáp án đúng).
- [ ] `exam_detail_history_page.dart` — lịch sử các lần làm.

**Backend (Spring Boot):**
- [ ] `GET /api/v1/exams` (public), `GET /{id}/questions` (không có `isCorrect`, an toàn cho Learner).
- [ ] `POST /trainer/exams`, `PUT /trainer/exams/{id}` — tạo/sửa cấu trúc.
- [ ] `POST /trainer/exams/import-excel-multiple` — dùng **Apache POI thật**.
- [ ] `TrainerQuestionAIController /exams/chat`, `/exams/generate-from-chat` — AI-generate.
- [ ] `POST /exams/{id}/submit` — chấm điểm **server-side** dựa `QuestionOption.isCorrect`, không tin điểm client, 0.25đ/câu, thang 10.
- [ ] `GET /exams/my-attempts`, `GET /exams/{id}/attempts` — lịch sử attempt.
- [ ] `POST /course-manager/exams/{id}/publish`\|`reject` — luồng duyệt duy nhất (không có "legacy self-publish" riêng như Course).

## 3. Technical Constraints
- **Exam Question privacy:** không lẫn với Question Bank chung của Quiz.
- **Frontend Security:** timer tính theo start-time server, không tin đồng hồ client.
- **`returnExamToDraft` không đưa về Draft:** dù tên method gợi ý "về Draft", hành vi thật là set status `REJECTED`.

## 4. Edge Cases
- **Mất kết nối giữa lúc làm bài:** cache câu trả lời local, đồng bộ/nộp khi có mạng lại.
- **Hết giờ auto-submit:** client phải tự gọi API submit ngay khi timer về 0.
- **Nộp bài 2 lần cho cùng 1 lượt:** cần khoá tránh double-submit (chưa xác nhận độc lập cơ chế chặn cụ thể trong đợt audit này).

## 5. Non-functional Requirements
- **Security:** không lộ đáp án đúng trong response khi Exam attempt đang `IN_PROGRESS`.
