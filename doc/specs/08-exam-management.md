# Feature Specification: FE-08 — Exam Management

> Ref: [HanGo_Documentation.md](../HanGo_Documentation.md) §7.8 (EXM)

## 1. Business Context
Exam is **independent of Course** — it simulates the latest THPTQG English exam and is created by **Trainer or Course Manager** (Course Manager can self-publish; Trainer's exam needs Course Manager approval — FR-EXM-01/03). Exam Questions are **created specifically for the Exam** — they are *not* pulled from / shared with the reusable Question Bank used by Quiz (BR-G07). Format is **fixed, not configurable**: **40 questions / 50 minutes / scale of 10** (0.25 pt per question), single-choice (BR-EXM-01). There is no pass/fail threshold — only a numeric score. For the Learner, this is an interface featuring a countdown timer, test execution, and automatic scoring immediately upon submission, with **unlimited retakes** (BR-G08).

## 2. Acceptance Criteria

**Frontend (Flutter):**
- [ ] Exam Builder interface for Trainer/Course Manager: author exam-specific questions (not reused from the shared Question Bank); duration/question-count are fixed at 40Q/50min, not editable per exam.
- [ ] Exam Execution interface for Learners: Display countdown timer synced against server `end_time`. Auto-submit when time is up.
- [ ] Local caching of answers (Local Storage/SharedPreferences) to prevent data loss if the app crashes during the exam.
- [ ] Result screen displaying the score (0–10 scale), correct/incorrect per question, and explanations.
- [ ] Attempt history view within the Exam detail page (unlimited retakes).

**Backend (Spring Boot):**
- [ ] API `POST /api/v1/exams` to create the exam structure (`exams`, `exam_versions`, `exam_questions` — private to the Exam).
- [ ] API `POST /api/v1/exams/{id}/submit` to receive the array of user answers (`learner_id`, `question_id`, `chosen_answer_id`).
- [ ] Auto-grading logic based on the `is_correct` field, 0.25 pt/question, scale of 10.
- [ ] Record the results into the `exam_attempts` table (score on a 0–10 scale, per-question correctness — no PASS/FAIL status).

## 3. Technical Constraints
- **Exam Question Privacy:** Exam questions must have `Visibility = Private` and be scoped strictly to a specific `ExamVersion` (mapped via `exam_version_id`), ensuring they cannot be pulled into general course quizzes.
- **Backend Scoring Validation:** The Submit API must evaluate options using the `is_correct` field in the `question_options` table.
- **Frontend Security:** The countdown timer must calculate the remaining duration based on the server-provided start time, not trusting the client device clock.

## 4. Edge Cases
- **Loss of Connection During Exam:** Cache answers locally. When the connection is restored, sync answers or submit on connection recovery.
- **Time's Up auto-submit:** The client must trigger an API submission immediately when the timer expires. The server will reject submissions that exceed the duration window by more than 1 minute.
- **Double Submit:** Prevent a learner from submitting the same exam attempt twice via locks.

## 5. Non-functional Requirements
- **Performance:** Submit and scoring API must return the results in `< 1000ms`.
- **Security:** Do not expose the correct options/answers payload in the API response while the exam attempt is still in progress.

