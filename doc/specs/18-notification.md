# Feature Specification: FE-18 — Notification

> Ref: [HanGo_Documentation.md](../HanGo_Documentation.md) §7.18 (NTF). Renumbered from `14-notification.md` 2026-08-10.

> ⚠️ **Hiệu chỉnh quan trọng:** hệ thống Notification là **REST/poll-based**, **chưa có WebSocket/STOMP push thật** — comment trong chính code (`NotificationService`) ghi rõ "no realtime/WebSocket delivery yet". Đây khác với mô tả kiến trúc "Realtime WebSocket" ở tài liệu tổng quan trước đây (đã sửa lại ở `HanGo_Documentation.md` §5). Toàn bộ 12 loại notification trung tâm **đều đã có trigger thật** (không còn loại "Planned" nào), cộng 2 loại ad-hoc của Ticket.

## 1. Business Context
Notification giữ chân user bằng cách nhắc các sự kiện quan trọng. Frontend tự fetch danh sách + số chưa đọc khi mở chuông/sau đăng nhập — không có kết nối đẩy liên tục.

## 2. Acceptance Criteria

**Frontend (Flutter):**
- [ ] Chuông thông báo trên `shared_header.dart`/`internal_app_header.dart`, badge đỏ đếm chưa đọc.
- [ ] Bấm chuông mở dropdown danh sách (popup tại chỗ, chưa phải trang riêng).
- [ ] Bấm 1 notification → đánh dấu đã đọc (chưa điều hướng sang trang liên quan — xem Edge Cases).
- [ ] ❌ Chưa có kết nối WebSocket/STOMP thật — chuông chỉ refresh khi mở/sau login.

**Backend (Spring Boot, `NotificationController` base `/api/v1/notifications`, không có `@PreAuthorize`, tự check đăng nhập):**
- [ ] `GET /` — phân trang, gồm cả notification nhắm trực tiếp lẫn broadcast theo role đang giữ.
- [ ] `GET /unread-count`.
- [ ] `PUT /{id}/read`, `PUT /read-all`.
- [ ] `JavaMailSender` (`EmailService`) gửi email độc lập cho: OTP verify, reset password, mua thành công, duyệt Trainer, statement settled — không rớt request chính nếu gửi mail lỗi.

**Trigger wiring hiện tại (12 loại trung tâm + 2 loại ad-hoc của Ticket):**

| Trigger | Nguồn | Người nhận |
|---|---|---|
| `PurchaseSuccess` | `PaymentServiceImpl` (webhook thành công) | Learner đã mua |
| `NewEnrollment` | `PaymentServiceImpl`, `CourseServiceImpl.enrollCourse` (course free) | Trainer tạo Course |
| `CommentReply` | `CommentServiceImpl.addComment` (reply người khác) | Tác giả comment gốc |
| `ContentApproved`/`ContentRejected` | `CourseManagerDashboardServiceImpl` (publish/reject Course hoặc Exam) | Trainer/Course Manager tạo nội dung |
| `CourseUpdated` | `CourseManagerDashboardServiceImpl.publishCourse` (version mới) | Mọi learner đang enroll bản cũ |
| `CourseSubmitted` | `TrainerDashboardServiceImpl.submitTrainerCourse` | Course Manager/Admin |
| `StatementReady` | `MonthlyStatementServiceImpl.generateMonthlyCutoff` | Trainer liên quan |
| `TrainerApplicationSubmitted` | `TrainerOnboardingServiceImpl.submitProfileForReview` | Broadcast `ADMINISTRATOR` |
| `TrainerApplicationReviewed` | `TrainerOnboardingServiceImpl.reviewTrainerProfile` | Trainer nộp đơn |
| `LOW_RATING` | `CourseRatingServiceImpl` (rating ≤3) | Course Manager **và** Administrator |
| `LOW_AVERAGE_RATING` | `CourseRatingServiceImpl` (avg vượt ngưỡng 4.0 xuống) | Course Manager **và** Administrator |
| `TicketCreated`/`TicketReviewed` | `TicketServiceImpl` | Broadcast `ADMINISTRATOR` cho `TicketCreated`, và Trainer/Learner sở hữu ticket cho `TicketReviewed` |

## 3. Technical Constraints
- **Không dùng `ApplicationEventPublisher`** — mỗi service gọi trực tiếp `NotificationService`, khớp behavior thật nhưng khác thiết kế decoupled ban đầu.
- **`type` là `String` tự do**, không phải DB enum — dễ gõ sai chuỗi khi thêm loại mới.

## 4. Edge Cases
- **Course/resource liên kết bị xoá:** notification vẫn trả về (courseId/courseTitle null trong DTO) — Frontend chưa điều hướng khi click nên không gặp lỗi 404, chỉ đơn thuần chưa có trang đích.
- **Notification broadcast theo role** (vd `LOW_RATING`): mỗi user nhận **1 dòng riêng** (materialize lúc tạo) — trạng thái đã đọc độc lập theo từng người, không dùng chung 1 dòng như thiết kế cũ mô tả.
- **`TicketCreated` gửi theo role `TRAINER_LEAD`:** không map user thật nào — cần dev sửa thành `COURSE_MANAGER` để thông báo thực sự tới nơi (xem [16-ticket-management.md](16-ticket-management.md)).

## 5. Non-functional Requirements
- **Performance:** danh sách/unread-count có phân trang để bound response khi khối lượng notification tăng.
- **Async:** gửi email hiện chạy đồng bộ trong try/catch tại điểm gọi (không rớt request chính khi mail lỗi), chưa chuyển hẳn sang thread pool riêng.
