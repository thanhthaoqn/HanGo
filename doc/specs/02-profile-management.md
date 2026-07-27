# Feature Specification: FE-02 — Profile Management

> Ref: [HanGo_Documentation.md](../HanGo_Documentation.md) §7.2 (PROF). Admin-side account list/lock/role management is out of scope here — see [03-rbac.md](03-rbac.md) (FE-03).

> ⚠️ **Ghi chú 2026-07-24:** `ProfileUpdateRequest` hiện **không có** annotation validation nào (`@Valid`/`@NotBlank`/`@Size`) — cập nhật profile không được validate ở tầng server (GAP-PROF-03, chưa sửa — xem `AUDIT_REPORT.md`). Learner "Learning Profile" (FR-PROF-04) và Trainer public/brand page (FR-PROF-05, vốn đã đánh dấu 📌 optional) vẫn chưa xác nhận có implementation đầy đủ tương ứng ở backend — cần đọc lại code trước khi viết test hoặc claim đã "Implemented".

## 1. Business Context
Profile Management lets every logged-in user (Learner, Trainer, Course Manager, Admin) view/update their own personal information (full name, avatar, phone number) and change their own password. Learners additionally get a **Learning Profile** view — courses studied, progress, Exam history, and weaknesses (FR-PROF-04). Trainers may additionally get a public "brand page" (bio, course list) — this is marked open/optional for v1 (📌 FR-PROF-05).

## 2. Acceptance Criteria

**Frontend (Flutter):**
- [ ] Profile viewing and editing interface for all roles (full name, avatar, phone number).
- [ ] Image Picker for Avatar upload with image compression before sending to server.
- [ ] Change Password form requiring current password + new password confirmation.
- [ ] Learner-only "Learning Profile" view: enrolled courses, progress %, Exam attempt history, Weakness Analysis by SkillType.
- [ ] (📌 optional) Trainer public profile / brand page: bio, avatar, list of published Courses.

**Backend (Spring Boot):**
- [ ] API `GET /api/v1/users/me` and `PUT /api/v1/users/me` for profile CRUD.
- [ ] API `GET /api/admin/users` for Admin (supports pagination, search, and filtering by role).
- [ ] API `PUT /api/admin/users/{id}/status` to lock/unlock accounts.
- [ ] Integrate Cloudinary API for storing Avatar images and returning secure URLs.

## 3. Technical Constraints
- **Backend Authorization:** Admin APIs must be strictly protected with `@PreAuthorize("hasRole('ADMINISTRATOR')")`.
- [ ] API `PUT /api/v1/users/me/password` to change password (requires current password match — FR-PROF-03).
- [ ] API `GET /api/v1/users/me/learning-profile` aggregating enrollments, progress, Exam attempts and Weakness Analysis for the Learner.
- [ ] Integrate Cloudinary API for storing Avatar images and returning secure URLs.

## 3. Technical Constraints
- **Image Upload:** Restrict avatar file size to max 2MB. Only accept `.jpg`, `.png`, `.jpeg` formats.
- **Frontend:** Profile state must be managed globally (e.g., using Riverpod) so that the avatar updates instantly across all screens after a successful change.

## 4. Edge Cases
- **Wrong current password on Change Password:** Return HTTP 400/401 with a clear message; do not update the password.
- **Duplicate Email update:** If a user tries to change their email to one already in use, catch `DataIntegrityViolationException` and return HTTP 409 Conflict.
- **Cloudinary upload failure:** If third-party image upload fails, return a graceful error message without crashing the server.

## 5. Non-functional Requirements
- **Performance:** Avatar images should be fetched using optimized Cloudinary URLs (compressed and resized).
- **Usability:** Provide instant visual feedback (Toast/Snackbar) when profile update succeeds or fails.
- **Security:** Never log or return the password hash; changing password must re-hash with BCrypt.
