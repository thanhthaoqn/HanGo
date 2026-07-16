# Feature Specification: FT-06 - Exam Management

## 1. Business Context
The Exam Management feature is a tool to measure and evaluate the competency of Learners. In contrast to quizzes, Exams are simulated English THPTQG mock tests, utilizing dedicated exam questions that are private and not reusable in standard courses. For the Learner, this is an interface featuring a countdown timer, test execution, and automatic scoring immediately upon submission.

## 2. Acceptance Criteria

**Frontend (Flutter):**
- [ ] Exam listing screen displaying available exams.
- [ ] Exam Builder interface for Course Managers/Trainers to create exams and attach dedicated questions.
- [ ] Exam Execution interface for Learners: 50-minute countdown timer. Auto-submit when time is up.
- [ ] Local caching of answers (SharedPreferences) to prevent data loss if the app crashes during the exam.
- [ ] Result screen displaying the score on a 10-point scale, total correct/incorrect answers, and explanations.

**Backend (Spring Boot):**
- [ ] API `GET /api/v1/exams` to retrieve the list of exams.
- [ ] API `GET /api/v1/exams/{id}/attempts` and `/api/v1/exams/my-attempts` to fetch learner attempts.
- [ ] API `POST /api/v1/exams/{id}/submit` receiving the array of user answers in an `ExamAttemptRequestDTO`.
- [ ] Auto-grading logic: each correct answer yields exactly 0.25 points (40 questions total, max score 10).
- [ ] Record the attempt details in the `exam_attempts` table (with score, start time, and submission time).

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

