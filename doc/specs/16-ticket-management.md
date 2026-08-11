# Feature Specification: FE-16 — Ticket Management

> Ref: [HanGo_Documentation.md](../HanGo_Documentation.md) §7.16 (TKT), §9.7 (state machine). **Module hoàn toàn mới** trong Feature Map 19-module (2026-08-10) — chưa từng có file spec riêng trước đây; viết mới từ đọc code trực tiếp (`Ticket`/`TicketMessage` entity, `TicketController`, `ManagementTicketController`, `TicketServiceImpl`).

## 1. Business Context
Hệ thống hỗ trợ chung — bất kỳ role nào (Learner/Trainer/Course Manager/Admin) tạo Ticket cho vấn đề của mình (câu hỏi chung, tranh chấp doanh thu, cập nhật thông tin nhận tiền, yêu cầu hoàn tiền, sự cố nội dung...). Staff (Course Manager và Administrator) xử lý ticket của người khác. 2 category tài chính nhạy cảm (`PAYOUT_INFO_UPDATE`, `REFUND_REQUEST`) **chỉ Administrator** được xử lý — Course Manager cố xử lý sẽ bị chặn ở tầng Service.

## 2. Acceptance Criteria

**Frontend (Flutter):**
- [ ] `create_ticket_modal.dart` — form tạo/sửa ticket (tiêu đề, mô tả, category dropdown, mặc định `GENERAL_ENQUIRY`).
- [ ] Learner: panel `_SupportTicketsPanel` nhúng trong `my_information_page.dart` (tạo, xem danh sách, filter status, xem thread).
- [ ] Trainer: `trainer_tickets_page.dart` — tab "Support & Tickets" riêng trong `TrainerShellPage`.
- [ ] Course Manager: `management_tickets_page.dart` — tab "Support Tickets" trong `CourseManagerShellPage`/sidebar, tabs ALL/PENDING/PROCESSED, mở `process_ticket_modal.dart` để Approve/Reject.
- [ ] `ticket_detail_page.dart` — trang riêng xem đầy đủ 1 ticket (thread + reply box).
- [ ] ⚠️ **Administrator hiện chưa có UI để xử lý Ticket** — `admin_dashboard_page.dart` có import `ManagementTicketsPage` nhưng chưa nhúng vào bất kỳ tab/menu nào (dead import). Cần thêm 1 tab Ticket cho Admin nếu muốn Admin thực sự dùng được quyền xử lý ticket tài chính mà backend đã cho phép.

**Backend (Spring Boot):**
- [ ] `TicketController` (`/api/v1/tickets`, **không có `@PreAuthorize`**, chỉ cần đăng nhập): `POST /` tạo, `PUT /{id}` sửa (chủ ticket), `GET /{id}` chi tiết, `GET /my-tickets?status=`, `POST /{id}/messages` trả lời.
- [ ] `ManagementTicketController` (`/api/v1/management/tickets`, gate `hasAnyRole('ADMINISTRATOR','COURSE_MANAGER')` — role `TRAINER_LEAD` trong code là tên cũ, không map user thật): `GET /` hàng chờ (filter status/category/từ khoá), `POST /{id}/process` (Approve/Reject), `GET /stats`.
- [ ] Tạo ticket tự sinh `ticketCode` duy nhất, snapshot role người tạo, tạo sẵn 1 `TicketMessage` từ nội dung mô tả.
- [ ] Trả lời đầu tiên từ staff (role không phải `LEARNER`/`TRAINER`) tự chuyển `PENDING → PROCESSING`.

## 3. Technical Constraints
- **Không role-gate phía người tạo:** ai đăng nhập cũng tạo/tự trả lời được ticket của mình.
- **RBAC 2 tầng phía xử lý:** tầng Controller cho cả Course Manager lẫn Admin vào `ManagementTicketController`; tầng Service **chặn riêng** Course Manager khỏi 2 category `PAYOUT_INFO_UPDATE`/`REFUND_REQUEST` (lỗi rõ ràng "Assigned to System Admin").
- **`Ticket.assignedTo` khai báo nhưng chưa từng được set** trong code hiện tại — cột chết, chưa có cơ chế phân công ticket cho 1 staff cụ thể.
- **Notification ticket mới hiện gọi `notifyRole("TRAINER_LEAD", ...)`** — chuỗi này không map tới user thật nào (role thật là `COURSE_MANAGER`) → **thông báo "có ticket mới" hiện không tới được ai** (bug, cần dev sửa thành `"COURSE_MANAGER"`).
- **Message sender role khi staff xử lý ticket bị hardcode `"ADMINISTRATOR"`** kể cả khi người xử lý thật là Course Manager — hiển thị nhãn sai trong thread, chưa ảnh hưởng logic phân quyền.

## 4. Edge Cases
- **Ticket đã `APPROVED`/`REJECTED`:** vẫn sửa được tiêu đề/mô tả hoặc thêm message — **chưa có khoá thread**, cần biết trước khi coi ticket "đã xử lý" là bất biến.
- **`REFUND_REQUEST` được Admin Approve:** chỉ đổi status Ticket — **không** có hành động nào tự động hoàn tiền/đảo Payment/Enrollment (xem [14-payment-revenue.md](14-payment-revenue.md) Edge Cases). Xử lý hoàn tiền thật (nếu có) hiện là thao tác thủ công ngoài hệ thống.
- **Course Manager cố xử lý ticket `PAYOUT_INFO_UPDATE`/`REFUND_REQUEST`:** bị chặn ở Service, trả lỗi rõ ràng.

## 5. Non-functional Requirements
- **Auditability:** mỗi lần xử lý (Approve/Reject) ghi lại `processedBy`/`processedAt`/`adminResponse`/`rejectionReason` trên chính `Ticket` — đủ để tra cứu ai xử lý khi nào, nhưng chưa có bản ghi audit log riêng tách khỏi entity (khác cách Account Management ghi `AuditLog`).
