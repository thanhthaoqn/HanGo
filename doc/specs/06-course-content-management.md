# Feature Specification: FE-06 — Course Content Management

> Ref: [HanGo_Documentation.md](../HanGo_Documentation.md) §7.6 (CNT). Course **metadata**/review-publish workflow lives in [05-course-management.md](05-course-management.md) (FE-05) — not duplicated here.

## 1. Business Context
Once a Course version exists, Trainers populate it with structure and content, owned exclusively by them (BR-G06): manage **Section** (create/edit/delete/reorder), manage **Lesson** within a Section (create/edit/delete/reorder), and author Lesson content as **LessonBlocks** — text-first, with optional inserted video/pdf/image blocks (not a single freeform rich-text document per lesson). Each Lesson can also have a **Quiz**, built from questions pulled from the Trainer's reusable Question Bank (FR-CNT-03, BR-G07 — Quiz questions are reusable, unlike Exam questions which are locked to the Exam). Bulk authoring is supported via **Excel (.xlsx) import** (FR-CNT-05). Structure: `Course version → Section → Lesson → (LessonBlock, Quiz)` — BR-CNT-01.

## 2. Acceptance Criteria

**Frontend (Flutter):**
- [ ] Syllabus editor: Section CRUD + reorder, Lesson CRUD + reorder within a Section (drag-and-drop, updates `order_index`).
- [ ] Lesson editor built around **LessonBlock**: add/reorder blocks of type Text (primary), Video, PDF, Image — not a single rich-text body.
- [ ] Quiz builder inside a Lesson: create Quiz, pick questions from the Trainer's Question Bank (see [07-question-bank-management.md](07-question-bank-management.md)).
- [ ] File picker for Video/PDF/Image block uploads with a visible progress bar.
- [ ] "Import from Excel" flow: download template, pick `.xlsx` file, upload, show per-row success/error report.

**Backend (Spring Boot):**
- [ ] `sections`, `lessons`, `lesson_blocks` (`type`: Text/Video/PDF/Image) tables under a Course version.
- [ ] API `PUT /api/v1/sections/{id}/reorder` / `PUT /api/v1/sections/{id}/lessons/reorder` to persist `order_index`.
- [ ] API to attach a Quiz + selected Question Bank question IDs to a Lesson.
- [ ] API `POST /api/v1/lessons/{id}/media` to receive `MultipartFile` uploads, pushed to Cloudinary asynchronously (`@Async`); DB stores only the returned URL.
- [ ] API `POST /api/v1/courses/{id}/import` to parse an `.xlsx` file (Apache POI) into Sections/Lessons/LessonBlocks/Quiz in bulk, inside a single `@Transactional` batch.

## 3. Technical Constraints
- **Asynchronous Processing:** Video uploads to Cloudinary can take time; return an "Uploading" status immediately and process asynchronously to avoid HTTP timeouts.
- **Security:** Guard Apache POI parsing against XXE; validate MIME types so only legitimate `.mp4`/`.pdf`/image formats are accepted for LessonBlock media; reject executables.
- **Frontend Reordering:** Update local state first, then silently sync the new `order_index` array to the backend.

## 4. Edge Cases
- **Network Interruptions:** If the connection drops mid-upload, offer a "Retry" button; don't lose already-entered Lesson content.
- **XSS in Text LessonBlock:** Sanitize text-block content on the backend before saving.
- **Invalid Excel data:** Row missing a required field, or referencing a non-existent Question Bank question ID → report the row and either skip it or roll back the whole import (Trainer's choice / documented default).
- **Invalid Reorder Data:** Reject incomplete/duplicate ID arrays for reordering to protect data integrity.

## 5. Non-functional Requirements
- **User Experience:** Upload progress bar must reflect real progress.
- **Scalability:** Offloading media storage to Cloudinary keeps the app server stateless regarding file storage.
