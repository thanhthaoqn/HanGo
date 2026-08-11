# Feature Specification: FE-10 — Exam Matrix Management

> Ref: [HanGo_Documentation.md](../HanGo_Documentation.md) §7.10 (MTX). Module mới hoàn toàn trong Feature Map 19-module (2026-08-10) — trước đây gộp chung vào Exam Management, giờ tách riêng vì có UI/API/data model đủ độc lập.

## 1. Business Context
Exam Matrix là **blueprint tái sử dụng** để sinh Exam tự động: 1 tiêu đề/mô tả + danh sách luật (`skill × difficulty × group-type (tuỳ chọn) × category (tuỳ chọn) × số lượng câu`). Khi generate, hệ thống lấy mẫu câu hỏi khớp luật từ Question Bank để dựng thành 1 Exam mới. Trainer chỉ dùng được matrix `Public`; Course Manager tạo/sửa/xem mọi matrix (kể cả Private) và bật/tắt Public.

## 2. Acceptance Criteria

**Frontend (Flutter, `course_manager/`):**
- [ ] `course_manager_matrix_management_page.dart` — danh sách, tìm kiếm, filter Public/Private (Course Manager); Trainer chỉ thấy matrix Public.
- [ ] `course_manager_matrix_builder_page.dart` — tạo/sửa/xem (`MatrixMode`: create/view/edit): tiêu đề/mô tả + danh sách luật động (skill/difficulty/group-type/số lượng, lấy từ `SystemParameter`).
- [ ] `course_manager_exam_matrix_page.dart` — picker chọn 1 matrix có sẵn khi đang tạo Exam (dùng trong `CourseManagerCreateExamPage`, cả Trainer lẫn Course Manager mode).

**Backend (Spring Boot, service dùng chung `CourseManagerExamMatrixService`):**
- [ ] `TrainerExamMatrixController` (`/api/v1/trainer/matrices`) — `GET` list (**chỉ** matrix `isPublic=true`), `POST /{id}/generate`, `GET /count-available`.
- [ ] `CourseManagerExamMatrixController` (`/api/v1/course-manager/matrices`) — `GET` list (**mọi** matrix), CRUD, `PUT /{id}/toggle-public`, `PUT /{id}/edit`, `POST /{id}/generate`.
- [ ] Generate: tổng `quantity` các luật = số câu mặc định (ghi đè được), tạo `Exam` mới `status=DRAFT`, `visibility=PRIVATE`.

## 3. Technical Constraints
- **1 service, 2 controller:** không có `TrainerExamMatrixService` riêng — cả 2 controller cùng gọi `CourseManagerExamMatrixService`, chỉ khác ở API/quyền truy cập.
- **Mọi matrix hiện tạo ra đều `isPublic=true` (hardcode ở lúc tạo)** — cờ Private/Public trong data model tồn tại nhưng chưa có luồng tạo nào thật sự đặt `isPublic=false` ngoài API `toggle-public` riêng của Course Manager sau khi đã tạo.
- **1 route trong `TrainerExamMatrixController` (`count-available`) siết chặt hơn 2 route còn lại của cùng controller** — yêu cầu permission `CREATE_AND_MANAGE_EXAMS_CM` thay vì chấp nhận cả `MANAGE_OWN_COURSES` như 2 route kia; cần biết trước khi debug "sao Trainer gọi được list nhưng không gọi được count-available".

## 4. Edge Cases
- **Tổng `quantity` các luật vượt quá số câu thật có trong Question Bank khớp điều kiện:** hành vi generate khi không đủ câu khớp luật chưa được xác nhận độc lập trong đợt audit này — cần test riêng trước khi coi tính năng này là hoàn thiện.
- **Xoá/sửa 1 matrix đã từng được dùng để generate Exam:** Exam đã tạo ra trước đó không có liên kết ngược nào bị ảnh hưởng (Exam là bản ghi độc lập sau khi generate).

## 5. Non-functional Requirements
- **Reusability:** mục tiêu chính của module là giảm công sức tạo Exam lặp lại cùng 1 cấu trúc câu hỏi — không có yêu cầu hiệu năng đặc biệt ngoài các API CRUD thông thường.
