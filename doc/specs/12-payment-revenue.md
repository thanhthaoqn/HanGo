# Feature Specification: FE-12 — Payment & Revenue

> Ref: [HanGo_Documentation.md](../HanGo_Documentation.md) §7.12 (PAY)

## 1. Business Context
HanGo supports paid courses via **PayOS** integration (superseding an earlier VNPay design — the actual implementation is PayOS end-to-end: checkout link creation, QR payment, and webhook verification). Learners add courses to a Cart, then check out, creating an automated flow of Cart → Payment → Auto-Enrollment. The revenue is split between the platform and the Trainer based on trainer type (PROFESSIONAL 70/30, PEER_TUTOR 60/40), and Monthly Statements are generated on demand by the Course Manager (`POST /api/v1/course-manager/statements/generate`, not yet an automatic cron job). Pay-in (purchase, revenue recording, statement generation) is automatic once triggered; payout (transferring money to the Trainer) is a **manual bank transfer recorded by the Course Manager / Administrator** via the settlement endpoint — Administrator's own dashboard does not surface revenue figures directly (separation of duties, BR-G11).

## 2. Acceptance Criteria

**Frontend (Flutter):**
- [x] Cart page (`cart_page.dart`) listing selected courses with pricing, and a PayOS QR payment dialog (`payment_qr_dialog.dart`).
- [x] Handling return/cancel redirects from PayOS to display Success/Failed payment UI.
- [x] Revenue tracking dashboard for Trainers (`trainer_revenue_page.dart`) showing available/pending balances and statement history.

**Backend (Spring Boot):**
- [x] `Payment`, `CartItem`, and `MonthlyStatement` entities exist (`entity/Payment.java`, `entity/CartItem.java`, `entity/MonthlyStatement.java`).
- [x] API `POST /api/v1/payment/create` to generate a PayOS checkout link + QR code (`PaymentController`/`PaymentServiceImpl.createPayment`).
- [x] API `POST /api/v1/payment/payos-webhook` to receive the PayOS webhook and verify the HMAC-SHA256 signature (`PaymentServiceImpl.handlePayOSWebhook`).
- [x] Auto-Enrollment logic: upon a verified `"00"` success webhook, automatically create `Enrollment` records for every course in the payment, clear the matching Cart items, and send a `PurchaseSuccess` notification to the learner plus a `NewEnrollment` notification to each course's trainer.
- [x] `PaymentExpirationScheduler` (`@Scheduled`, every 15 min) auto-expires `PENDING` payments older than 30 minutes.
- [ ] Cron job (`@Scheduled`) to automatically generate `MonthlyStatement` records at the end of each month — still a manual, on-demand trigger (`MonthlyStatementServiceImpl.generateMonthlyCutoff`) called via `POST /api/v1/course-manager/statements/generate`, not yet scheduled.
- [x] API for Course Managers to mark Monthly Statements as `PAID` after manual bank transfers (`POST /api/v1/course-manager/statements/{id}/settle`); fires a `StatementReady` notification to the trainer when a statement is generated, and an email when it is settled.

## 3. Technical Constraints
- **Idempotency:** The PayOS webhook is idempotent — `handlePayOSWebhook` uses a pessimistic-write lock (`findByTxnRefWithLock`) and short-circuits if the payment's status is already `SUCCESS`, so a duplicated webhook delivery never creates duplicate Enrollments or revenue records.
- **Transaction:** Webhook processing runs inside `@Transactional` so the Payment status update and Enrollment creation succeed together.

## 4. Edge Cases
- **Free Courses:** Bypass the entire Cart/Payment flow. Free (or non-existent-price) courses enroll directly via `CourseServiceImpl.enrollCourse`, which also fires a `NewEnrollment` notification.
- **Signature Failure:** If the PayOS webhook signature is invalid, `handlePayOSWebhook` throws and rejects the request without touching any Payment row.
- **Multi-course checkout:** A single Payment can cover several courses at once (`Payment.courseIds`, a CSV of course IDs) — the webhook loops over all of them for enrollment/notification/cart-cleanup.

## 5. Non-functional Requirements
- **Reliability:** Payments directly affect revenue. Ensure robust error logging and monitoring for the PayOS webhook endpoint.

## 6. Test Coverage
Service-layer unit tests: `PaymentServiceImplTest` (webhook signature/idempotency/revenue-split/notifications, payment status, payment history — `createPayment` itself is not unit-tested because it calls the live PayOS HTTP API via an inline `new RestTemplate()`, not an injectable client), `CartServiceImplTest`, `MonthlyStatementServiceImplTest`. See `doc/specs/utc-sheet-payment.csv`.
