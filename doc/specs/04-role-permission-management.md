# Feature Specification: FE-04 — Role and Permission Management

> Ref: [HanGo_Documentation.md](../HanGo_Documentation.md) §7.4 (RBAC), §4.3. Account CRUD is a separate module — see [03-account-management.md](03-account-management.md) (FE-03).

> ⚠️ **Thay đổi lớn so với thiết kế trước (2026-08-10):** RBAC **không còn tĩnh/chỉ đọc**. Có `Permission` entity thật, bảng `role_permissions`, và API **ghi** thật: `PUT /api/admin/roles/{roleName}/permissions`. "Configure Permission" trong Feature Map giờ là 1 tính năng có thật, không phải placeholder.

## 1. Business Context
Role-Based Access Control cho phép Administrator xem toàn bộ Role/Permission trong hệ thống, gán role cho tài khoản, và **cấu hình lại** tập permission của từng Role. 4 Role thật: `LEARNER`/`TRAINER`/`COURSE_MANAGER`/`ADMINISTRATOR`. 16 Permission được seed sẵn (4 permission/role), nhóm theo `module` (Learning & Enrollment / Course Management / Analytics / Platform / System Settings).

## 2. Acceptance Criteria

**Frontend (Flutter, `admin_dashboard_page.dart` tab "Roles"):**
- [ ] `RoleMatrixTab` — ma trận Role × Permission (cột Admin/Course Manager/Trainer/Learner).
- [ ] `RoleDetailDrawer` — panel sửa tập permission của 1 role, nhóm theo module, có Save gọi API thật.
- [ ] Sidebar/menu item của Course Manager và Trainer tự ẩn/hiện theo permission code hiện có của user đang đăng nhập (ví dụ `VIEW_PLATFORM_DASHBOARD`, `CREATE_AND_MANAGE_EXAMS_CM`, `VIEW_OWN_REVENUE`).

**Backend (Spring Boot, trong `AdminController`):**
- [ ] `GET /api/admin/roles` — danh sách role kèm permission hiện có.
- [ ] `GET /api/admin/permissions` — danh sách 16 permission (code/name/description/module).
- [ ] `PUT /api/admin/roles/{roleName}/permissions` — thay thế toàn bộ tập permission của 1 role bằng danh sách permission code mới, ràng buộc theo `Permission.coreForRoles`/`restrictedForRoles`.
- [ ] Gán/đổi role cho 1 tài khoản dùng chung API cập nhật tài khoản (FE-03, `PUT /api/admin/users/{id}`).

## 3. Technical Constraints
- **Administrator luôn có cửa hardcode:** hầu hết `@PreAuthorize` viết dạng `hasAuthority('X') or hasRole('ADMINISTRATOR')` — nghĩa là Configure Permission **không thể** hạn chế Administrator, dù Admin có gỡ hết permission của chính role Administrator khỏi ma trận.
- **Một số controller không đọc permission code:** `CourseManagerDashboardController` (toàn bộ, trừ 2 endpoint notification) và `ManagementTicketController` dùng thuần `hasAnyRole(...)`/`hasRole(...)` — Configure Permission **không có tác dụng** lên các endpoint này (đổi permission của Course Manager không mở/khoá được các route đó).
- **`Role` row chỉ tồn tại khi có user đầu tiên giữ role đó** — permission mặc định của `RolePermissionDataInitializer` chỉ gán khi role hiện có 0 permission (không ghi đè permission Admin đã tuỳ biến, kể cả sau khi restart backend).

## 4. Edge Cases
- **Gán permission bị `restrictedForRoles` chặn:** API từ chối, giữ nguyên permission cũ của role đó.
- **Đổi permission của Course Manager rồi kỳ vọng Ticket/Dashboard đổi theo:** sẽ **không** thấy tác dụng ngay với 2 controller nêu trên — cần biết trước khi test Configure Permission để tránh coi đây là bug UI.

## 5. Non-functional Requirements
- **Auditability:** hiện **chưa** có audit log riêng cho hành động Configure Permission (khác với tạo/sửa tài khoản — xem [19-dashboard.md](19-dashboard.md) FR-DASH-04) — cần xác nhận lại trước khi coi đây là đã có audit đầy đủ.
