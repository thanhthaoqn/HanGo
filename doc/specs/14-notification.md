# Feature Specification: FE-14 — Notification

> Ref: [HanGo_Documentation.md](../HanGo_Documentation.md) §7.14 (NTF)

## 1. Business Context
The Notification system helps retain users by reminding them of important events. **v1 is REST/polling-based, not realtime** — the frontend fetches the list and unread count on demand (bell click, page load), there is no WebSocket/STOMP push yet (that remains a documented future enhancement, see §3). Triggers implemented for **Learner**: PurchaseSuccess, CommentReply, CourseUpdated. Triggers implemented for **Trainer**: NewEnrollment, CommentReply, ContentApproved, ContentRejected, StatementReady (FR-NTF-02/03). There is no "Task"/"Lead" concept in HanGo. A separate role-broadcast mechanism (not per-user) still covers Course Manager low-rating alerts (`LOW_RATING` / `LOW_AVERAGE_RATING`), unchanged from the original design.

## 2. Acceptance Criteria

**Frontend (Flutter):**
- [x] Notification Bell Icon on the AppBar (`shared_header.dart`), with a red badge counting unread notifications.
- [x] Clicking the Bell opens a dropdown notification list (in-place popup, not a separate screen in v1).
- [ ] Real-time STOMP/WebSocket client connection to listen to user-specific queues — not implemented; the bell refreshes on open and after login instead.
- [x] Clicking a notification marks it as "Read" (no cross-page navigation yet — Edge Case below covers why this is deferred).

**Backend (Spring Boot):**
- [x] `notifications` table containing: `id`, `user_id` (nullable — per-user target), `recipient_role` (nullable — role-broadcast target, mutually exclusive with `user_id`), `title`, `message`, `type` (free-form `String`, not yet a DB enum: `PurchaseSuccess` · `CourseUpdated` · `CommentReply` · `NewEnrollment` · `ContentApproved` · `ContentRejected` · `StatementReady` · `LOW_RATING` · `LOW_AVERAGE_RATING`), `is_read`, `created_at`, `course_id` (optional FK for deep-linking).
- [ ] Spring Boot WebSocket (STOMP) endpoint — not implemented (Planned).
- [x] API `GET /api/v1/notifications` (paginated list of notifications visible to the current user — targeted-at-them OR broadcast to one of their roles).
- [x] API `GET /api/v1/notifications/unread-count`.
- [x] API `PUT /api/v1/notifications/{id}/read` (mark one as read; ownership/role-membership enforced in `NotificationService.markAsRead`).
- [x] API `PUT /api/v1/notifications/read-all` (bulk mark-as-read for the current user).
- [x] Automated Notification Logic wired directly into the relevant services (see below) — not yet migrated to `ApplicationEventPublisher` (see §3).
- [x] `JavaMailSender` for email on critical events: OTP verification, reset password, purchase success, Trainer application approved/rejected, statement settled (`EmailService`) — these run independently of the in-app `NotificationService`.

**Trigger wiring (current code, all via direct `NotificationService.notifyUser(...)` calls):**
| Trigger | Source | Recipient |
|---|---|---|
| `PurchaseSuccess` | `PaymentServiceImpl.handlePayOSWebhook` (successful webhook) | Learner who paid |
| `NewEnrollment` | `PaymentServiceImpl.handlePayOSWebhook`, `CourseServiceImpl.enrollCourse` (free courses) | Course creator (Trainer) |
| `CommentReply` | `CommentServiceImpl.addComment` (when replying to someone else's comment) | Parent comment's author |
| `ContentApproved` | `CourseManagerDashboardServiceImpl.publishCourse` / `publishExam` | Course/Exam creator |
| `ContentRejected` | `CourseManagerDashboardServiceImpl.returnCourseToDraft` / `returnExamToDraft` | Course/Exam creator |
| `CourseUpdated` | `CourseManagerDashboardServiceImpl.publishCourse` (when publishing a new version) | Every learner enrolled in a prior version |
| `StatementReady` | `MonthlyStatementServiceImpl.generateMonthlyCutoff` | Trainer the statement was generated for |
| `LOW_RATING` / `LOW_AVERAGE_RATING` | `CourseRatingServiceImpl` | Role-broadcast to `TRAINER_LEAD` (unchanged legacy behavior) |

## 3. Technical Constraints
- **Backend Design:** The original design called for decoupling notification generation via **Spring ApplicationEventPublisher** (Observer Pattern), published asynchronously (`@Async`). The current implementation calls `NotificationService` directly from each business-logic service instead — simpler, but couples notification code into the business methods. Revisiting this with an event-publisher refactor is a known follow-up, not required for v1 correctness.
- **Frontend:** Realtime delivery via WebSocket (STOMP) remains the target architecture per [ARCHITECTURE.md](../ARCHITECTURE.md) §2, but v1 ships with polling (fetch-on-open) instead, to keep scope bounded.

## 4. Edge Cases
- **Deleted Resources Linked to Notifications:** If the linked `course` is deleted, the notification is still returned (courseId/courseTitle become null in the DTO) — the frontend does not yet attempt navigation on click, only marks-as-read, precisely to sidestep this dangling-reference case until a list/detail page is built.
- **Role-broadcast read state:** A role-broadcast notification (e.g. `LOW_RATING` to `TRAINER_LEAD`) has a single shared `is_read` flag — if one Course Manager reads it, it shows as read for all Course Managers. Acceptable given the role is held by a small team in practice; per-user read-receipts for broadcasts are out of scope for v1.

## 5. Non-functional Requirements
- **Performance:** Not applicable in v1 (no WebSocket push). List/unread-count endpoints are paginated to bound response size as notification volume grows.
- **Asynchronous Execution:** Email delivery (`EmailService`) already runs wrapped in try/catch at each call site so a mail failure never blocks the triggering request; it is not yet on a dedicated async thread pool.

## 6. Test Coverage
Service-layer unit tests: `NotificationServiceTest` (notifyCourseManagers, notifyUser, list/unread-count/mark-as-read/mark-all-as-read including ownership checks for both per-user and role-broadcast notifications). Trigger wiring is covered by the tests of the services that fire them: `CourseManagerDashboardServiceTest` (ContentApproved/ContentRejected/CourseUpdated), `CommentServiceImplTest` (CommentReply), `PaymentServiceImplTest` (PurchaseSuccess/NewEnrollment), `MonthlyStatementServiceImplTest` (StatementReady). See `doc/specs/utc-sheet-notification.csv`.
