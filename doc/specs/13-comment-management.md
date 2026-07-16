# Feature Specification: FT-11 - Comment Management

## 1. Business Context
Learning requires interaction (Community). The Comment System allows Learners to ask questions and discuss directly under each lesson, receiving answers from Trainers or other Learners. This feature establishes a Q&A model similar to major MOOC platforms.

## 2. Acceptance Criteria

**Frontend (Flutter):**
- [ ] Comment list interface below the lesson/quiz.
- [ ] Input field for comment text, Submit button.
- [ ] Display nested comments (Root Comment -> Replies), supporting likes/unlikes.
- [ ] Admin panel interface to review and moderate comments.

**Backend (Spring Boot):**
- [ ] API `GET /api/v1/comments/lesson/{lessonId}` to fetch the comment thread (uses `JOIN FETCH` to prevent N+1 queries).
- [ ] API `POST /api/v1/comments/lesson/{lessonId}` to post a comment or reply (with user ID).
- [ ] API `PUT /api/v1/comments/{commentId}` and `DELETE /api/v1/comments/{commentId}` to edit/delete.
- [ ] API `POST /api/v1/comments/{commentId}/like` and `POST /api/v1/comments/{commentId}/unlike`.
- [ ] Admin APIs: `GET /api/admin/comments` (list all comments) and `PUT /api/admin/comments/{id}/status` to approve/reject comments.

## 3. Technical Constraints
- **Database Schema:** The `comments` table supports self-referential tree structure using `parent_comment_id`. It maps to `user_id` and `lesson_id` (or course rating entities).
- **Backend Optimization:** Queries must load recursively or map flat results into tree DTO structures (containing child comments) before returning to the UI to optimize performance.
- **XSS Prevention:** Escape input strings and sanitize content before persisting to prevent HTML/Javascript injection attacks.

## 4. Edge Cases
- **Deleted Parent Comment:** Keep the parent comment node to preserve the tree structure but mask the content as "This comment has been deleted".
- **Spam Control:** Enforce basic rate-limiting rules.

## 5. Non-functional Requirements
- **Performance:** Fetching thread comments must respond in `< 300ms`.

