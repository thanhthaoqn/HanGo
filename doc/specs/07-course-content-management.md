# Feature Specification: FE-07 — Course Content Management

> Ref: [HanGo_Documentation.md](../HanGo_Documentation.md) §7.7 (CNT). Course **metadata**/review-publish workflow lives in [06-course-management.md](06-course-management.md) (FE-06). Renumbered from `06-course-content-management.md` 2026-08-10.

> ⚠️ **Lỗ hổng cần biết trước khi thêm tính năng mới:** `SectionQuestionController` (toàn bộ 8 endpoint CRUD Section/Question ở module này) **không có `@PreAuthorize` nào** — bất kỳ role đã đăng nhập nào (kể cả Learner) hiện gọi được, tạo/sửa được nội dung của Trainer khác. Xem `HanGo_Documentation.md` §22 CRIT.

## 1. Business Context
Sau khi có 1 version Course, Trainer soạn cấu trúc & nội dung, sở hữu độc quyền (chỉ owner sửa được): quản lý **Section** (tạo/sửa/xoá/sắp xếp — thực hiện qua payload lồng nhau khi tạo/sửa Course, không có `SectionController` riêng), quản lý **Lesson** trong Section (nội dung text-first, `Lesson.content` LONGTEXT, có thể gắn resource video/pdf/image qua Cloudinary), và **Quiz** gắn vào Lesson — chọn câu hỏi có sẵn từ Question Bank hoặc AI-generate. Không có entity `LessonBlock`/`Quiz` tách riêng như thiết kế ban đầu — Quiz thực chất là câu hỏi gắn qua field `exam` (optional) trên `Lesson`.

## 2. Acceptance Criteria

**Frontend (Flutter):**
- [ ] `create_section_page.dart` — CRUD + sắp xếp Section, `lesson_list_widget.dart` per-Section.
- [ ] `create_lesson_page.dart` (chọn loại: text/video/quiz) → `create_lesson_text_page.dart`/`create_lesson_video_page.dart`.
- [ ] `create_quiz_page.dart` (metadata quiz) → `select_quiz_questions_page.dart` (chọn từ Question Bank) hoặc `add_new_question_page.dart`/`add_multiple_choice_question_page.dart` (tạo mới thủ công/AI).
- [ ] File picker cho Video/PDF/Image, hiện progress bar.
- [ ] "Import from Excel": tải template, upload, báo cáo kết quả từng dòng.

**Backend (Spring Boot, `SectionQuestionController` base `/api/v1/trainer`):**
- [ ] `GET /courses/{courseId}/sections`, `GET /sections/{sectionId}/questions`, `GET /lessons/{lessonId}/questions`.
- [ ] `GET /sections/{sectionId}/questions/select` — chọn câu hỏi có sẵn để gắn vào Quiz.
- [ ] `POST /lessons/{lessonId}/questions`, `POST /questions`, `PUT /questions/{id}`, `POST /questions/group`.
- [ ] AI generate Quiz-question: `TrainerQuestionAIController` (dùng chung engine với Question Bank, [08-question-bank-management.md](08-question-bank-management.md)).
- [ ] Upload media Lesson lên Cloudinary, DB chỉ lưu URL.

## 3. Technical Constraints
- **⚠️ Không có `@PreAuthorize`:** cả 8 endpoint của `SectionQuestionController` (xem cảnh báo đầu file) — biết trước khi thiết kế test case, không mặc định hệ thống đã chặn theo role.
- **Security khác:** guard MIME type media upload (chỉ `.mp4`/`.pdf`/ảnh hợp lệ).
- **Frontend Reordering:** cập nhật local state trước, đồng bộ `order_index` lên server sau.

## 4. Edge Cases
- **Mất kết nối giữa chừng khi upload:** cần nút Retry, không mất nội dung Lesson đã nhập.
- **Excel import thiếu field bắt buộc / trỏ tới Question Bank ID không tồn tại:** báo lỗi theo dòng.
- **Reorder gửi mảng ID không đầy đủ/trùng lặp:** cần từ chối để bảo toàn dữ liệu.

## 5. Non-functional Requirements
- **Scalability:** đẩy toàn bộ media lên Cloudinary giữ app server stateless về file storage.
