# Feature Specification: FT-04 - Course Content Management

## 1. Business Context
Once the course structure is defined, Trainers need to populate it with actual content. Course Content Management allows Trainers to compose structured lesson content using **LessonBlocks** (supporting combinations of text blocks, video clips, PDF guides, or images in sequential order) and upload these media files to Cloudinary. It also provides bulk importing of lessons/quizzes via Excel templates.

## 2. Acceptance Criteria

**Frontend (Flutter):**
- [ ] Dynamic Syllabus editor allowing Trainers to manage Sections and Lessons.
- [ ] Lesson content composer utilizing **LessonBlocks** (allows adding, deleting, and reordering multiple content blocks like Text, Video, PDF, and Image).
- [ ] File picker with Progress Bar for video/image uploads.
- [ ] Excel Import interface to download template and upload bulk data (.xlsx).

**Backend (Spring Boot):**
- [ ] API endpoints to create, update, delete, and reorder Sections, Lessons, and nested LessonBlocks.
- [ ] API endpoint to upload media files directly to Cloudinary and retrieve secure URLs.
- [ ] API `POST /api/v1/lessons/import` to parse bulk upload Excel files (.xlsx) using Apache POI.
- [ ] Support reordering sections and lessons (updating `order_index` fields).

## 3. Technical Constraints
- **Lesson Content Layout:** Content must map to the `lesson_blocks` table with fields `id`, `lesson_id`, `block_type` (Text, Video, PDF, Image), `content` (for text markup), `media_url` (Cloudinary file link), and `display_order`.
- **Asynchronous Cloudinary Uploads:** Keep media uploads isolated. Large file handling should be configured safely on the server side.
- **Security:** Sanitize text inputs inside LessonBlocks on the backend to prevent Cross-Site Scripting (XSS). Parse Excel files securely to avoid XML External Entity (XXE) injection vulnerabilities.

## 4. Edge Cases
- **Missing or Invalid Excel Formats:** Rollback database transactions entirely if any row of the imported Excel has formatting/validation errors to preserve relational integrity.
- **Broken Media Link:** If media upload fails, prompt the user with detailed error notes instead of saving broken block references.

## 5. Non-functional Requirements
- **Performance:** Bulk Excel import processing must execute in `< 3000ms` for up to 1000 rows using Hibernate batch insertions.
- **Scalability:** Offloading heavy media storage to Cloudinary ensures the main application server does not run out of disk space.

