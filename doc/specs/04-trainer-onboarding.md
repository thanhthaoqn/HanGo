# Feature Specification: 7.4 - Trainer Onboarding

## 1. Business Context
To become a Trainer on HanGo, standard Learners or Guests must submit an application containing their credentials, banking info, and chosen Trainer type (Teacher or Tutor). Administrators review these applications to maintain the quality of instruction on the platform.

## 2. Acceptance Criteria

**Frontend (Flutter):**
- [ ] Onboarding application form: select role type (Professional Trainer vs Peer Tutor), fill in phone number, CCCD/National ID, and bank details.
- [ ] Document proof upload section (diplomas, certificates, transcripts).
- [ ] Application tracking page displaying status (Draft, Submitted, Approved, Rejected) and reject notes.
- [ ] Admin panel view displaying all applications, document links, and actions to Approve or Reject.

**Backend (Spring Boot):**
- [ ] API `POST /api/v1/trainers/become-trainer` to initialize/request trainer status.
- [ ] API `GET /api/v1/trainers/profile` to get current onboarding trainer profile.
- [ ] API `PUT /api/v1/trainers/profile` to save trainer application details as a draft.
- [ ] API `POST /api/v1/trainers/profile/submit` to submit the profile details for Admin review.
- [ ] API `GET /api/v1/admin/trainer-profiles` (Admin only) to list/search trainer profile applications.
- [ ] API `PUT /api/v1/admin/trainer-profiles/{id}/review` (Admin only) to approve or reject with comments.
- [ ] Automatically upgrade user role to `ROLE_TRAINER` on approval, setting `TrainerType` and corresponding `RevenueShareRate`.

## 3. Technical Constraints
- **Security:** Strict authorization using `@PreAuthorize("hasRole('ADMINISTRATOR')")` for review endpoints.
- **Database:** `trainer_profiles` table maps to user ID, status, documents (Cloudinary links), bank info, and timestamps.
- **File Storage:** Verification documents must be uploaded directly to Cloudinary and database stores secure HTTPS links.

## 4. Edge Cases
- **Missing Proof Document:** Prevent application submission if no document link is uploaded.
- **Resubmission:** If an application is rejected, allow the user to modify and resubmit, resetting status to `SUBMITTED`.
- **First Course Constraint:** Approved Trainers must publish their first course for free (`BR-G02`).

## 5. Non-functional Requirements
- **Performance:** Application status updates should trigger real-time notifications to the user.
