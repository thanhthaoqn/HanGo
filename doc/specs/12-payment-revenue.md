# Feature Specification: 7.12 - Payment & Revenue

## 1. Business Context
HanGo supports paid courses via VNPay integration. Learners purchase courses, creating an automated flow of Order -> Payment -> Auto-Enrollment. The revenue is split between the platform and the Trainer based on the configured revenue share rate, and Monthly Statements are generated for payouts.

## 2. Acceptance Criteria

**Frontend (Flutter):**
- [ ] Course purchase screen displaying the price and redirecting to VNPay payment gateway.
- [ ] Handling Deep Links / Return URLs from VNPay to display Success/Failed payment UI.
- [ ] Revenue tracking dashboard for Trainers to view their sales and monthly statements.

**Backend (Spring Boot):**
- [ ] *Note:* `Order`, `PaymentTransaction`, and `MonthlyStatement` entities do not currently exist and MUST be created.
- [ ] API `POST /api/v1/orders/create-payment` to generate VNPay URL.
- [ ] API `GET /api/v1/orders/vnpay-ipn` to receive VNPay IPN webhook and verify checksum.
- [ ] Auto-Enrollment logic: Upon successful IPN verification, automatically create an `Enrollment` record for the user and course.
- [ ] Cron job (`@Scheduled`) to automatically generate `MonthlyStatement` records at the end of each month.
- [ ] API for Course Managers to mark Monthly Statements as `PAID` after manual bank transfers.

## 3. Technical Constraints
- **Idempotency:** The VNPay IPN endpoint must be idempotent. If VNPay sends the same successful IPN multiple times, the backend must not create duplicate Enrollments or revenue records.
- **Transaction:** The IPN processing must run in a database transaction (`@Transactional`) to ensure both the Order status update and Enrollment creation succeed together.

## 4. Edge Cases
- **Free Courses:** Bypass the entire Order/Payment flow. Free courses trigger immediate Enrollment creation.
- **Checksum Failure:** If the VNPay IPN checksum is invalid, reject the request and log a potential security breach.
- **Amount Mismatch:** Validate that the amount returned by VNPay exactly matches the Order amount in the database.

## 5. Non-functional Requirements
- **Reliability:** Payments directly affect revenue. Ensure robust error logging and monitoring for the VNPay IPN endpoint.
