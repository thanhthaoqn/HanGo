# Feature Specification: FT-02 - Account Management

## 1. Business Context
Account Management allows users to view and update their personal information (Profile), including Avatar, Name, and Phone Number. For Admins, this feature provides a comprehensive dashboard to manage all users in the system, including the ability to lock/unlock accounts to maintain community standards.

## 2. Acceptance Criteria

**Frontend (Flutter):**
- [ ] Profile viewing and editing interface for Learner/Trainer.
- [ ] Image Picker for Avatar upload with image compression before sending to server.
- [ ] User management `DataTable` interface for Admins.
- [ ] Render "Lock Account" / "Unlock Account" buttons based on user role.

**Backend (Spring Boot):**
- [ ] API `GET /api/v1/users/me` and `PUT /api/v1/users/me` for profile CRUD.
- [ ] API `GET /api/v1/users` for Admin (supports pagination, filtering by role).
- [ ] API `PUT /api/v1/users/{id}/status` to lock/unlock accounts.
- [ ] Integrate Cloudinary API for storing Avatar images and returning secure URLs.

## 3. Technical Constraints
- **Backend Authorization:** Admin APIs must be strictly protected with `@PreAuthorize("hasRole('ADMIN')")`.
- **Image Upload:** Restrict avatar file size to max 2MB. Only accept `.jpg`, `.png`, `.jpeg` formats.
- **Frontend:** Profile state must be managed globally (e.g., using Riverpod) so that the avatar updates instantly across all screens after a successful change.

## 4. Edge Cases
- **Admin locks their own account:** Backend must validate and block this action, returning HTTP 400 Bad Request.
- **Duplicate Email update:** If a user tries to change their email to one already in use, catch `DataIntegrityViolationException` and return HTTP 409 Conflict.
- **Cloudinary upload failure:** If third-party image upload fails, return a graceful error message without crashing the server.

## 5. Non-functional Requirements
- **Performance:** Avatar images should be fetched using optimized Cloudinary URLs (compressed and resized).
- **Usability:** Provide instant visual feedback (Toast/Snackbar) when profile update succeeds or fails.
