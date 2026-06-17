# Feature Specification: FT-04 - Course Content Management

## 1. Business Context
Once the course structure is defined, Trainers need to populate it with actual content. Course Content Management allows Trainers to upload heavy media files (Videos, PDFs) and write detailed text lessons using a Rich-text editor. It also provides the ability to reorder lessons easily via drag-and-drop.

## 2. Acceptance Criteria

**Frontend (Flutter):**
- [ ] Integrate a Rich-text editor (Markdown or HTML support) for text-based lessons.
- [ ] File picker for Video and PDF uploads with a visible Progress Bar.
- [ ] Drag-and-drop interface to reorder Lessons within a Section.
- [ ] API integration to update the `order_index` of lessons.

**Backend (Spring Boot):**
- [ ] API `POST /api/v1/lessons/{id}/media` to receive `MultipartFile` uploads.
- [ ] Handle pushing heavy Video/PDF files to Cloudinary asynchronously using `@Async`.
- [ ] API `PUT /api/v1/sections/{id}/reorder` to update the sequence of lessons.
- [ ] Configure Spring Boot to accept large file uploads (e.g., `spring.servlet.multipart.max-file-size=500MB`).

## 3. Technical Constraints
- **Asynchronous Processing:** Video uploads to Cloudinary can take time. The Backend should immediately return an "Uploading" status and process the file asynchronously to avoid HTTP timeout errors.
- **Frontend Reordering:** The drag-and-drop list must smoothly update the local state first, then silently call the Backend API to sync the new `order_index` array.
- **Security:** Validate MIME types on the Backend to ensure only legitimate `.mp4`, `.pdf` files are accepted. Reject executable files (`.exe`, `.sh`).

## 4. Edge Cases
- **Network Interruptions:** If the user's connection drops during a 500MB video upload, the Frontend should handle the error gracefully and offer a "Retry" button.
- **XSS Vulnerabilities:** Text content from the Rich-text editor must be sanitized on the Backend before saving to the database to prevent Cross-Site Scripting (XSS) attacks.
- **Invalid Reorder Data:** If the Frontend sends an incomplete array of lesson IDs for reordering, the Backend must validate and reject the request to maintain data integrity.

## 5. Non-functional Requirements
- **User Experience:** The upload progress bar must reflect real-time progress to keep the user informed during long uploads.
- **Scalability:** Offloading heavy media storage to Cloudinary ensures the main application server does not run out of disk space.
