# Feature Specification: FE-06 — Course Management

> Ref: [HanGo_Documentation.md](../HanGo_Documentation.md) §7.6 (CRS), §9.3 (versioning). Section/Lesson/Quiz **content** authoring is [07-course-content-management.md](07-course-content-management.md) (FE-07). Renumbered from `05-course-management.md` 2026-08-10.

> ⚠️ **Cập nhật 2026-08-10 — điểm quan trọng nhất của module này:** có **2 đường độc lập** dẫn tới `PUBLISHED`: (1) luồng chuẩn Submit → Course Manager Review → Publish, và (2) `TrainerDashboardServiceImpl.publishTrainerCourse` — endpoint riêng của Trainer, comment code ghi "Legacy direct publish", **không có điều kiện tiên quyết nào** ngoài Trainer phải `VERIFIED`, cho phép tự publish thẳng bỏ qua review. Course Manager `reject` set status **`REJECTED`**, không phải quay về `DRAFT` như thiết kế trước mô tả (không có method `returnCourseToDraft` cho Course trong code hiện tại).

## 1. Business Context
Course Management gồm discovery (browse/search/filter), Trainer authoring **metadata** (title, description, thumbnail, 1–3 category/SkillType), và luồng review/publish do Course Manager quản lý (trừ trường hợp Course Manager/Admin tự tạo → tự publish ngay). Backend **tự tính** giá gợi ý theo công thức cộng dồn (§3.3 tài liệu chính); Trainer chốt giá cuối. Course Manager review **chỉ trình bày** (template, cấu trúc, chính sách) — không đánh giá chuyên môn; cần đổi nội dung → Reject, không tự sửa. Sửa Course đã Published tạo **version mới** (row `Course` mới, `parentId` trỏ về bản cũ) phải qua lại Submit → Review; bản live giữ nguyên phục vụ Learner cho tới khi bản mới Published.

## 2. Acceptance Criteria

**Frontend (Flutter):**
- [ ] `list_courses_page.dart` — discovery: search/filter (type/difficulty/rating/giá).
- [ ] `course_detail_page.dart` — chi tiết, tab review, banner chuyển version.
- [ ] `create_course_page.dart`/`edit_course_page.dart` — metadata + chọn 1–3 category, giá gợi ý (sửa được).
- [ ] "Submit for Review"; badge trạng thái (Draft/Pending Approval/Rejected/Published/Archived/Hidden).
- [ ] `TrainerActionRequiredCard` — banner hiện lý do Reject trên trang edit khi Course đang `REJECTED`.
- [ ] Course Manager: `course_manager_courses_page.dart` (queue), `course_review_dashboard_dialog.dart` (duyệt từng Lesson trước khi Approve/Reject/Hide/Unhide).
- [ ] Import Course hàng loạt từ Excel + tải template.

**Backend (Spring Boot):**
- [ ] `GET /api/v1/courses` (public, pagination + filter), `GET /{id}`.
- [ ] `POST /trainer/courses`, `PUT /trainer/courses/{id}` (metadata) — Trainer/Course Manager.
- [ ] `POST /trainer/courses/{id}/submit` — auto-publish nếu submitter là Course Manager/Admin, ngược lại → `PENDING_APPROVAL`.
- [ ] `POST /trainer/courses/{id}/publish` — đường "legacy self-publish" của Trainer (`VERIFIED` mới dùng được, không cần `PENDING_APPROVAL`).
- [ ] `POST /trainer/courses/{id}/re-evaluate-price`.
- [ ] `POST /course-manager/courses/{id}/publish`\|`reject`\|`hide`\|`unhide` — luồng review chuẩn.
- [ ] `POST /courses/{id}/import` — parse `.xlsx` bằng **XML tự viết** (không dùng Apache POI dù có dependency), tạo Section/Lesson trong 1 transaction.

## 3. Technical Constraints
- **Không có bảng version riêng:** `Course.parentId`/`Course.latestVersionId` là plain `Long`, không phải JPA relation — versioning dựa convention ở tầng Service, không được Hibernate tự join.
- **SkillType cap:** validate 1–3 category ở `TrainerDashboardServiceImpl.resolveCategories` (không đủ 1 hoặc quá 3 → lỗi).
- **`Course.status` có 6 giá trị:** `DRAFT`/`PENDING_APPROVAL`/`PUBLISHED`/`REJECTED`/`ARCHIVED`/`HIDDEN`.

## 4. Edge Cases
- **Double Submit:** disable nút trong lúc gọi API để tránh spam-click.
- **Sửa Course khi Learner đang học bản cũ:** Learner tiếp tục thấy bản Published cũ không gián đoạn cho tới khi bản mới Published.
- **Course chưa có Section/Lesson nào mà vẫn Submit được:** chưa xác nhận có validate "phải có ít nhất 1 Section/Lesson" ở server trong đợt audit này — cần kiểm tra lại trước khi coi đây là đã chặn.
- **Trainer dùng "legacy publish" bỏ qua review:** đúng hành vi thiết kế hiện tại (không phải bug), nhưng cần Course Manager/QA biết để không hiểu nhầm mọi Course Published đều đã qua review.

## 5. Non-functional Requirements
- **Data Integrity:** Course/Section/Lesson luôn map qua DTO ra client, không trả `@Entity` trực tiếp.
