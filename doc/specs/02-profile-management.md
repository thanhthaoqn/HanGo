# Feature Specification: FE-02 — Profile Management

> Ref: [HanGo_Documentation.md](../HanGo_Documentation.md) §7.2 (PROF). Admin-side account list/lock/role management is out of scope here — see [03-account-management.md](03-account-management.md) (FE-03).

> ⚠️ **Cập nhật 2026-08-10:** `ProfileUpdateRequest` vẫn **không có** annotation validation nào (`@Valid`/`@NotBlank`/`@Size`) — vẫn mở, chưa sửa. "View Learning History" (FR-PROF-04) hiện được phục vụ qua endpoint danh sách Course có `filterType=ENROLLED|IN_PROGRESS|COMPLETED`, **không phải** một API "learning-profile" tổng hợp riêng như bản trước mô tả.

## 1. Business Context
Profile Management cho mọi role đã đăng nhập xem/sửa thông tin cá nhân và đổi mật khẩu. Learner có thêm "View Learning History". Trainer có thêm "View Trainer Public Profile" (bio, kinh nghiệm, danh sách Course) — mức độ công khai thật sự (Guest xem được hay chỉ user đã login) **chưa xác nhận độc lập** ở đợt audit này, cần kiểm tra route cụ thể trước khi coi là hoàn tất.

## 2. Acceptance Criteria

**Frontend (Flutter):**
- [ ] Giao diện xem/sửa profile cho mọi role (họ tên, avatar, số điện thoại, giới tính, ngày sinh, địa chỉ).
- [ ] Đổi mật khẩu (yêu cầu mật khẩu hiện tại + xác nhận mật khẩu mới).
- [ ] Learner: "My Learning" hiển thị danh sách Course theo trạng thái (Enrolled/In Progress/Completed) + lịch sử Exam attempt.
- [ ] Trainer: `trainer_profile_page.dart` — 4 tab (Personal Info, CV & Experience, Bank Account, Security).

**Backend (Spring Boot):**
- [ ] `GET /api/v1/users/me`, `PUT /api/v1/users/me` (không có `@PreAuthorize`, tự check `@AuthenticationPrincipal == null`).
- [ ] `PUT /api/v1/users/change-password` (yêu cầu đúng mật khẩu hiện tại — FR-PROF-03).
- [ ] `GET /api/v1/courses?filterType=ENROLLED|IN_PROGRESS|COMPLETED` phục vụ Learning History (không phải endpoint riêng).
- [ ] Đổi email qua `PUT /me` → tự reset `isVerified=false` (cần verify lại email mới).
- [ ] Tích hợp Cloudinary lưu Avatar.

## 3. Technical Constraints
- **Validation còn thiếu (biết trước khi test):** `ProfileUpdateRequest` không chặn định dạng email/độ dài field ở server — dữ liệu sai vẫn lưu được, phải test kỹ ở tầng UI thay vì tin server chặn hộ.
- **Image Upload:** giới hạn file avatar theo quy ước chung Cloudinary của dự án (không có giới hạn cứng riêng xác nhận được trong `ProfileUpdateRequest`/`AuthService.updateProfile`).

## 4. Edge Cases
- **Sai mật khẩu hiện tại khi đổi mật khẩu:** trả lỗi rõ ràng, không đổi.
- **Đổi email trùng email đã tồn tại:** service tự kiểm tra unique trước khi lưu, trả lỗi thay vì để DB constraint văng exception thô.
- **Cloudinary upload lỗi:** không được làm crash luồng cập nhật profile chính.

## 5. Non-functional Requirements
- **Security:** không log/trả về password hash; đổi mật khẩu thành công thu hồi **toàn bộ** refresh token của user (buộc đăng nhập lại mọi thiết bị).
