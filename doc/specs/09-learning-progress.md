# Feature Specification: FT-09 - Learning Progress

## 1. Business Context
The system needs to provide Learners with the ability to track the Learning Progress of each course they are enrolled in. This helps motivate learning (Gamification), ensuring learners know exactly what percentage they have completed and what part they need to study next. For the Trainer/Lead, this is core data to evaluate course effectiveness.

## 2. Acceptance Criteria

**Frontend (Flutter):**
- [ ] "My Courses" screen displaying the list of enrolled courses along with a Progress Bar (completion percentage).
- [ ] Lesson details interface features a "Mark as Completed" button.
- [ ] Auto-navigate to the next lesson (Next Lesson) when marked as completed successfully.

**Backend (Spring Boot):**
- [ ] API `POST /api/v1/courses/{id}/enroll` to enroll (insert into `learner_courses` table).
- [ ] API `PUT /api/v1/lessons/{id}/complete` to record lesson completion in the `learning_progress` table.
- [ ] `ProgressService` class calculates the total completion percentage (Lessons completed / Total lessons in Course) and updates the `progress_percent` column in the `learner_courses` table.

## 3. Technical Constraints
- **Frontend:** Prevent spam-clicking the "Mark as Completed" button. Save the state locally (hide or disable the button after completion is marked). 
- **Backend:** 
  - Lock the table when calculating percentages using JPA `@Lock(LockModeType.PESSIMISTIC_WRITE)` if there is a risk of race conditions (e.g., User calls the complete lesson API twice within a millisecond).
  - Return a DTO containing the completion status of each `Lesson` when fetching `Course` details for the Learner.

## 4. Edge Cases
- **Learner wants to unmark completion:** Either do not support this, or (if business requires) allow "Unmark" which means the percentage calculation algorithm must run again and decrease the percentage.
- **Trainer deletes a lesson someone already completed:** When a `Lesson` is deleted, trigger a Spring Event or DB Trigger to rerun the percentage calculation algorithm for all Learners currently taking that course. This prevents the percentage from exceeding 100% or having an inaccurate count.

## 5. Non-functional Requirements
- **Consistency:** Percentage data must not be inaccurate.
- **Performance:** Percentage calculation must execute extremely fast `< 100ms`, or run asynchronously in a background job if a course has thousands of learners.
