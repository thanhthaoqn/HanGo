# Feature Specification: FE-08 — Question Bank Management

> Ref: [HanGo_Documentation.md](../HanGo_Documentation.md) §7.8 (QB). Renumbered from `07-question-bank-management.md` 2026-08-10.

> ⚠️ **Lỗ hổng mới phát hiện 2026-08-10 (chưa từng được ghi nhận ở báo cáo trước):** `TrainerQuestionAIController` (3 endpoint AI-generate câu hỏi/đề thi) **không có `@PreAuthorize` nào**, và `TrainerQuestionAIService` phía sau cũng không tự kiểm tra role — bất kỳ user đã đăng nhập nào (kể cả Learner) hiện gọi được tính năng AI-generate của Trainer/Course Manager. Xem `HanGo_Documentation.md` §22.

## 1. Business Context
Kho câu hỏi tái sử dụng, sở hữu bởi từng Trainer (Course Manager dùng chung được nhờ có permission `CREATE_AND_MANAGE_EXAMS_CM`), phục vụ Quiz (Course Content) và làm nguồn cho Exam Matrix. v1 hỗ trợ **đúng 1 QuestionType: SingleChoice** (4 lựa chọn A/B/C/D, đúng 1 đáp án đúng). Mỗi Question có **đúng 1** SkillType/category. QuestionGroup cho phép nhiều câu dùng chung 1 passage.

## 2. Acceptance Criteria

**Frontend (Flutter, `course_manager/question_bank/` — dùng chung cho cả Trainer qua `isCourseManager: false`):**
- [ ] `question_search_bar.dart`/`question_filter_pane.dart` — search + filter theo skill/group-type/difficulty.
- [ ] `question_table.dart` — bảng phân trang, view/edit/toggle-status.
- [ ] `course_manager_create_question_page.dart` — tạo/sửa 1 câu hoặc 1 QuestionGroup (passage + câu con), có nút "AI-assist".
- [ ] Import/Export Excel.

**Backend (Spring Boot, `TrainerQuestionController` base `/api/v1/trainer/question-bank`):**
- [ ] `GET /` (filter type/search/skill/category/difficulty/sort), `GET /detail/{id}`.
- [ ] `POST /` (tạo group question), `PUT /{id}`, `PATCH /{id}/status`.
- [ ] `GET /import-excel/template`.
- [ ] `TrainerQuestionAIController /generate` (AI-generate câu hỏi, ⚠️ xem cảnh báo đầu file).

## 3. Technical Constraints
- **CRUD group/sub-question dùng `JdbcTemplate`** (raw SQL có tham số hoá, không phải thuần JPA) — vẫn an toàn khỏi SQL injection nhưng khác cách triển khai CRUD chung của dự án.
- **Deleting a Question đang được dùng:** ưu tiên đổi status (soft) thay vì xoá cứng nếu đang gắn vào Quiz/Exam Matrix đang hoạt động — chưa xác nhận độc lập server có tự chặn hard-delete hay không trong đợt audit này.

## 4. Edge Cases
- **Option thiếu đáp án đúng:** validate tối thiểu 1 option `is_correct=true`.
- **AI-generate bị gọi bởi role không phải Trainer/Course Manager (do thiếu `@PreAuthorize`):** hiện **không bị chặn** — Learner gọi thẳng API vẫn dùng được tính năng AI-generate. Cần Product/Security xác nhận có chấp nhận rủi ro này tạm thời hay ưu tiên vá trước.

## 5. Non-functional Requirements
- **Security:** guard XXE khi import Excel bằng Apache POI.
