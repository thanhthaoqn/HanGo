# Feature Specification: FE-01 — Authentication

> Ref: [HanGo_Documentation.md](../HanGo_Documentation.md) §7.1 (AUTH)

> ⚠️ **Cập nhật 2026-08-10 (đọc trực tiếp `AuthController`/`AuthService`/`PasswordPolicy`):** hệ thống hiện **có đầy đủ** access token + refresh token (bảng `RefreshToken`, lưu hash, xoay vòng single-use khi refresh, thu hồi khi logout/đổi mật khẩu) — khác với ghi chú "chỉ 1 JWT" ở bản tài liệu trước. `authenticateUser` hiện chặn login với **bất kỳ status nào khác `ACTIVE`** (không chỉ riêng `"INACTIVE"`), và khoá 15 phút sau 5 lần sai mật khẩu liên tiếp.

## 1. Business Context
The Authentication feature ensures that only valid users can access the HanGo system. It includes Register, Login (Email/Password và Google OAuth2), Forgot Password, và Logout. Registration cho phép chọn role **Learner** hoặc **Trainer** ngay lúc đăng ký — chọn Trainer gán role Trainer **ngay lập tức**, không chờ duyệt (xem [05-trainer-application-management.md](05-trainer-application-management.md)).

## 2. Acceptance Criteria

**Frontend (Flutter):**
- [ ] Login/Register screens (`login_page.dart`, `register_page.dart`), Role toggle Learner/Trainer lúc Register (không có lựa chọn Course Manager/Admin).
- [ ] Form validation: email đúng định dạng, password theo `PasswordPolicy` (xem BR-AUTH-02).
- [ ] Màn hình nhập OTP (`verify_otp_page.dart`), auto-advance/paste, cooldown gửi lại 60s.
- [ ] "Login with Google" dùng `google_sign_in`.
- [ ] `forgot_password_page.dart` → `verify_otp_page.dart` → `reset_password_page.dart`.

**Backend (Spring Boot, tất cả trong `AuthController` base path `/api/auth`, đều public):**
- [ ] `POST /login`, `POST /register`, `POST /google`.
- [ ] `POST /forgot-password`, `POST /verify-otp`, `POST /reset-password`.
- [ ] `GET /check-verification`, `POST /resend-verification`.
- [ ] `POST /refresh-token`, `POST /logout`.
- [ ] `PUT /profile/avatar` (endpoint duy nhất trong controller này yêu cầu đăng nhập).

## 3. Technical Constraints
- **Security:** Mật khẩu hash BCrypt. Refresh token lưu **hash**, không lưu token gốc.
- **Database:** `users.email` UNIQUE, so khớp không phân biệt hoa/thường.
- **Frontend:** JWT lưu qua `SharedPreferences`/`flutter_secure_storage` (2 nơi song song, chưa đồng bộ tường minh — xem `HanGo_Documentation.md` §22).

## 4. Edge Cases
- **Tài khoản chưa verify login:** chặn với thông báo riêng ("hãy xác minh email"), kiểm tra **trước** check status chung.
- **Sai mật khẩu 5 lần liên tiếp:** khoá đăng nhập 15 phút (HTTP 423), tự reset đếm khi login thành công.
- **Email đã tồn tại khi register:** trả lỗi rõ ràng, không tạo trùng.
- **Refresh token hết hạn/bị thu hồi:** `refreshAccessToken` từ chối, yêu cầu đăng nhập lại.
- **Quên mật khẩu với email không tồn tại:** trả thông báo chung chung giống hệt trường hợp email tồn tại (chống user enumeration).

## 5. Non-functional Requirements
- **Security:** không log mật khẩu plaintext; OTP tối đa 5 lần thử sai rồi phải xin lại.
