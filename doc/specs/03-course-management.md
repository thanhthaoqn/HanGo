# Feature Specification: FT-03 - Course Management

## 1. Business Context
Course Management is the core feature for Trainers to create and structure their courses. It allows Trainers to define the syllabus by creating Courses, dividing them into Sections (Chapters), and further breaking them down into Lessons. This structural hierarchy is essential for organizing educational content logically.

## 2. Acceptance Criteria

**Frontend (Flutter):**
- [ ] Dynamic Course creation form allowing the addition of multiple Sections and Lessons.
- [ ] Input fields for Course Title, Description, Category, and Price.
- [ ] Image picker integration for uploading Course Thumbnail.
- [ ] API integration via `dio` to submit the entire course structure.

**Backend (Spring Boot):**
- [ ] API `POST /api/v1/courses` to create a new course along with its nested sections and lessons.
- [ ] API `GET /api/v1/courses` with pagination and filtering (by category, instructor, status).
- [ ] Table structures for `courses`, `sections`, and `lessons` with proper Foreign Key constraints.
- [ ] Integrate Cloudinary API to handle Thumbnail image upload.

## 3. Technical Constraints
- **Database Consistency:** Use `ON DELETE CASCADE` for Sections and Lessons to prevent orphan records when a Course is deleted.
- **Transaction Management:** The creation of a Course, its Sections, and Lessons must be wrapped in `@Transactional` to ensure atomicity (all or nothing).
- **Frontend Architecture:** The complex dynamic form state (adding/removing sections dynamically) should be managed efficiently using Riverpod to avoid unnecessary widget rebuilds.

## 4. Edge Cases
- **Double Submit:** Prevent users from spam-clicking the "Save" button, which could create duplicate courses. Disable the button during the API call.
- **Concurrent Editing:** If two Trainers attempt to edit the same course simultaneously, implement Optimistic Locking (`@Version` in JPA) to throw an `OptimisticLockException` and prevent data overwriting.
- **Empty Course Structure:** Validate that a Course has at least one Section and one Lesson before allowing it to be published.

## 5. Non-functional Requirements
- **Data Integrity:** Ensure that the hierarchical data (Course -> Section -> Lesson) is consistently mapped using DTOs to avoid circular reference issues (`@JsonManagedReference` / `@JsonBackReference` if returning entities, though DTOs are preferred).
