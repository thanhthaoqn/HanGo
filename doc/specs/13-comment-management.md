# Feature Specification: FE-13 — Comment Management

> Ref: [HanGo_Documentation.md](../HanGo_Documentation.md) §7.13 (CMT)

## 1. Business Context
Learning requires interaction (Community). The Comment System allows Learners and Trainers to ask questions and discuss directly under a **Lesson or Quiz** (BR-CMT-01) — Course level only supports Rating, not comments. This feature establishes a Q&A model similar to major MOOC platforms (Udemy, Coursera).

There is **no AI moderation** in v1.0. Instead, every submitted comment goes through a simple **Rule Engine**: text normalization + blacklist keywords + regex patterns, which assigns the comment a status without any human/AI judgment call at submission time. Admin only reviews what the Rule Engine flags as suspicious (`PENDING`), plus anything already `REJECTED`/`APPROVED` if they want to override it.

## 2. Comment Workflow

1. **Normalize** the raw text (`CommentRuleEngineService.normalize`):
   - lowercase
   - remove Vietnamese accents (NFD decomposition + `đ`→`d`)
   - collapse extra whitespace
   - normalize common special-character substitutions used to dodge filters (`0/@`→`o`, `1`→`i`, `3`→`e`, `4`→`a`, `5/$`→`s`, `7`→`t`)
2. **Check blacklist keywords** (whole-word match on the normalized text) and **regex patterns** (phone number / URL / email / off-platform-contact solicitation, checked on the whitespace-collapsed original text since these rely on digits/symbols that the leetspeak-normalization step would otherwise scramble).
3. **Determine status**:
   - No match → **`APPROVED`** → visible immediately to everyone.
   - Regex pattern matched (suspicious, not necessarily offensive) → **`PENDING`** → hidden from other users; visible only to the author; waiting for Admin review.
   - Blacklist keyword matched (offensive) → **`REJECTED`** → hidden from everyone, **including the author** (no exception — the toast message at submit time is the only feedback the author gets; the comment itself never reappears in the thread, unlike `PENDING`).
4. The same evaluation runs on **both create and edit** (`addComment` / `updateComment` in `CommentServiceImpl`) so a user can't post a clean comment and later edit in a blacklisted word to bypass the check.

**Status values:** `APPROVED` · `PENDING` · `REJECTED` (stored as-is in `comments.status`, matching the values the existing `AdminCommentController` already expected).

## 3. Acceptance Criteria

**Frontend (Flutter):**
- [x] Comment list interface below the lesson/quiz (`lesson_detail_page.dart` → `_buildCommentsSection`).
- [x] Input field for comment text, Submit button; nested Root → Reply, likes/unlikes.
- [x] After posting/replying, show the moderation outcome: silent for `APPROVED`, a neutral toast ("awaiting moderation, visible only to you") for `PENDING`, an error toast ("violates community guidelines") for `REJECTED`.
- [x] Admin **Comment Management** screen (`comment_management_page.dart`): Lesson/Quiz tabs, search, status filter, table with Course / Lesson-Quiz / Status / Created columns, per-row **View Detail** and **Delete**, quick Approve/Reject via the status chip.
- [x] **Comment Detail** dialog: Original Comment, Normalized Comment, Detection Reason, Current Status, Created By, Created Time, with Approve / Reject / Delete actions.

**Backend (Spring Boot):**
- [x] `POST /api/v1/comments/lesson/{lessonId}` — root or reply (via `parentCommentId`) comment on a Lesson/Quiz; runs the Rule Engine and persists `status` + `normalizedContent` + `detectionReason`.
- [x] `GET /api/v1/comments/lesson/{lessonId}` — returns `APPROVED` comments to everyone, plus the caller's own `PENDING`/`REJECTED` comments (`CommentServiceImpl.isVisibleTo`).
- [x] `PUT /api/v1/comments/{id}` (edit), `DELETE /api/v1/comments/{id}` — own comment only.
- [x] `GET /api/admin/comments` — moderation list (`@PreAuthorize("hasRole('ADMINISTRATOR')")`), now includes `course` (resolved via `lesson.section.course`), `quizOrLesson`, `normalizedContent`/`detectionReason` are on the detail endpoint only (kept off the list payload to stay lightweight).
- [x] `GET /api/admin/comments/{id}` — Comment Detail (original + normalized + detection reason + status + author + created time).
- [x] `PUT /api/admin/comments/{id}/status` — Approve/Reject.
- [x] `DELETE /api/admin/comments/{id}` — Admin can delete any comment.

## 4. Technical Constraints
- **Database Schema:** `comments` table: self-referential tree via `parent_comment_id`; `user_id` + `lesson_id` (optional `course_id`, used only if a comment is ever attached directly to a Course rather than a Lesson — current UI never does this per BR-CMT-01); new columns `normalized_content` (TEXT) and `detection_reason` (VARCHAR 255), added via `spring.jpa.hibernate.ddl-auto=update` (no manual migration needed).
- **Rule Engine is intentionally simple/hardcoded (`CommentRuleEngineService`)**: blacklist keywords and regex patterns are Java constants, not an admin-configurable table — matches the "simple Rule Engine" scope in the spec; if the team later wants Admin to edit the blacklist from the UI, that's a follow-up, not v1.0.
- **XSS Prevention:** Escape input strings and sanitize content before persisting to prevent HTML/Javascript injection attacks. *(Not yet implemented — see Edge Cases.)*

## 5. Edge Cases
- **Deleted Parent Comment:** Keep the parent comment node to preserve the tree structure but mask the content as "This comment has been deleted". *(Not yet implemented — `deleteComment` currently hard-deletes the row; a reply whose parent was deleted will show a broken `parentCommentId` reference. Flag for dev if nested-thread integrity matters before launch.)*
- **Spam Control:** Enforce basic rate-limiting rules. *(Not yet implemented.)*
- **Own PENDING/REJECTED comment editing:** if a user edits a `REJECTED` comment and it now passes the Rule Engine, it flips back to `APPROVED` automatically (same `evaluate()` call path) — there's no "resubmit for review" step, it's just re-evaluated like a fresh comment.
- **Accent-stripping causes genuine word collisions — an inherent trade-off of BR step "remove Vietnamese accents", not a bug:** e.g. `cặc` (profanity) and `các` (extremely common word, "everyone/all") both normalize to `cac`; `đéo` (profanity) and `đeo` ("to wear") both normalize to `deo`; `lồn` (profanity) and `lon` ("can/tin", as in "một lon nước") both normalize to `lon`. `CommentRuleEngineService.BLACKLIST_KEYWORDS` deliberately **excludes** `cac` (too high a false-positive rate — would reject a huge fraction of normal Vietnamese comments) but does include `lon`/`deo`, accepting a lower, situational false-positive rate for those. If Admin reports too many false `REJECTED`/`PENDING` hits, the fix is to prune the specific offending keyword from that list, not to change the normalization approach.

## 6. Non-functional Requirements
- **Performance:** Fetching thread comments must respond in `< 300ms`.
