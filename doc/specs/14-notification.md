# Feature Specification: FT-14 - Notification

## 1. Business Context
The Notification system helps retain users (Retention) by reminding them of important events. The system will send notifications when a new course is published, when a payment succeeds, when someone replies to your comment, or when monthly statements/onboardings status are updated.

## 2. Acceptance Criteria

**Frontend (Flutter):**
- [ ] Notification Bell Icon on the AppBar, attaching a red Badge counting the number of unread notifications.
- [ ] Clicking the Bell opens a notification list screen.
- [ ] Real-time STOMP/WebSocket client connection to listen to user-specific queues.
- [ ] Clicking a notification marks it as "Read" and triggers navigation.

**Backend (Spring Boot):**
- [ ] `notifications` table containing columns: `id`, `user_id`, `title`, `content`, `type`, `is_read`, `created_at`.
- [ ] WebSocket config using STOMP message broker.
- [ ] API `GET /api/v1/notifications` (Fetch paginated list of notifications for the current user).
- [ ] API `PUT /api/v1/notifications/{id}/read` (Mark as read).
- [ ] Event-driven notification publisher: send notifications asynchronously (`@Async`) when database triggers occur (PurchaseSuccess, CourseUpdated, CommentReply, NewEnrollment, ContentApproved, ContentRejected, StatementReady).
- [ ] Send async emails using `JavaMailSender` for OTP verify, password reset, purchase confirmations, and trainer activation.

## 3. Technical Constraints
- **Backend Design:** Avoid tightly coupling notification generation logic with the main business logic. Must use **Spring ApplicationEventPublisher** (Observer Pattern) to publish notification events asynchronously (`@Async`).
- **Real-time Transport:** Standard transport must use WebSockets with automatic connection recovery under network loss. Polling is kept as a fallback logic.

## 4. Edge Cases
- **Deleted Resources Linked to Notifications:** If resources are deleted, wrap navigation in try-catch on the frontend and show a toast warning.

## 5. Non-functional Requirements
- **Performance:** WebSocket notifications must trigger in `< 500ms` of event publication.
- **Asynchronous Execution:** Email delivery tasks must run in isolated thread pools so they do not block main API request/response threads.

