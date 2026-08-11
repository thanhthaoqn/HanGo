# Feature Specification: FE-17 — Comment Management

> Ref: [HanGo_Documentation.md](../HanGo_Documentation.md) §7.17 (CMT). Renumbered from `13-comment-management.md` 2026-08-10; content largely carried over (already well-verified against code) with one new permission-mismatch flag.

## 1. Business Context
Comment System cho Learner và Trainer hỏi/thảo luận trực tiếp dưới **Lesson hoặc Quiz** (không ở cấp Course — Course chỉ có Rating). **Không có AI moderation** ở v1 — mỗi comment đi qua **Rule Engine**: normalize text + blacklist keyword + suspicious keyword (riêng, nhẹ hơn) + regex pattern, tự gán status mà không cần người/AI phán đoán tại thời điểm đăng. Admin chỉ review những gì Rule Engine gắn cờ `PENDING`.

## 2. Comment Workflow

1. **Normalize** (`CommentRuleEngineService.normalize`): lowercase → bỏ dấu tiếng Việt (NFD + `đ`→`d`) → gộp khoảng trắng → thay thế ký tự né lọc (`0/@`→`o`, `1`→`i`, `3`→`e`, `4`→`a`, `5/$`→`s`, `7`→`t`).
2. **Check blacklist keyword** (khớp nguyên từ trên text đã normalize) **và** **suspicious keyword riêng** (nhẹ hơn, ví dụ "ngu", "dot") **và regex pattern** (số điện thoại/URL/email/mời liên hệ ngoài nền tảng, kiểm tra trên text gốc đã gộp khoảng trắng vì cần giữ số/ký tự đặc biệt).
3. **Quyết định status:**
   - Không khớp gì → **`APPROVED`** → hiển thị ngay.
   - Khớp suspicious keyword **hoặc** regex pattern (nghi vấn, chưa chắc vi phạm) → **`PENDING`** → ẩn với người khác, tác giả vẫn thấy, chờ Admin duyệt.
   - Khớp blacklist keyword (vi phạm) → **`REJECTED`** → ẩn hoàn toàn **kể cả với tác giả**, không có ngoại lệ.
4. Đánh giá lại **cả lúc tạo lẫn lúc sửa** — sửa lại nội dung chạy lại Rule Engine (có thể đổi status theo cả 2 chiều: đang `REJECTED` sửa sạch → tự về `APPROVED`).

**Status values:** `APPROVED` · `PENDING` · `REJECTED`.

## 3. Acceptance Criteria

**Frontend (Flutter):**
- [ ] Comment thread dưới Lesson/Quiz (`lesson_detail_page.dart`), nested Root → Reply, like/unlike.
- [ ] Toast phản hồi khi đăng: im lặng cho `APPROVED`, thông báo trung tính ("đang chờ duyệt, chỉ bạn thấy") cho `PENDING`, thông báo lỗi ("vi phạm cộng đồng") cho `REJECTED`.
- [ ] `comment_management_page.dart` (Admin): tab Lesson/Quiz, search, filter status, bảng + View Detail + Delete + Approve/Reject nhanh qua status chip.
- [ ] Comment Detail dialog: nội dung gốc, nội dung đã normalize, lý do bị gắn cờ, status, người tạo, thời gian.

**Backend (Spring Boot):**
- [ ] `POST /api/v1/comments/lesson/{lessonId}` — root hoặc reply (`parentCommentId`), chạy Rule Engine, lưu `status`+`normalizedContent`+`detectionReason`.
- [ ] `GET /api/v1/comments/lesson/{lessonId}` — trả `APPROVED` cho mọi người + `PENDING`/`REJECTED` của chính người gọi.
- [ ] `PUT /{id}` (sửa), `DELETE /{id}` (xoá) — chỉ chủ comment.
- [ ] `GET /api/admin/comments`, `GET /api/admin/comments/{id}`, `PUT /{id}/status`, `DELETE /{id}` — Admin moderate.

## 4. Technical Constraints
- **Rule Engine hardcode có chủ đích** (blacklist/suspicious/regex là hằng số Java, không phải bảng cấu hình được qua UI) — nếu team muốn Admin tự sửa danh sách từ khoá, đây là việc làm thêm, không phải v1.
- **⚠️ `AdminCommentController` kiểm tra permission `MANAGE_ACCOUNTS_ROLES`, không phải `MODERATE_COMMENTS`** — permission `MODERATE_COMMENTS` được `RolePermissionDataInitializer` seed đúng cho mục đích này nhưng không được endpoint nào đọc tới trong lần audit này. Chưa gây vấn đề thực tế vì Admin đang có cả hai permission, nhưng sẽ lệch nếu Admin dùng "Configure Permission" ([04-role-permission-management.md](04-role-permission-management.md)) để tách quyền sau này.
- **XSS Prevention:** cần escape/sanitize nội dung trước khi lưu — **chưa xác nhận đã implement đầy đủ** trong đợt audit này, cần kiểm tra lại riêng trước khi coi là an toàn.

## 5. Edge Cases
- **Comment gốc bị xoá còn reply:** hiện xoá cứng (hard delete) — reply mồ côi (`parentCommentId` trỏ tới bản ghi không còn tồn tại) chưa có cơ chế hiển thị "bình luận đã bị xoá" thay thế.
- **Sửa lại comment đang `REJECTED` cho sạch:** tự chuyển lại `APPROVED` ngay khi Rule Engine chạy lại, không cần bước "resubmit" riêng.
- **Vấn đề bỏ dấu gây trùng từ (đánh đổi có chủ đích, không phải bug):** ví dụ `cặc` (tục) và `các` (từ rất phổ biến) đều normalize về `cac`; `lồn` (tục) và `lon` ("cái lon") đều về `lon`. Blacklist cố tình **loại** `cac` (tỷ lệ false-positive quá cao) nhưng **giữ** `lon`/`deo` — nếu Admin báo nhiều trường hợp `REJECTED`/`PENDING` sai, hướng xử lý là tỉa từ khoá cụ thể, không phải đổi cách bỏ dấu.

## 6. Non-functional Requirements
- **Performance:** tải comment thread cần phản hồi nhanh (chưa có SLA đo lường cụ thể trong đợt audit này).
