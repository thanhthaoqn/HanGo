# Feature Specification: FE-10 — Learning Management

> Ref: [HanGo_Documentation.md](../HanGo_Documentation.md) §7.10 (LRN)

## 1. Business Context
The system needs to provide Learners with the ability to track the Learning Progress of each course they are enrolled in, ensuring learners know exactly what percentage they have completed and what part they need to study next. Learning is **strictly sequential by Lesson** — completing Lesson N unlocks Lesson N+1 (Quiz completion is not required to unlock the next Lesson — BR-LRN-02). Course access, once purchased/enrolled, is **lifetime** (BR-LRN-05). Gamification is explicitly out of scope for v1. For the Trainer, this is core data to evaluate course effectiveness.

## 2. Acceptance Criteria

**Frontend (Flutter):**
- [ ] "My Learning" screen displaying the list of enrolled courses along with a Progress Bar (% = completed Lessons / total Lessons).
- [ ] Lesson details interface features a "Mark as Completed" button.
- [ ] Auto-navigate to the next lesson (Next Lesson) when marked as completed successfully; Lesson N+1 stays locked until Lesson N is completed, regardless of Quiz result.
- [ ] "Continue Learning" — resume from the last accessed position.

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

