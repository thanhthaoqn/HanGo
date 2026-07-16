# Feature Specification: FT-09 - Learning Progress

## 1. Business Context
The system needs to provide Learners with the ability to track the Learning Progress of each course they are enrolled in. This helps motivate learning (Gamification), ensuring learners know exactly what percentage they have completed and what part they need to study next. For the Trainer/Lead, this is core data to evaluate course effectiveness.

## 2. Acceptance Criteria

**Frontend (Flutter):**
- [ ] "My Courses" screen displaying the list of enrolled courses along with a Progress Bar (completion percentage).
- [ ] Lesson details interface features a "Mark as Completed" button.
- [ ] Auto-navigate to the next lesson when marked as completed successfully, unlocking the next lesson sequence.

**Backend (Spring Boot):**
- [ ] API `POST /api/v1/courses/{id}/enroll` to enroll (insert into `enrollments` table).
- [ ] API `PUT /api/v1/lessons/{id}/complete` to record lesson completion in the `lesson_progresses` table.
- [ ] `ProgressService` calculates the total completion percentage (completed lessons / total lessons in Course version) and updates `progress_percentage` in `enrollments`.
- [ ] Enforce sequential check logic on Lesson access APIs.

## 3. Technical Constraints
- **Sequential Learning Constraint:** Access to Lesson N+1 requires that the user has a completed record for Lesson N in the `lesson_progresses` table. Quizzes are optional and do not block sequential progress.
- **Database Consistency:** Complete percentage calculation logic maps to the `enrollments` table (containing `progress_percentage`) and `lesson_progresses` table.
- **Security:** Guard Lesson endpoints from URL hacking (users manually typing `/lessons/N+2` routing paths directly).

## 4. Edge Cases
- **Trainer Modifies Published Course Structure:** When sections/lessons are added or deleted in a new course version, recalculate progress percentages for enrolled learners dynamically upon access to prevent numbers out of bounds.

## 5. Non-functional Requirements
- **Consistency:** Completion percentage calculation must run in `< 100ms` using optimized JPQL queries or DB updates.

