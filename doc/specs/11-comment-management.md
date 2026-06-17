# Feature Specification: FT-11 - Comment Management

## 1. Business Context
Learning requires interaction (Community). The Comment System allows Learners to ask questions and discuss directly under each lesson, receiving answers from Trainers or other Learners. This feature establishes a Q&A model similar to major MOOC platforms (Udemy, Coursera).

## 2. Acceptance Criteria

**Frontend (Flutter):**
- [ ] Comment list interface below the lesson.
- [ ] Input field for comment text (with character limit), Submit button.
- [ ] Display nested comments (Root Comment -> Replies).
- [ ] "Delete" or "Edit" button if the current user is the author of that comment.

**Backend (Spring Boot):**
- [ ] API `POST /api/v1/lessons/{id}/comments` to write a root comment.
- [ ] API `POST /api/v1/comments/{id}/replies` to reply to a comment.
- [ ] API `GET /api/v1/lessons/{id}/comments` with pagination (Pageable) including nested replies.
- [ ] Authorization: Trainer/Lead has the right to delete any comment within their course. Learners can only delete their own comments.

## 3. Technical Constraints
- **Database:** The `comments` table must support a tree structure using a `parent_id` column (Self-referencing relationship).
- **Frontend:** Rendering nested comments can use a Recursive Widget or limit the depth to just 1 level of replies to simplify the UI.
- **Backend:** Map data from DB (Flat list) into a Nested DTO (Parent comment containing a list of child comments) before returning. Avoid N+1 query issues by using `JOIN FETCH` or graph libraries.

## 4. Edge Cases
- **Toxic Content:** The system blocks prohibited keywords (Bad words filter) at the Backend before saving to the DB.
- **Deleting a parent comment:** How should child comments (Replies) be handled? (Option 1: Domino effect deletion - Cascade. Option 2: Hide the parent comment text as "This comment has been deleted" but keep the child comments. *Recommendation: Use Option 2 via Soft Delete*).
- **Comment Spamming:** Set a limit where 1 user can post a maximum of 3 comments per minute (Rate limit).

## 5. Non-functional Requirements
- **Performance:** Loading the comment page must not be slower than loading the lesson video. (API response < 300ms).
- **Security:** Incoming DTOs must use a library to escape HTML/Javascript (preventing XSS Attacks). Never trust user input.
