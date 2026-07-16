# Feature Specification: FE-14 — Notification

> Ref: [HanGo_Documentation.md](../HanGo_Documentation.md) §7.14 (NTF)

## 1. Business Context
The Notification system helps retain users by reminding them of important events, delivered **realtime in-app via WebSocket** plus email for critical events (FR-NTF-01/04 — this is a decided v1 requirement, not optional). Triggers for **Learner**: PurchaseSuccess, CourseUpdated, CommentReply. Triggers for **Trainer**: NewEnrollment, CommentReply, ContentApproved, ContentRejected, StatementReady (FR-NTF-02/03). There is no "Task"/"Lead" concept in HanGo.

## 2. Acceptance Criteria

**Frontend (Flutter):**
- [ ] Notification Bell Icon on the AppBar, attaching a red Badge counting the number of unread notifications.
<<<<<<< HEAD
- [ ] Clicking the Bell opens a notification list screen.
- [ ] Real-time STOMP/WebSocket client connection to listen to user-specific queues.
- [ ] Clicking a notification marks it as "Read" and triggers navigation.
**Backend (Spring Boot):**
- [ ] `notifications` table containing columns: `id`, `user_id`, `title`, `content`, `type` (`NotificationType` enum: PurchaseSuccess · CourseUpdated · CommentReply · NewEnrollment · ContentApproved · ContentRejected · StatementReady), `is_read`, `created_at`.
- [ ] Spring Boot **WebSocket** (STOMP) endpoint to push notifications to the owning user's queue in realtime.
- [ ] API `GET /api/v1/notifications` (Fetch paginated list of notifications for the current user).
- [ ] API `PUT /api/v1/notifications/{id}/read` (Mark as read).
- [ ] Automated Notification Logic via `ApplicationEventPublisher`, e.g.: payment succeeds → PurchaseSuccess to Learner; Learner enrolls → NewEnrollment to Trainer; Course Manager approves/rejects content → ContentApproved/ContentRejected to Trainer; Monthly Statement generated → StatementReady to Trainer; someone replies to a comment → CommentReply to the parent comment's author.
- [ ] `JavaMailSender` for email on critical events: OTP verification, reset password, purchase success, Trainer application approved (FR-NTF-04).

## 3. Technical Constraints
- **Backend Design:** Avoid tightly coupling notification generation logic with the main business logic. Must use **Spring ApplicationEventPublisher** (Observer Pattern) to publish notification events asynchronously (`@Async`), avoiding slowing down the main API.
- **Frontend:** Realtime delivery is via WebSocket (STOMP), per the platform's decided architecture ([ARCHITECTURE.md](../ARCHITECTURE.md) §2) — polling is not used in v1.
>>>>>>> db59d10 (unit test)

## 4. Edge Cases
- **Deleted Resources Linked to Notifications:** If resources are deleted, wrap navigation in try-catch on the frontend and show a toast warning.
## 5. Non-functional Requirements
- **Performance:** WebSocket notifications must trigger in `< 500ms` of event publication.
- **Asynchronous Execution:** Email delivery tasks must run in isolated thread pools so they do not block main API request/response threads.

