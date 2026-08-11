# Feature Specification: FE-03 — Account Management

> Ref: [HanGo_Documentation.md](../HanGo_Documentation.md) §7.3 (ACC). Role→Permission matrix is a separate module — see [04-role-permission-management.md](04-role-permission-management.md) (FE-04). This spec used to be merged with RBAC as `03-rbac.md`; split 2026-08-10 to match the current 19-module Feature Map.

## 1. Business Context
Administrator quản lý toàn bộ tài khoản trong hệ thống: xem danh sách, xem chi tiết, tạo tài khoản thủ công, cập nhật, và activate/deactivate. Đây là CRUD tài khoản thuần tuý — việc gán/đổi **role** cho 1 tài khoản cũng nằm trong cùng API cập nhật (`PUT /api/admin/users/{id}`), nhưng khái niệm role/permission matrix thuộc phạm vi FE-04.

## 2. Acceptance Criteria

**Frontend (Flutter, `admin_dashboard_page.dart` tab "Accounts"):**
- [ ] Danh sách tài khoản: tìm kiếm, lọc theo role (Learner/Trainer/Course Manager/Admin) và status.
- [ ] Xem chi tiết 1 tài khoản.
- [ ] "Create New Account" — form nhập tay, chọn role qua dropdown (gồm cả Course Manager).
- [ ] Activate/Deactivate (khoá/mở khoá).
- [ ] Sửa thông tin tài khoản (họ tên/email/sđt/giới tính/ngày sinh/status/role).

**Backend (Spring Boot, tất cả trong `AdminController`, base `/api/admin`, gate `hasAuthority('MANAGE_ACCOUNTS_ROLES') or hasRole('ADMINISTRATOR')`):**
- [ ] `GET /users?roleType=&search=&page=&size=` — `roleType` nhận `learner`/`trainer`/`course_manager`/`admin`/`staff`.
- [ ] `GET /users/{id}`.
- [ ] `POST /users` — whitelist role `LEARNER`/`TRAINER`/`COURSE_MANAGER`/`ADMINISTRATOR`; tài khoản tạo kiểu này kích hoạt ngay (`isVerified=true`, `status=ACTIVE`, không OTP).
- [ ] `PUT /users/{id}/status` — whitelist status `ACTIVE`/`INACTIVE`.
- [ ] `PUT /users/{id}` — cập nhật gộp (profile + status + role trong 1 lần gọi), dùng chung whitelist status với API trên.

## 3. Technical Constraints
- **Self-lock prevention:** Admin không tự khoá được chính mình — chặn ở cả `PUT /users/{id}/status` **và** `PUT /users/{id}`.
- **Audit:** mọi hành động tạo/sửa/đổi status ghi 1 dòng `AuditLog` — xem [19-dashboard.md](19-dashboard.md) FR-DASH-04.
- **Đăng ký tự do (register) chỉ cho Learner/Trainer** — tài khoản Course Manager/Admin **chỉ** tạo được qua module này, không có đường tự đăng ký.

## 4. Edge Cases
- **Role không hợp lệ khi tạo tài khoản:** bị chặn bởi whitelist, không tự tạo `Role` row mới cho chuỗi lạ.
- **Status không hợp lệ khi cập nhật:** bị chặn bởi whitelist (chỉ `ACTIVE`/`INACTIVE`).
- **Admin cố khoá chính mình:** trả lỗi rõ ràng, không thực hiện.

## 5. Non-functional Requirements
- **Performance:** danh sách hiện tổng hợp bằng Java in-memory filter/aggregate là chính (trừ Top Courses dùng SQL native) — chưa cần tối ưu thêm ở quy mô dữ liệu hiện tại.
