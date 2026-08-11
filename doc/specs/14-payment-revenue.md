# Feature Specification: FE-14 — Payment and Revenue

> Ref: [HanGo_Documentation.md](../HanGo_Documentation.md) §7.14 (PAY). Cart is a separate module — see [15-cart-management.md](15-cart-management.md) (FE-15). Renumbered from `12-payment-revenue.md` 2026-08-10.

## 1. Business Context
HanGo dùng **PayOS** (thay VNPay ở thiết kế ban đầu — vẫn còn vài tên field/comment "vnpay" sót lại, không ảnh hưởng hành vi). Learner checkout từ Cart → Payment → auto-enroll. Doanh thu chia theo TrainerType (`PROFESSIONAL` 70/30, `PEER_TUTOR` 60/40), có trừ thêm **10% thuế TNCN** nếu tổng thu nhập gộp trong kỳ ≥2 triệu VND (Khoản 1 Điều 25 Thông tư 111/2013/TT-BTC). Pay-in tự động; payout (chuyển tiền cho Trainer) vẫn thủ công, ghi nhận bởi Course Manager/Admin.

## 2. Acceptance Criteria

**Frontend (Flutter):**
- [ ] `payment_qr_dialog.dart` — QR PayOS, đếm ngược 15 phút, poll trạng thái.
- [ ] `learner_shell_page.dart` xử lý redirect thành công/thất bại từ PayOS.
- [ ] `trainer_revenue_page.dart` — balance khả dụng/đang giữ/đã trả + lịch sử statement, nút Confirm/Reject statement.
- [ ] `course_manager_settlement_page.dart` — 2 tab: Statements (filter kỳ/status, export) + Payments Log (toàn bộ giao dịch, filter status/settlementStatus).

**Backend (Spring Boot):**
- [ ] `POST /api/v1/payment/create` — hỗ trợ 1 hoặc nhiều Course cùng lúc; nếu tổng = 0 → auto-enroll ngay, **không** tạo `Payment` row.
- [ ] `POST /api/v1/payment/payos-webhook` (public) — verify HMAC-SHA256 (TreeMap-sort field), idempotent (pessimistic lock + bỏ qua nếu đã `SUCCESS`).
- [ ] `GET /payment/my-history`, `GET /payment/status/{txnRef}`.
- [ ] `GET /payment/manager/all`, `GET /payment/manager/export-excel` (Course Manager/Admin).
- [ ] `PaymentExpirationScheduler` (`@Scheduled`, mỗi 15 phút) — `PENDING` quá 30 phút → `EXPIRED`.
- [ ] `POST /course-manager/statements/generate` — thủ công, mặc định **tháng hiện tại** nếu không truyền `periodMonth`.
- [ ] `MonthlyStatementScheduler` (cron `0 0 0 1 * *`) — tự chạy 00:00 ngày 1 hàng tháng, nhắm **tháng trước** (khác default của API thủ công ở trên — xem Edge Cases).
- [ ] `POST /trainer/statements/{id}/confirm`\|`/reject`.
- [ ] `POST /course-manager/statements/{id}/settle` (bankTxnRef ≥4 ký tự + ảnh biên lai `.jpg/.jpeg/.png`), `/cancel`, `/regenerate`.

## 3. Technical Constraints
- **Idempotency:** webhook dùng `findByTxnRefWithLock` (pessimistic) + check `status==SUCCESS` để bỏ qua webhook trùng.
- **Transaction:** toàn bộ xử lý webhook nằm trong 1 `@Transactional`.
- **Timezone chưa cấu hình tường minh** cho 2 scheduler — chạy theo giờ mặc định JVM/host, chưa xác nhận là Asia/Ho_Chi_Minh.

## 4. Edge Cases
- **Free courses:** bỏ qua hoàn toàn Cart/Payment flow, enroll thẳng qua `CourseServiceImpl.enrollCourse`.
- **Chữ ký webhook sai:** từ chối, không đụng tới bất kỳ `Payment` row nào.
- **Multi-course checkout:** 1 `Payment` có thể phủ nhiều Course (`Payment.courseIds`, CSV) — webhook loop qua từng course để enroll/notify/dọn cart.
- **Generate statement thủ công không truyền `periodMonth`:** ra kết quả khác với scheduler tự động (tháng hiện tại vs tháng trước) — dễ tạo nhầm statement sai kỳ nếu không cẩn thận.
- **Yêu cầu hoàn tiền qua Ticket được Admin duyệt (`REFUND_REQUEST`):** hiện **không có** hành động nào tự đảo trạng thái `Payment`/`Enrollment` tương ứng — hoàn tiền hiện chỉ dừng ở đổi status Ticket, chưa có tác động tài chính/enrollment thật (xem [16-ticket-management.md](16-ticket-management.md)).

## 5. Non-functional Requirements
- **Reliability:** log/giám sát chặt webhook PayOS vì ảnh hưởng trực tiếp doanh thu.
