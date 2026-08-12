# Feature Specification: FE-16 — Ticket Management

> Ref: [HanGo_Documentation.md](../HanGo_Documentation.md) §7.16 (TKT), §9.7 (state machine).

> ⚠️ **Cập nhật 2026-08-12:** Loại bỏ hoàn toàn tính năng Ticket đối với **Learner** và **Course Manager**. Quyền tạo Ticket hỗ trợ (`TicketController`) chỉ dành riêng cho **Trainer** (`TRAINER`) gửi yêu cầu tới **Administrator** (`ADMINISTRATOR`). Quyền tiếp nhận và xử lý Ticket (`ManagementTicketController`) thuộc độc quyền của **Administrator**.

## 1. Business Context
Hệ thống hỗ trợ kênh riêng giữa **Trainer** và **Administrator** — Trainer tạo Ticket gửi các vấn đề của mình (câu hỏi chung, tranh chấp doanh thu, cập nhật thông tin nhận tiền, sự cố nội dung...). **Duy nhất Administrator** tiếp nhận, phản hồi và xử lý duyệt (Approve/Reject) các Ticket hỗ trợ trên toàn hệ thống. Learner và Course Manager không có quyền tạo hay quản lý Ticket.

## 2. Acceptance Criteria

**Frontend (Flutter):**
- [ ] `create_ticket_modal.dart` — form tạo/sửa ticket của Trainer (tiêu đề, mô tả, category dropdown, mặc định `GENERAL_ENQUIRY`).
- [ ] Learner: Không có giao diện hay nút tạo/xem Ticket (đã gỡ bỏ hoàn toàn khỏi `my_information_page.dart`).
- [ ] Trainer: `trainer_tickets_page.dart` — tab "Support & Tickets" riêng trong `TrainerShellPage`.
- [ ] Course Manager: Không có giao diện quản lý Ticket (đã gỡ bỏ khỏi `CourseManagerSidebar` và `CourseManagerShellPage`).
- [ ] Administrator: `admin_dashboard_page.dart` tab "Support Tickets" (Index 8) — tích hợp `ManagementTicketsPage(isEmbedded: true)` với tabs ALL/PENDING/PROCESSED, filter status/category, mở `process_ticket_modal.dart` để Approve/Reject.
- [ ] `ticket_detail_page.dart` — trang riêng xem đầy đủ 1 ticket (thread + reply box).

**Backend (Spring Boot):**
- [ ] `TicketController` (`/api/v1/tickets`, được bảo vệ bởi `@PreAuthorize("hasAnyRole('TRAINER', 'ADMINISTRATOR')")`): `POST /` tạo, `PUT /{id}` sửa (chủ ticket), `GET /{id}` chi tiết, `GET /my-tickets?status=`, `POST /{id}/messages` trả lời.
- [ ] `ManagementTicketController` (`/api/v1/management/tickets`, gate `hasAuthority('MANAGE_ACCOUNTS_ROLES') or hasRole('ADMINISTRATOR')`): `GET /` hàng chờ (filter status/category/từ khoá), `POST /{id}/process` (Approve/Reject), `GET /stats`.
- [ ] Tạo ticket tự sinh `ticketCode` duy nhất, snapshot role người tạo, tạo sẵn 1 `TicketMessage` từ nội dung mô tả, gửi thông báo `TicketCreated` tới `ADMINISTRATOR`.
- [ ] Trả lời đầu tiên từ Administrator tự chuyển `PENDING → PROCESSING`.

## 3. Technical Constraints
- **RBAC người tạo:** Chỉ `TRAINER` và `ADMINISTRATOR` được phép gọi `TicketController` tạo/trả lời ticket. `LEARNER` và `COURSE_MANAGER` bị chặn 403 Forbidden.
- **RBAC phía xử lý:** Chỉ Administrator được phép truy cập `ManagementTicketController` và xử lý toàn bộ các category ticket (bao gồm cả `PAYOUT_INFO_UPDATE` và `REFUND_REQUEST`).
- **`Ticket.assignedTo` khai báo nhưng chưa từng được set** trong code hiện tại — cột chết, chưa có cơ chế phân công ticket cho 1 staff cụ thể.
- **Notification ticket mới:** bắn `notifyRole("ADMINISTRATOR", "TicketCreated", ...)` trực tiếp tới tất cả Administrator.

## 4. Edge Cases
- **Ticket đã `APPROVED`/`REJECTED`:** vẫn sửa được tiêu đề/mô tả hoặc thêm message — **chưa có khoá thread**, cần biết trước khi coi ticket "đã xử lý" là bất biến.
- **`REFUND_REQUEST` được Admin Approve:** chỉ đổi status Ticket — **không** có hành động nào tự động hoàn tiền/đảo Payment/Enrollment (xem [14-payment-revenue.md](14-payment-revenue.md) Edge Cases). Xử lý hoàn tiền thật (nếu có) hiện là thao tác thủ công ngoài hệ thống.
- **Course Manager / Learner gọi API Ticket:** bị `@PreAuthorize` từ chối ngay với HTTP 403 Forbidden.

## 5. Non-functional Requirements
- **Auditability:** mỗi lần xử lý (Approve/Reject) ghi lại `processedBy`/`processedAt`/`adminResponse`/`rejectionReason` trên chính `Ticket` — đủ để tra cứu ai xử lý khi nào, nhưng chưa có bản ghi audit log riêng tách khỏi entity (khác cách Account Management ghi `AuditLog`).
