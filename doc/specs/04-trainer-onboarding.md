# Feature Specification: FE-04 - Trainer Onboarding

## 1. Business Context
To allow qualified instructors and peers to publish courses on the HanGo marketplace, users must submit an onboarding application. The onboarding workflow ensures that Trainer accounts are verified by Administrators, protecting course quality and mapping revenue split rates based on the trainer type (Professional Trainer vs Peer Tutor).

## 2. Acceptance Criteria

**Frontend (Flutter):**
- [ ] Onboarding application form: select role type (Professional Trainer vs Peer Tutor), fill in phone number, CCND/National ID, and bank details.
- [ ] Document proof upload section (diplomas, certificates, transcripts).
- [ ] Application tracking page displaying status (Draft, Submitted, Approved, Rejected) and reject notes.
- [ ] Admin panel view displaying all applications, document links, and actions to Approve or Reject.

**Backend (Spring Boot):**
- [ ] API `POST /api/v1/trainers/apply` to submit a trainer onboarding application.
- [ ] API `GET /api/v1/trainers/applications` (Admin only) to list pending applications.
- [ ] API `POST /api/v1/trainers/applications/{id}/review` (Admin only) to approve or reject with comments.
- [ ] Automatically upgrade user role to `ROLE_TRAINER` on approval, setting `TrainerType` and corresponding `RevenueShareRate`.

## 3. Technical Constraints
- **Security:** Strict authorization using `@PreAuthorize("hasRole('ADMINISTRATOR')")` for review endpoints.
- **Database:** `trainer_applications` table maps to user ID, status, document URL (Cloudinary links), and timestamps.
- **File Storage:** Verification documents must be uploaded directly to Cloudinary and database stores secure HTTPS links.

## 4. Edge Cases
- **Missing Proof Document:** Prevent application submission if no document link is uploaded.
- **Resubmission:** If an application is rejected, allow the user to modify and resubmit, resetting status to `Submitted`.
- **First Course Constraint:** Approved Trainers must publish their first course for free (`BR-G02`).

## 5. Non-functional Requirements
- **Performance:** Application status updates should trigger real-time notifications to the user.
