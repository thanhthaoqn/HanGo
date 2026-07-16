# Feature Specification: FE-13 — Comment Management

> Ref: [HanGo_Documentation.md](../HanGo_Documentation.md) §7.13 (CMT)

## 1. Business Context
Learning requires interaction (Community). The Comment System allows Learners and Trainers to ask questions and discuss directly under a **Lesson or Quiz** (BR-CMT-01) — Course level only supports Rating, not comments. This feature establishes a Q&A model similar to major MOOC platforms (Udemy, Coursera).

## 2. Acceptance Criteria

**Frontend (Flutter):**
<<<<<<< HEAD
- [ ] Comment list interface below the lesson/quiz.
- [ ] Input field for comment text, Submit button.
- [ ] Display nested comments (Root Comment -> Replies), supporting likes/unlikes.

**Backend (Spring Boot):**
- [ ] API `POST /api/v1/lessons/{id}/comments` (and equivalent for Quiz) to write a root comment.
- [ ] API `POST /api/v1/comments/{id}/replies` to reply to a comment.
- [ ] API `GET /api/v1/lessons/{id}/comments` with pagination (Pageable) including nested replies.
- [ ] Authorization: a user may edit/delete only their **own** comment (Learner and Trainer have equal standing here — a Trainer has no special delete right over other users' comments on their own course). Only **Administrator** can moderate — hide/delete any comment (FR-CMT-04) — via `DELETE /api/v1/admin/comments/{id}`.
>>>>>>> db59d10 (unit test)

## 3. Technical Constraints
- **Database Schema:** The `comments` table supports self-referential tree structure using `parent_comment_id`. It maps to `user_id` and `lesson_id` (or course rating entities).
- **XSS Prevention:** Escape input strings and sanitize content before persisting to prevent HTML/Javascript injection attacks.

## 4. Edge Cases
- **Deleted Parent Comment:** Keep the parent comment node to preserve the tree structure but mask the content as "This comment has been deleted".
- **Spam Control:** Enforce basic rate-limiting rules.

## 5. Non-functional Requirements
- **Performance:** Fetching thread comments must respond in `< 300ms`.

