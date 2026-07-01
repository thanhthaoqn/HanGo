# TODO - HanGo AI assistant: đọc được practice exercise data

- [ ] Bước 1: Tìm entity/repository/DTO chứa “practice exercise data” (quiz/task/question) theo lesson.
- [ ] Bước 2: Đọc schema hiện tại (entity + field nào liên quan lessonId/examId/section).
- [ ] Bước 3: Thiết kế payload context cho AI: đề bài + dữ kiện cần thiết (đáp án/giải thích nếu có).
- [ ] Bước 4: Mở rộng `AIPromptBuilder` để nhúng practice data vào system prompt (hoặc prompt engineering cho từng practice).
- [ ] Bước 5: Mở rộng guardrail embedding similarity để tính scope theo (lý thuyết + practice) thay vì chỉ lý thuyết.
- [ ] Bước 6: Sửa `AIAssistantService.sendMessage()` để load practice data theo request.lessonId và truyền vào prompt/guardrail.
- [ ] Bước 7: Chạy build/test backend và thử nghiệm chat với câu hỏi thuộc phần practice.

- (1) When starting a task, change the checkbox status to `- [ ] (In Progress)`.
- (2) When a task is completed, change it to `- [x] Done`.
- (3) **ABSOLUTELY DO NOT arbitrarily delete any tasks** from this file without Human approval.
- (4) If attempting a task 3 times still results in failure (Stuck), keep the current status and log the error in the `Escalated to Human` section of the corresponding feature at the end of the file.

---

## 🚀 [FT-01] Authentication

### 🎨 Phase 1: Frontend UI & Mock Data _(Assigned to: Frontend Agent)_

- [x] Build Login/Register screens (Material Design) at `lib/presentation/pages/auth/`.
- [x] Create Mock Auth Repository simulating JWT generation and Google OAuth2 flow.

### ⚙️ Phase 2: Backend Execution & API Design _(Assigned to: Backend Agent)_

- [x] Set up `spring-boot-starter-security` and JWT (`jjwt`) dependencies.
- [x] Analyze and map `users`, `roles` Entities in MySQL.
- [x] Write `AuthService`: BCrypt hashing, JWT generation, Google OAuth2 integration.
- [x] Configure `SecurityFilterChain` and create `AuthController` returning agreed JSON.

### 🔌 Phase 3: Integration _(Assigned to: Frontend Agent)_

- [x] Integrate `google_sign_in` library to get Identity Token.
- [x] Call real REST APIs via `dio`, securely save JWT into `shared_preferences` and navigate to Dashboard using `go_router`.

### 🚨 Phase 4: Quality Assurance _(Assigned to: QA/Testing Agent)_

- [ ] Backend: Unit test password hashing and token parsing.
- [ ] Frontend: Widget Test for invalid email form error.
- [ ] Simulate expired JWT error (401) to automatically push back to Login screen.

---

## 🚀 [FT-02] Account Management

### 🎨 Phase 1: Frontend UI & Mock Data _(Assigned to: Frontend Agent)_

- [x] Build Profile view/edit UI for Learner/Trainer.
- [x] Build User Management `DataTable` for Admin. Add Image Picker for Avatar.
- [x] Render "Lock Account" button based on internal Role. Create Mock User Repository.

### ⚙️ Phase 2: Backend Execution & API Design _(Assigned to: Backend Agent)_

- [x] Create CRUD APIs for Profile (`GET /api/v1/users/me`, `PUT /api/v1/users/me`).
- [x] Create Management API for Admin (`GET /api/v1/users`, pagination, `@PreAuthorize`).
- [x] Create Lock API (`PUT /api/v1/users/{id}/status`) and integrate Cloudinary for Avatar.

### 🔌 Phase 3: Integration _(Assigned to: Frontend Agent)_

- [x] Replace mock data with real APIs. Implement image compression and Cloudinary upload flow.

### 🚨 Phase 4: Quality Assurance _(Assigned to: QA/Testing Agent)_

- [ ] Prevent Admin from locking their own account (HTTP 400 Error).
- [ ] Duplicate email update (Catch `DataIntegrityViolationException` -> 409 Conflict).

---

## 🚀 [FT-03] Course Management

### 🎨 Phase 1: Frontend UI & Mock Data _(Assigned to: Frontend Agent)_

- [x] Build dynamic Course creation form allowing addition of multiple Sections/Lessons.
- [x] Build Course listing UI. Use Mock Course Repository for visual validation.

### ⚙️ Phase 2: Backend Execution & API Design _(Assigned to: Backend Agent)_

- [ ] Initialize `courses`, `sections`, `lessons` tables with `ON DELETE CASCADE` configuration.
- [ ] Write `CourseService` combined with `@Transactional`.
- [x] Build `POST /api/v1/courses` API and integrate Course Thumbnail upload to Cloudinary.

### 🔌 Phase 3: Integration _(Assigned to: Frontend Agent)_

- [x] Integrate image picker library and call real `POST /api/v1/courses` API via `dio`.

### 🚨 Phase 4: Quality Assurance _(Assigned to: QA/Testing Agent)_

- [ ] Catch Double Submit case (Spam clicking Save button).
- [ ] Test Optimistic Locking (`@Version`) when 2 Trainers edit the same course concurrently.

---

## 🚀 [FT-04] Course Content Management

### 🎨 Phase 1: Frontend UI & Mock Data _(Assigned to: Frontend Agent)_

- [ ] Integrate Rich-text editor (Markdown/HTML).
- [ ] Implement Drag & Drop feature for Lesson list.
- [ ] Display Progress bar for video upload progress using mock data.

### ⚙️ Phase 2: Backend Execution & API Design _(Assigned to: Backend Agent)_

- [ ] Increase file upload size in Spring Boot config (Max 500MB).
- [ ] Write API to receive `MultipartFile` and push Video/PDF to Cloudinary asynchronously (`@Async`).
- [ ] Write Reorder API to update `order_index` column of lessons.

### 🔌 Phase 3: Integration _(Assigned to: Frontend Agent)_

- [ ] Replace mock logic with real chunked/multipart file uploads and drag-and-drop sync APIs.

### 🚨 Phase 4: Quality Assurance _(Assigned to: QA/Testing Agent)_

- [ ] Simulate slow/lost connection during video upload -> Allow Retry.
- [ ] XSS Prevention for Lesson description text data.

---

## 🚀 [FT-05] Question Bank Management

### 🎨 Phase 1: Frontend UI & Mock Data _(Assigned to: Frontend Agent)_

- [ ] Build list UI with filters (By type, difficulty).
- [ ] Build dynamic question creation form (Multiple Choice, True/False).
- [ ] Add File Picker UI for Excel import. Create Mock Question Repository.

### ⚙️ Phase 2: Backend Execution & API Design _(Assigned to: Backend Agent)_

- [ ] Set up `questions`, `answers` tables.
- [ ] Integrate **Apache POI** library to read Excel files from `POST /api/v1/questions/import` API.
- [ ] Implement "Soft delete" logic (Change status to INACTIVE).

### 🔌 Phase 3: Integration _(Assigned to: Frontend Agent)_

- [ ] Hook up real API filtering and real file picker for POI import.

### 🚨 Phase 4: Quality Assurance _(Assigned to: QA/Testing Agent)_

- [ ] Prevent XXE Injection vulnerability when parsing Excel.
- [ ] Test importing Excel file missing correct answers (`is_correct`).

---

## 🚀 [FT-06] Exam Management

### 🎨 Phase 1: Frontend UI & Mock Data _(Assigned to: Frontend Agent)_

- [x] Build List Exams UI (Grid of available exams).
- [ ] Exam Builder UI (select questions).
- [x] Exam Execution UI with countdown timer and Mock Submission logic.

### ⚙️ Phase 2: Backend Execution & API Design _(Assigned to: Backend Agent)_

- [x] List exams API (`GET /api/v1/exams`).
- [x] Exam configuration API (`time_limit`, `passing_score`).
- [x] Receive answer API (`POST /api/v1/exams/{id}/submit`), with auto-grading algorithm.
- [x] Log results to `exam_attempts` and lock attempt to prevent double submission.

### 🔌 Phase 3: Integration _(Assigned to: Frontend Agent)_

- [x] Integrate `GET /api/v1/exams` API for List Exams UI.
- [x] Cache answers locally to `shared_preferences` and integrate real API submission logic.

### 🚨 Phase 4: Quality Assurance _(Assigned to: QA/Testing Agent)_

- [ ] Time's up -> Automatically fire Submit API with answered questions.
- [ ] Handle late submission due to network delay (Tolerance +1 minute at Backend).

---

## 🚀 [FT-07] Recommendation System

### 🎨 Phase 1: Frontend UI & Mock Data _(Assigned to: Frontend Agent)_

- [ ] Design "Suggested for you" Card Carousel on Dashboard.
- [ ] Handle Empty State if the user hasn't taken any exams yet. Provide mock recommendations.

### ⚙️ Phase 2: Backend Execution & API Design _(Assigned to: Backend Agent)_

- [ ] Write `RecommendationEngineService` using logic rules (E.g.: Score < 50% -> suggest Basic course).
- [ ] Apply Indexes on DB tables and Caching to optimize queries.

### 🔌 Phase 3: Integration _(Assigned to: Frontend Agent)_

- [ ] Fetch actual dynamic recommendations via backend API.

### 🚨 Phase 4: Quality Assurance _(Assigned to: QA/Testing Agent)_

- [ ] Test Cold-start scenario (Return Top Rated courses instead of error).

---

## 🚀 [FT-08] AI Learning Assistant

### 🎨 Phase 1: Frontend UI & Mock Data _(Assigned to: Frontend Agent)_

- [ ] Build floating Chatbot Bubble UI.
- [ ] Handle Streaming Text logic and Typing Indicator with mock data. Support Markdown rendering.

### ⚙️ Phase 2: Backend Execution & API Design _(Assigned to: Backend Agent)_

- [ ] Call REST API to AI Provider (OpenAI/Gemini) via `RestTemplate` or WebClient.
- [ ] Build Prompt Context embedding current lesson information.

### 🔌 Phase 3: Integration _(Assigned to: Frontend Agent)_

- [ ] Connect chat UI to backend AI endpoint, parsing real streaming SSE/chunks.

### 🚨 Phase 4: Quality Assurance _(Assigned to: QA/Testing Agent)_

- [ ] Handle expired or overloaded API Token error (Display "System is busy").
- [ ] Prevent Prompt Injection. Rate limit questions per day.

---

## 🚀 [FT-09] Learning Progress

### 🎨 Phase 1: Frontend UI & Mock Data _(Assigned to: Frontend Agent)_

- [x] Render Progress bar in "My Courses" list.
- [x] "Mark as Completed" button UI and Mock Progress Repository.

### ⚙️ Phase 2: Backend Execution & API Design _(Assigned to: Backend Agent)_

- [x] Write Enroll API and "Complete Lesson" API.
- [x] Use `@Lock` in the course progress percentage calculation function to prevent Race Conditions.

### 🔌 Phase 3: Integration _(Assigned to: Frontend Agent)_

- [x] Call real API and auto-navigate to the next lesson upon success.

### 🚨 Phase 4: Quality Assurance _(Assigned to: QA/Testing Agent)_

- [ ] Prevent user from spam calling Complete API for a single lesson.
- [ ] Auto-revert percentage if a Trainer deletes a lesson.

---

## 🚀 [FT-10] Flashcard Management

### 🎨 Phase 1: Frontend UI & Mock Data _(Assigned to: Frontend Agent)_

- [ ] Implement Flip Animation and Swipe (Left/Right) UI.
- [ ] Pagination (Load more) for flashcard list with fake items.

### ⚙️ Phase 2: Backend Execution & API Design _(Assigned to: Backend Agent)_

- [ ] Build CRUD APIs for Collection and Flashcard (`user_id` validation).

### 🔌 Phase 3: Integration _(Assigned to: Frontend Agent)_

- [ ] Connect Flashcard interactions (know/don't know) with real API logging.

### 🚨 Phase 4: Quality Assurance _(Assigned to: QA/Testing Agent)_

- [ ] Widget Test for frame rate (60fps) during card Flip.
- [ ] Cascade delete all child flashcards when parent Collection is deleted.

---

## 🚀 [FT-11] Comment Management

### 🎨 Phase 1: Frontend UI & Mock Data _(Assigned to: Frontend Agent)_

- [x] Build Recursive Widget UI for parent-child comments.
- [x] Use Mock Comment repository with a few levels of nesting.

### ⚙️ Phase 2: Backend Execution & API Design _(Assigned to: Backend Agent)_

- [x] Self-referencing `comments` table structure (`parent_id`).
- [x] Use `JOIN FETCH` to resolve N+1 query issues. Implement Soft Delete feature.

### 🔌 Phase 3: Integration _(Assigned to: Frontend Agent)_

- [x] Replace mock with backend `GET` mapping recursive JSON.

### 🚨 Phase 4: Quality Assurance _(Assigned to: QA/Testing Agent)_

- [ ] Prevent Comment Spam (Rate Limiting).
- [ ] Filter Bad Words and escape XSS malicious characters.

---

## 🚀 [FT-12] Task Management

### 🎨 Phase 1: Frontend UI & Mock Data _(Assigned to: Frontend Agent)_

- [ ] Build Kanban Board or Task List UI.
- [ ] Integrate Date/Time picker for Deadlines. Use Mock Tasks.

### ⚙️ Phase 2: Backend Execution & API Design _(Assigned to: Backend Agent)_

- [ ] Create `tasks` table and `task_activities` logs.
- [ ] APIs with strict checking of Assignee permissions.

### 🔌 Phase 3: Integration _(Assigned to: Frontend Agent)_

- [ ] Connect task drag & drop status updates to real API.

### 🚨 Phase 4: Quality Assurance _(Assigned to: QA/Testing Agent)_

- [ ] Strict access control (Learner calling Task API -> HTTP 403).
- [ ] Test Re-assign task feature when a Trainer leaves.

---

## 🚀 [FT-13] Analytics Dashboard

### 🎨 Phase 1: Frontend UI & Mock Data _(Assigned to: Frontend Agent)_

- [x] Build Bar, Pie charts using `fl_chart` library.
- [x] Add date filter UI. Supply mock stats to charts.

### ⚙️ Phase 2: Backend Execution & API Design _(Assigned to: Backend Agent)_

- [x] Write optimized Native Queries for totals (`COUNT`, `GROUP BY`).
- [ ] Potentially move heavy aggregations to a `@Scheduled` Job.

### 🔌 Phase 3: Integration _(Assigned to: Frontend Agent)_

- [x] Fetch actual dashboard metrics.

### 🚨 Phase 4: Quality Assurance _(Assigned to: QA/Testing Agent)_

- [x] UI properly handles Empty Data state (Does not display distorted charts).

---

## 🚀 [FT-14] Notification

### 🎨 Phase 1: Frontend UI & Mock Data _(Assigned to: Frontend Agent)_

- [ ] Bell icon UI with unread count Badge. Display mock drop-down notifications.

### ⚙️ Phase 2: Backend Execution & API Design _(Assigned to: Backend Agent)_

- [ ] Set up `ApplicationEventPublisher` (Spring Events) for asynchronous notification generation (`@Async`).
- [ ] Paginated Notification GET API and Mark as Read API.

### 🔌 Phase 3: Integration _(Assigned to: Frontend Agent)_

- [ ] Set up Polling Timer (once per minute) to fetch real unread counts.
- [ ] Integrate Mark as Read API click action.

### 🚨 Phase 4: Quality Assurance _(Assigned to: QA/Testing Agent)_

- [ ] Max badge count = "99+".
- [ ] Toast warning if clicking a notification navigating to a deleted lesson (HTTP 404).

---

## 🛑 ESCALATED TO HUMAN

_(AI Agents should log tasks stuck after 3 attempts here, formatted as: [FeatureID] - Task Name - Error Description - File Link)_

- [ ] (No issues yet)
