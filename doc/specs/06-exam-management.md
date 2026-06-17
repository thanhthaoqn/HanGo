# Feature Specification: FT-06 - Exam Management

## 1. Business Context
The Exam Management feature is a tool to measure and evaluate the competency of Learners. It allows linking questions from the Question Bank into an exam, defining time limits, and setting passing scores. For the Learner, this is an interface featuring a countdown timer, test execution, and automatic scoring immediately upon submission.

## 2. Acceptance Criteria

**Frontend (Flutter):**
- [ ] Exam Builder interface for Trainers (select questions from the Bank, set time, passing score).
- [ ] Exam Execution interface for Learners: Display countdown timer. Auto-submit when time is up.
- [ ] Local caching of answers (Local Storage/SharedPreferences) to prevent data loss if the app crashes during the exam.
- [ ] Result screen displaying the score, total correct/incorrect, and detailed explanations (if configured to allow).

**Backend (Spring Boot):**
- [ ] API `POST /api/v1/exams` to create the exam structure (`exams` and `exam_questions`).
- [ ] API `POST /api/v1/exams/{id}/submit` to receive the array of user answers (`learner_id`, `question_id`, `chosen_answer_id`).
- [ ] Auto-grading logic based on the `is_correct` field in the `answers` table.
- [ ] Record the results into the `exam_attempts` table (score, PASS/FAIL status).

## 3. Technical Constraints
- **Frontend:** The countdown timer must calculate the time difference against the `end_time` returned by the server, not relying entirely on the local device time to prevent Learners from hacking by rewinding the device clock.
- **Backend:** 
  - The Submit API must lock the attempt data to prevent a user from submitting twice for the same exam attempt.
  - Must clearly separate the Request DTO containing chosen answers from the system's server-side verification of correct answers (Never send correct answers to the Client during an exam).

## 4. Edge Cases
- **Loss of Connection During Exam:** Cache answers locally. When the connection is restored, silently sync answers to the server (if Auto-save is designed) or allow submission when the connection is stable.
- **Time's Up but Not Submitted:** The Flutter Timer function automatically triggers an API `submit` call with the answers currently in the Cache.
- **Submitting Beyond the Time Limit:** The server checks `current_time` against `start_time + time_limit`. If it exceeds the allowed tolerance (e.g., 1 minute for network delay), mark the exam Invalid or score 0 for the late submission.

## 5. Non-functional Requirements
- **Performance:** The Submit API must process and return the score instantaneously in `< 1000ms`.
- **Concurrency (Load Bearing):** Capable of handling hundreds of concurrent submit requests when a common exam ends (Effectively utilizing Connection Pooling in the database).
- **Security:** Strictly prohibit any API calls attempting to fetch question details meant for Admin/Trainers while the account role is Learner.
