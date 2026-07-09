# Feature Specification: FE-12 - Payment & Revenue

## 1. Business Context
HanGo operates as a course marketplace. Paid courses require learners to complete checkout via the VNPay payment gateway. Once checkout is successful, revenue is split automatically based on the Trainer's split rate (70/30 or 60/40). Finally, at the end of each month, the system generates monthly statements for Trainers to confirm before Admins manually transfer the payouts.

## 2. Acceptance Criteria

**Frontend (Flutter):**
- [ ] Course details checkout button redirecting user to VNPay payment URL.
- [ ] Order status page showing payment progress (Pending, Paid, Completed, Failed).
- [ ] Revenue dashboard for Trainers displaying sales numbers, charts, and statement logs.
- [ ] Monthly statements list page where Trainers can view and confirm monthly payouts.

**Backend (Spring Boot):**
- [ ] API `POST /api/v1/payments/checkout` to create a VNPay transaction URL for an order.
- [ ] API `GET /api/v1/payments/callback` and IPN webhook endpoint verifying VNPay checksum and completing orders.
- [ ] Automatically calculate and split revenue into Trainer statements table on successful transactions.
- [ ] API `GET /api/v1/statements` to fetch monthly reports, and `PUT /api/v1/statements/{id}/confirm` for Trainer confirmations.

## 3. Technical Constraints
- **Security:** Strict authorization using `@PreAuthorize("hasRole('ADMINISTRATOR')")` for manual settlement recording.
- **Idempotency:** The IPN webhook callback must handle duplicate notifications safely (only enroll once and create revenue record once).
- **Integration:** VNPay integrations must use HMAC-SHA512 checksum validation and secure sandbox configurations.

## 4. Edge Cases
- **Duplicate Callback/IPN:** Double-check IPN request parameters, verifying that duplicate webhook calls don't result in double-payout tracking.
- **Mixture of Free & Paid:** Free courses do not prompt payment and bypass order generation directly into course enrollments.
- **Timezone Alignment:** Sales calculations and statement cycles must align with the Asia/Ho_Chi_Minh timezone.

## 5. Non-functional Requirements
- **Performance:** Checkout transaction initialization response must be `< 300ms`.
