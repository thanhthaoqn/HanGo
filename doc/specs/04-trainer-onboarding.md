# Feature Specification: 7.4 - Trainer Onboarding

## 1. Business Context
To become a Trainer on HanGo, standard Learners or Guests must submit an application containing their credentials, banking info, and chosen Trainer type (Teacher or Tutor). Administrators review these applications to maintain the quality of instruction on the platform.

## 2. Acceptance Criteria

**Frontend (Flutter):**
- [ ] Trainer Application form for Learners: Select Type (Teacher / Tutor).
- [ ] Input fields for personal info, phone, and banking details.
- [ ] File/Image upload for credentials and proofs (using Cloudinary).
- [ ] Status tracking screen for submitted applications.
- [ ] Admin interface to view pending applications and Approve/Reject with notes.

**Backend (Spring Boot):**
- [ ] *Note:* The `TrainerApplication` entity does not currently exist in the database and MUST be created (`id`, `user_id`, `trainer_type`, `banking_info`, `proof_urls`, `status`, `admin_notes`).
- [ ] API `POST /api/v1/trainer-applications` to submit the form.
- [ ] API `GET /api/v1/admin/trainer-applications` for Admin review.
- [ ] API `PUT /api/v1/admin/trainer-applications/{id}/approve` (or reject).
- [ ] Upon approval, the backend must dynamically assign the `TRAINER` role to the user's `User` entity and save `RevenueShareRate`.

## 3. Technical Constraints
- **Database:** The application must link to the `User` entity. Cloudinary URLs should be stored as JSON arrays or a separate linked table if multiple documents are allowed.
- **Workflow:** An approved application triggers an event that modifies the `roles` set in the `User` entity.

## 4. Edge Cases
- **Pending Application:** If a user already has a pending application, block them from submitting a new one.
- **Role Re-assignment:** If a user is already a Trainer, they cannot submit an onboarding application.

## 5. Non-functional Requirements
- **Security:** Banking information must be stored securely and only accessible to authorized Admins and the user themselves.
