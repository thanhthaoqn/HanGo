# Feature Specification: FT-03 - Course Management

## 1. Business Context
Course Management is the core feature for Trainers to create and structure their courses. It allows Trainers to define the syllabus by creating Courses, dividing them into Sections (Chapters), and further breaking them down into Lessons. This structural hierarchy is essential for organizing educational content logically, and requires version control to manage live vs draft states.

## 2. Acceptance Criteria

**Frontend (Flutter):**
- [ ] Dynamic Course creation form allowing the addition of multiple Sections and Lessons.
- [ ] Input fields for Course Title, Description, Category, pricing tier, and Price override.
- [ ] Image picker integration for uploading Course Thumbnail to Cloudinary.
- [ ] Course Versioning status tracking: Display whether the current view is Draft, Submitted, Approved, Published, or Archived.

**Backend (Spring Boot):**
- [ ] API `POST /api/v1/courses` to create a new course (creates initial version in DRAFT).
- [ ] API `GET /api/v1/courses` with pagination and filtering (by category, instructor, status).
- [ ] API `POST /api/v1/courses/{id}/submit` to submit a Draft version for review.
- [ ] API `PUT /api/v1/admin/courses/{id}/review` (CourseManager only) to approve or reject a version.
- [ ] Table structures for version control: `courses` identity table mapping to `course_versions` (with status DRAFT, SUBMITTED, REJECTED, APPROVED, PUBLISHED, ARCHIVED).
- [ ] Auto Price Tier suggestion algorithm: suggest 300k/500k/700k based on course lesson count, quiz count, and video duration (Trainer can override).

## 3. Technical Constraints
- **Course Versioning Workflow:** Modifying a published course must clone the published version into a new `DRAFT` version, keeping the existing version live for enrolled learners. Upon approval and publishing of the new version, the live version pointer updates and the old version is marked `ARCHIVED`.
- **Database Consistency:** Use proper Foreign Key constraints between version entities, and handle deletion cleanly.
- **Transaction Management:** The creation and version transitions must be wrapped in `@Transactional` to ensure atomicity.

## 4. Edge Cases
- **Double Submit:** Prevent duplicate courses or double-review actions via UI-state locks.
- **Empty Course Structure:** Validate that a course has at least one Section and one Lesson before allowing submission for review.
- **No Free Course:** Ensure Trainer's very first course has price = 0 (`BR-G02`).

## 5. Non-functional Requirements
- **Data Integrity:** Ensure that the hierarchical data is mapped using DTOs to avoid circular reference issues (Entities are never returned directly from Controllers).

