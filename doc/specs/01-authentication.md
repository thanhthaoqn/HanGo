# Feature Specification: FT-01 - Authentication

## 1. Business Context
The Authentication feature ensures that only valid users can access the HanGo system. It includes Registration, Login (using traditional Email/Password and Google OAuth2), as well as Forgot Password and Account Verification via OTP. This is the first layer of defense for the EdTech system, ensuring personalized learning paths and data security.

## 2. Acceptance Criteria

**Frontend (Flutter):**
- [ ] Login/Register screens located in `lib/presentation/pages/auth/`.
- [ ] Form Validation: Email matches regex format, Password >= 8 characters, containing letters and numbers.
- [ ] OTP verification overlay or screen to enter verification codes.
- [ ] "Login with Google" button uses `google_sign_in` package to fetch Google Token.
- [ ] Call authentication API via `lib/data/services/auth_service.dart` using `dio`.

**Backend (Spring Boot):**
- [ ] API `POST /api/auth/login` to authenticate user.
- [ ] API `POST /api/auth/register` to create a new user (with status inactive, sending verification email).
- [ ] API `POST /api/auth/google` to verify Google Token and issue internal JWT.
- [ ] API `POST /api/auth/forgot-password` to trigger password reset OTP email.
- [ ] API `POST /api/auth/verify-otp` to verify current password reset OTP.
- [ ] API `POST /api/auth/reset-password` to set a new password after successful OTP verification.
- [ ] API `GET /api/auth/verify` to activate the account via the verification email link.
- [ ] API `GET /api/auth/check-verification` and `POST /api/auth/resend-verification` for activation management.
- [ ] `AuthService` handles logic: hashing password with `BCryptPasswordEncoder`, generating JWT Access Token (24h expiration) and Refresh Token.

## 3. Technical Constraints
- **Security:** Do not expose plain text passwords in API logs. Use `spring-boot-starter-security`.
- **Database:** `users` table must have `email` as a UNIQUE constraint.
- **Frontend:** JWT must be stored securely using `flutter_secure_storage` or `shared_preferences`.

## 4. Edge Cases
- **Unverified Account Login:** If a user tries to log in before verifying their email via OTP/link, block the authentication attempt and return HTTP 403 Forbidden (or a specific validation error).
- **Wrong Password:** Limit login attempts (e.g., 5 times). After 5 failed attempts, lock account for 15 minutes.
- **Email already exists:** When registering, if the email exists, return HTTP 409 Conflict.
- **Expired Token:** Frontend `dio` interceptor must catch HTTP 401, clear local storage, and redirect user to Login screen.

## 5. Non-functional Requirements
- **Performance:** Login API response time must be `< 500ms`.
- **Security:** Passwords must be hashed using BCrypt before storing.

