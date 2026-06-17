# Feature Specification: FT-01 - Authentication

## 1. Business Context
The Authentication feature ensures that only valid users can access the HanGo system. It includes Registration, Login (using traditional Email/Password and Google OAuth2), as well as Forgot Password. This is the first layer of defense for the EdTech system, ensuring personalized learning paths and data security.

## 2. Acceptance Criteria

**Frontend (Flutter):**
- [ ] Login/Register screens located in `lib/presentation/pages/auth/`.
- [ ] Form Validation: Email matches regex format, Password >= 8 characters, containing letters and numbers.
- [ ] "Login with Google" button uses `google_sign_in` package to fetch Google Token.
- [ ] Call authentication API via `lib/data/services/auth_service.dart` using `dio`.

**Backend (Spring Boot):**
- [ ] API `POST /api/v1/auth/login` to authenticate user.
- [ ] API `POST /api/v1/auth/register` to create a new user.
- [ ] API `POST /api/v1/auth/google` to verify Google Token and issue internal JWT.
- [ ] `AuthService` handles logic: hashing password with `BCryptPasswordEncoder`, generating JWT Access Token (24h expiration).

## 3. Technical Constraints
- **Security:** Do not expose plain text passwords in API logs. Use `spring-boot-starter-security`.
- **Database:** `users` table must have `email` as a UNIQUE constraint.
- **Frontend:** JWT must be stored securely using `flutter_secure_storage` or `shared_preferences`.

## 4. Edge Cases
- **Wrong Password:** Limit login attempts (e.g., 5 times). After 5 failed attempts, lock account for 15 minutes.
- **Email already exists:** When registering, if the email exists, return HTTP 409 Conflict.
- **Expired Token:** Frontend `dio` interceptor must catch HTTP 401, clear local storage, and redirect user to Login screen.

## 5. Non-functional Requirements
- **Performance:** Login API response time must be `< 500ms`.
- **Security:** Passwords must be hashed using BCrypt before storing.
