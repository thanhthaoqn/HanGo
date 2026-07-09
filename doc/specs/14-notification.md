# Feature Specification: FT-14 - Notification

## 1. Business Context
The Notification system helps retain users (Retention) by reminding them of important events. The system will send notifications when a new course is published, when a Task deadline is approaching, or when someone replies to your comment.

## 2. Acceptance Criteria

**Frontend (Flutter):**
- [ ] Notification Bell Icon on the AppBar, attaching a red Badge counting the number of unread notifications.
- [ ] Clicking the Bell opens a notification list screen/BottomSheet.
- [ ] Unread notifications are bolded or have a different background color. Clicking a notification marks it as "Read" and navigates to the corresponding screen.

**Backend (Spring Boot):**
- [ ] `notifications` table containing columns: `id`, `user_id`, `title`, `content`, `type` (COURSE, TASK, COMMENT), `is_read`, `created_at`.
- [ ] API `GET /api/v1/notifications` (Fetch paginated list of notifications for the current user).
- [ ] API `PUT /api/v1/notifications/{id}/read` (Mark as read).
- [ ] Automated Notification Logic: e.g., when a Lead creates a new Task -> Auto-insert 1 row into the `notifications` table for the `assigned_to` user.

## 3. Technical Constraints
- **Backend Design:** Avoid tightly coupling notification generation logic with the main business logic. Must use **Spring ApplicationEventPublisher** (Observer Pattern) to publish notification events asynchronously (`@Async`), avoiding slowing down the main API.
- **Frontend:** Counting unread notifications can be done periodically (Polling) every 1 minute using a Flutter `Timer`, or via WebSocket/SSE for Real-time. Temporarily prioritize Polling for easier initial deployment.

## 4. Edge Cases
- **Too Many Unread Notifications:** The counter badge on the Bell maxes out at `99+` to prevent UI layout breaking.
- **Deleted Resources Linked to Notifications:** e.g., Notification says "Course A released", but Course A is subsequently deleted. Clicking the notification causes an error.
  - *Solution:* Frontend needs to wrap navigation in a `try-catch` block. If the API returns 404 Not Found, show a Toast: "This content no longer exists."

## 5. Non-functional Requirements
- **Performance:** Fetch notification APIs must be extremely lightweight (< 100ms) because they are called very frequently whenever the User opens the app.
- **Scalability:** The current In-app notification system is designed so that a Push Notification module (FCM - Firebase Cloud Messaging) can be easily attached later to push notifications outside to the phone's lock screen.
