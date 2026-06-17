# Feature Specification: FT-12 - Task Management

## 1. Business Context
In training centers, the Lead needs to delegate tasks such as "Drafting Java Course" or "Reviewing Exam Bank" to Trainers. Task Management is an internal workflow helping assign, track status, and monitor deadlines of these assignments. This feature acts like a mini Kanban board strictly for course quality administration.

## 2. Acceptance Criteria

**Frontend (Flutter):**
- [ ] Management interface (exclusive to Lead/Trainer) displaying tasks as a List or Kanban Board (Todo, In-progress, Done).
- [ ] Task Assignment Form (For Lead): Select Assignee (Trainer), Title, Description, Task Type (Course/Exam), and set Deadline (Date/Time Picker).
- [ ] Trainers can drag and drop (or click buttons) to change Task status to In Progress or Submit.

**Backend (Spring Boot):**
- [ ] CRUD APIs for Tasks: `POST /api/v1/tasks` (Lead only), `PUT /api/v1/tasks/{id}/status` (Lead/Trainer).
- [ ] The `tasks` table has `assigned_by` and `assigned_to` columns.
- [ ] Each time the status changes or a Lead adds a note, insert 1 record into the `task_activities` table (Activity log).

## 3. Technical Constraints
- **Role-Based Access Control (RBAC):** Crucial. If a Learner calls a Task API, immediately return HTTP 403 Forbidden.
- **Backend:** 
  - Validate that the Deadline date is always > Current time.
  - When a Trainer updates a Task to "COMPLETED", the system auto-verifies if the attached entities (e.g., Course) were actually created (If complex validation rules apply).

## 4. Edge Cases
- **Trainer resigns or account locked:** What happens to their "In Progress" tasks?
  - *Solution:* Lead has the permission to Re-assign that Task to another Trainer. The system updates the `assigned_to` column and logs it into `task_activities`.
- **Assigning a task to a non-Trainer user:** Backend validates that the role of `assigned_to` MUST be TRAINER or LEAD. If it's a Learner, return HTTP 400 Bad Request.

## 5. Non-functional Requirements
- **Usability:** The Kanban/List UI must be clear, intuitive, distinguishing statuses via colors (Red: Overdue, Yellow: In Progress, Green: Completed).
- **Data Integrity:** The `task_activities` log is read-only for users (Only Add operations allowed, no editing/deleting old logs) to guarantee Audit traceability.
