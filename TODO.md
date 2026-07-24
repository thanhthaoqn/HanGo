# TODO - HanGo Project Roadmap (Aligned with HanGo_Documentation.md)

This file is the official roadmap and checklist for the HanGo platform development. It is structured around the 14 functional modules defined in [HanGo_Documentation.md](doc/HanGo_Documentation.md).

---

## 🚀 [FE-01] Authentication
### 🎨 Phase 1: Frontend UI & Mock Data
- [x] Build Login/Register screens (Material Design) at `lib/presentation/pages/auth/`.
- [x] Create Mock Auth Repository simulating JWT generation and Google OAuth2 flow.

### ⚙️ Phase 2: Backend Execution & API Design
- [x] Set up `spring-boot-starter-security` and JWT (`jjwt`) dependencies.
- [x] Analyze and map `users`, `roles` Entities in MySQL.
- [x] Write `AuthService`: BCrypt hashing, JWT generation, Google OAuth2 integration.
- [x] Configure `SecurityFilterChain` and create `AuthController` returning agreed JSON.

### 🔌 Phase 3: Integration
- [x] Integrate `google_sign_in` library to get Identity Token.
- [x] Call real REST APIs via `dio`, securely save JWT into `shared_preferences` and navigate to Dashboard.

### 🚨 Phase 4: Quality Assurance
- [x] Backend: Unit test `AuthService` (login, register, forgot/verify/reset password, verify account, resend verification, `isAccountVerified`) + `UserDetailsServiceImpl.loadUserByUsername` — 30 tests passed, see `hango-backend/src/test/java/.../AuthServiceTest.java` + `UserDetailsServiceImplTest.java` and [`doc/specs/unit_test_plan.md`](doc/specs/unit_test_plan.md) §3.1/§3.2/§3.2b. Found during testing: (1) `googleLogin`'s JIT-provisioning happy path can't be unit-tested without refactoring `GoogleIdTokenVerifier` to be injectable; (2) no `refreshToken`/`logout` endpoint exists despite doc claiming "access + refresh token"; (3) `authenticateUser` only blocks status `"INACTIVE"` — a `"LOCKED"` status logs in fine today.
- [ ] Frontend: Widget Test for invalid email form error.
- [ ] Simulate expired JWT error (401) to automatically push back to Login screen.

---

## 🚀 [FE-02] Profile Management
### 🎨 Phase 1: Frontend UI & Mock Data
- [x] Build Profile view/edit UI for Learner/Trainer.
- [x] Render public profile brand page for Trainer (bio, course list).

### ⚙️ Phase 2: Backend Execution & API Design
- [x] Create CRUD APIs for Profile (`GET /api/v1/users/me`, `PUT /api/v1/users/me`).
- [x] Create Public Profile API for Trainer.

### 🔌 Phase 3: Integration
- [x] Replace mock data with real APIs. Implement image compression and Cloudinary upload flow.

### 🚨 Phase 4: Quality Assurance
- [ ] Duplicate email update (Catch `DataIntegrityViolationException` -> 409 Conflict).

---

## 🚀 [FE-03] Role & Permission Management
### 🎨 Phase 1: Frontend UI & Mock Data
- [x] Build User Management `DataTable` for Admin. Add Image Picker for Avatar.
- [x] Render "Lock Account" button based on internal Role.
- [x] Build Admin Dashboard & Analytics UI showing platform stats (revenue, active users, top courses).
- [ ] Build AI Usage Monitoring Dashboard UI (showing tokens and cost).

### ⚙️ Phase 2: Backend Execution & API Design
- [x] Create Management API for Admin (`GET /api/v1/users`, pagination, `@PreAuthorize`).
- [x] Create Lock API (`PUT /api/v1/users/{id}/status`).
- [ ] Implement AI Usage Logging Aspect (`@AfterReturning`) to record token usage and log into `ai_usage_logs` table.
- [ ] Implement Audit Logging Aspect to record administrative actions into `audit_logs` table.

### 🔌 Phase 3: Integration
- [x] Connect Admin User Management APIs and Dashboard Analytics charts.
- [ ] Integrate AI Usage Monitoring and Audit Logs with real APIs.

### 🚨 Phase 4: Quality Assurance
- [ ] Prevent Admin from locking their own account (HTTP 400 Error).

---

## 🚀 [FE-04] Trainer Onboarding (NEW)
### 🎨 Phase 1: Frontend UI & Mock Data
- [x] Build Trainer Application Form UI (allow selecting Professional / Peer Tutor).
- [x] Add fields for personal info, bank details, and Document file picker (for certificates/transcripts).
- [x] Build Admin Trainer Applications Queue view (allows review, approve, reject with notes).

### ⚙️ Phase 2: Backend Execution & API Design
- [x] Set up `trainer_applications` table with status (Draft, Submitted, Approved, Rejected).
- [x] Create API `POST /api/v1/trainers/apply` (receive files and upload to Cloudinary).
- [x] Create Admin review APIs (`GET /api/v1/admin/trainer-applications`, `PUT /api/v1/admin/trainer-applications/{id}/review`).
- [x] Write logic to update `User` role to `Trainer`, set TrainerType and default revenue split rate upon approval.

### 🔌 Phase 3: Integration
- [x] Connect Trainer onboarding flow and application submission to backend.
- [x] Integrate Admin application review actions.

### 🚨 Phase 4: Quality Assurance
- [ ] Ensure non-registered/non-learner users cannot submit application (HTTP 403).
- [ ] Validate uploaded files (limit file size and formats).

---

## 🚀 [FE-05] Course Management
### 🎨 Phase 1: Frontend UI & Mock Data
- [x] Build Course listing & discovery UI (search and filter by SkillType, price, rating).
- [x] Build Course detail view (Guest can only browse structure, Enrolled Learner can learn).
- [x] Build Trainer Course Creation Form (Draft metadata, category, max 3 SkillTypes, thumbnail upload).

### ⚙️ Phase 2: Backend Execution & API Design
- [x] Set up `courses` and `course_versions` tables to support content versioning.
- [x] Write `CourseService` to handle Course Versioning (cloning live version to Draft when modifying published course).
- [ ] Implement backend price tier suggestion algorithm (gợi ý 300k/500k/700k based on lesson count, quizzes, video duration) - Trainer can override.
- [x] Create APIs for Course Discovery (`GET /api/v1/courses`), and Trainer CRUD (`POST /api/v1/courses`, `PUT`).
- [x] Create Course Review APIs (`POST /api/v1/courses/{id}/submit`, `PUT /api/v1/admin/courses/{id}/review` for CourseManager).

### 🔌 Phase 3: Integration
- [x] Integrate course creation, thumbnail upload to Cloudinary, and submission.
- [x] Integrate CourseManager review queue and publish/unpublish action.

### 🚨 Phase 4: Quality Assurance
- [ ] Test versioning: editing a published course creates a draft version while the live version remains active for learners.

---

## 🚀 [FE-06] Course Content Management
### 🎨 Phase 1: Frontend UI & Mock Data
- [ ] Build Trainer Course Syllabus Editor (Manage Sections, Lessons).
- [ ] Soạn nội dung bằng **LessonBlock** (Text first, support video/pdf/image block insertions).
- [ ] Build Excel import template download and file selector.

### ⚙️ Phase 2: Backend Execution & API Design
- [ ] Set up `sections`, `lessons`, `lesson_blocks` tables.
- [ ] Write API to upload files to Cloudinary.
- [ ] Write Excel Import Service (using **Apache POI** or equivalent parser) to read LessonBlocks and Quizzes in bulk.

### 🔌 Phase 3: Integration
- [ ] Connect Syllabus editor (Sections/Lessons CRUD) to API.
- [ ] Integrate Excel import upload endpoint.

### 🚨 Phase 4: Quality Assurance
- [ ] Prevent XXE Injection vulnerability when parsing Excel files.
- [ ] Test video upload progress and file size limit configurations.

---

## 🚀 [FE-07] Question Bank Management
### 🎨 Phase 1: Frontend UI & Mock Data
- [ ] Build Question Bank list and filter UI (SkillType, Difficulty, Visibility).
- [ ] Build Question Editor Form (A/B/C/D choices, correct answer, explanation, SkillType).
- [ ] Build QuestionGroup Editor UI (supporting passage comprehension).

### ⚙️ Phase 2: Backend Execution & API Design
- [ ] Set up `questions`, `options`, `question_groups` tables.
- [ ] Implement Question Bank CRUD API (`/api/v1/questions`).
- [ ] Integrate AI generation draft service for Questions and Explanations.

### 🔌 Phase 3: Integration
- [ ] Integrate Question Bank manager screen with backend CRUD endpoints.
- [ ] Connect AI draft generation buttons.

### 🚨 Phase 4: Quality Assurance
- [ ] Ensure proper validation on SkillType mapping (must have exactly 1 SkillType).

---

## 🚀 [FE-08] Exam Management
### 🎨 Phase 1: Frontend UI & Mock Data
- [x] Build List Exams UI (Grid of available exams).
- [ ] Build Exam Builder UI (allows selecting exam questions).
- [x] Exam Execution UI with 50-minute countdown timer and auto-submit logic.
- [x] Exam Result page showing score (scale 10), correct answers, and explanations.

### ⚙️ Phase 2: Backend Execution & API Design
- [x] Set up `exams`, `exam_versions`, `exam_attempts` tables.
- [x] Implement CRUD APIs for Exams and private questions.
- [x] Implement API `POST /api/v1/exams/{id}/submit` with auto-grading algorithm (0.25 points per correct answer, 40 questions total).

### 🔌 Phase 3: Integration
- [x] Integrate Exam listing, taking, timer sync, and submission logic.
- [ ] Integrate Exam Builder UI for CourseManager to create and publish exams.

### 🚨 Phase 4: Quality Assurance
- [ ] Verify auto-submit triggers immediately when time's up.
- [ ] Verify that exam questions are private to the exam and cannot be reused in course quizzes.

---

## 🚀 [FE-09] AI Assistant
### 🎨 Phase 1: Frontend UI & Mock Data
- [ ] Build Floating Chatbot Bubble UI inside Course/Lesson page.
- [ ] Build AI draft helper panel in Trainer Question editor.

### ⚙️ Phase 2: Backend Execution & API Design
- [x] Set up connection to LLM API (Gemini/OpenAI).
- [ ] Implement `AIAssistantService` to handle Learner's questions about Lesson content, Quiz answers, or general concepts.
- [ ] Ensure guardrails are active (avoid answering off-topic questions).

### 🔌 Phase 3: Integration
- [ ] Connect Learner floating chatbot UI to backend assistant endpoints.
- [ ] Connect Trainer AI question drafting helpers.

### 🚨 Phase 4: Quality Assurance
- [ ] Test guardrails to ensure AI refuses out-of-scope prompts (e.g. non-educational questions).

---

## 🚀 [FE-10] Learning Management
### 🎨 Phase 1: Frontend UI & Mock Data
- [x] Build "My Learning" dashboard listing enrolled courses with progress bars.
- [x] Build Sequential Lesson View (unlocked lesson sequence: must complete Lesson N to view N+1).
- [x] Build Course Rating Dialog (Learner rates course 1-5 stars with comments).

### ⚙️ Phase 2: Backend Execution & API Design
- [x] Create Course Enrollment API (Free goes direct, Paid goes through VNPay webhook validation).
- [x] Create Progress Tracking API (percentage = completed lessons / total lessons).
- [x] Implement Sequential Learning check filter on Lesson access APIs.
- [x] Implement rating limitation logic (Max 1 review per learner per course).

### 🔌 Phase 3: Integration
- [x] Integrate Enrollment flow and Lesson learning state.
- [x] Connect sequential unlocking logic on frontend navigation.
- [x] Integrate Course Rating submission.

### 🚨 Phase 4: Quality Assurance
- [ ] Test sequential unlocking edge cases (e.g., trying to access Lesson N+2 directly via URL/Router).

---

## 🚀 [FE-11] Recommendation
### 🎨 Phase 1: Frontend UI & Mock Data
- [x] Build Adaptative Learning Pathway Page showing Interactive Node Tree (Duolingo-style nodes).
- [x] Implement 3 Node states: Locked (gray), In Progress (glow), Completed (green check).
- [x] Build AI Mentor Side Panel (Avatar, markdown chat box, free input text).
- [ ] Build "Suggested for you" Carousel on Dashboard.

### ⚙️ Phase 2: Backend Execution & API Design
- [x] Create `WeaknessAnalysis` logic (evaluate SkillType performance from ExamAttempt).
- [x] Create Rule-based Recommendation mapping weak SkillType -> Course.
- [x] Create `LearningPathwayService` to generate structured roadmap JSON from matrix results.
- [x] Create API endpoints `/api/v1/pathways/generate`, `/api/v1/pathways/me`, `/api/v1/pathways/{id}/chat` for AI Mentor.
- [ ] Add `wasOutOfScope` detection in AI Mentor Chat (system prompt and fallback logic).

### 🔌 Phase 3: Integration
- [x] Replace mock data with real pathway generator and AI Mentor Chat API calls.
- [x] Bind Node Tree steps to `CourseDetailPage` / `LessonPage` navigation.

### ⚙️ Phase 5: Agentic Upgrade (AI Pathway Upgrade)
- [ ] **Agent Tooling - Function Calling:**
  - [ ] Implement and register backend Tools (e.g., `triggerReroute`, `getPathwayById`, `getUserProgressSnapshot`).
  - [ ] Implement orchestrator to parse and execute function calls triggered by Gemini.
- [ ] **Dynamic Reroute via Function Calling:**
  - [ ] Update AI prompt to force the agent to call `triggerReroute` when user requests modification (e.g. "too hard").
  - [ ] Implement log audit database for tool executions.
- [ ] **Long-term Memory - Chat Memory:**
  - [ ] Set up `ai_chat_histories` table to persist pathway chat sessions.
  - [ ] Implement context truncation logic (prioritizing system instructions, current state, and last 5-10 messages).
- [ ] **Long-term Memory - Profile Memory:**
  - [ ] Implement database structure for learner profile memory (skill strengths/weaknesses preferences).
  - [ ] Update LLM prompts to reference profile memory (e.g., "you are showing progress in Reading").
- [ ] **Prompt Management (LLMOps):**
  - [ ] Extract system prompts from code into external `.st` (StringTemplate) configurations.
- [ ] **Human-in-the-loop - Reporting & Flag:**
  - [ ] Add UI/API for learner to submit a "Report bad roadmap" feedback.
  - [ ] Set rules to flag pathways (e.g., if rerouted >= 3 times) for manual Admin review.
- [ ] **Security & Guardrails for Agentic Calls:**
  - [ ] Validate path ownership on all tool invocations and enforce `course_id` validation.

### 🚨 Phase 4: Quality Assurance
- [ ] Verify AI recommendations do not hallucinate non-existing courses.
- [ ] Test out-of-scope fallback on AI Mentor Chat.
- [ ] Verify pathway access rules (only owner Learner can read/chat).

---

## 🚀 [FE-12] Payment & Revenue (NEW)
### 🎨 Phase 1: Frontend UI & Mock Data
- [x] Build Course Purchase screen displaying price details and PayOS QR code modal.
- [x] Build Learner Purchase History UI tab in Account Profile page (`MyInformationPage`).
- [ ] Integrate payment checkout redirection.
- [ ] Build Trainer Revenue Dashboard UI (sales statistics, monthly statement table).
- [ ] Build Admin Revenue Settlement UI (generate statements, confirm transfer record).

### ⚙️ Phase 2: Backend Execution & API Design
- [x] Set up `payments`, `revenue_records`, `monthly_statements` tables.
- [x] Write PayOS payment integration (generate payment URL, verify webhook checksum, idempotent success handler).
- [x] Implement API `GET /api/v1/payment/my-history` for Learner to retrieve purchase history.
- [x] Implement duplicate enrollment guard on payment creation.
- [x] Write auto revenue splitter logic (Gross -> TrainerShare / PlatformShare based on TrainerType 70/30 or 60/40) upon successful payment.
- [ ] Implement background scheduler job to automatically generate Monthly Statements.
- [ ] Create Trainer APIs (`GET /api/v1/trainer/revenue`, `POST /api/v1/trainer/statements/{id}/confirm`).
- [ ] Create Admin settlement APIs (`GET /api/v1/admin/statements`, `PUT /api/v1/admin/statements/{id}/pay`).

### 🔌 Phase 3: Integration
- [x] Integrate checkout redirection / QR dialog to PayOS environment.
- [x] Connect order tracking and webhook IPN processing.
- [x] Connect Purchase History UI to Backend API.
- [ ] Connect Revenue Dashboard for Trainers and Settlement views for Admins.

### 🚨 Phase 4: Quality Assurance
- [x] Test double-payment IPN (idempotency checks).
- [x] Test PayOS signature checks and duplicate enrollment protection.
- [ ] Validate manual transfer record flow by Admin.

---

## 🚀 [FE-13] Comment Management
### 🎨 Phase 1: Frontend UI & Mock Data
- [x] Build recursive nested Comment Widget (displays replies, likes).
- [x] Mount Comment Section under Lessons and Quizzes (Course level only has rating).

### ⚙️ Phase 2: Backend Execution & API Design
- [x] Set up `comments` table with self-referencing hierarchy (`parent_comment_id`).
- [x] Optimize database queries using `JOIN FETCH` to avoid N+1 queries.
- [x] Implement APIs for listing, posting, and replying.
- [x] Create Admin comment moderation API (`DELETE /api/v1/admin/comments/{id}`).

### 🔌 Phase 3: Integration
- [x] Integrate nested comments list fetching and posting comment/replies.
- [x] Integrate comment moderation dashboard for Admins.

### 🚨 Phase 4: Quality Assurance
- [ ] Validate profanity filters and XSS sanitization on comment submissions.

---

## 🚀 [FE-14] Notification
### 🎨 Phase 1: Frontend UI & Mock Data
- [ ] Build Notification Center Dropdown UI (with red unread count badge).
- [ ] Mount WebSocket Client listener to receive realtime pushes.

### ⚙️ Phase 2: Backend Execution & API Design
- [ ] Configure Spring Boot **WebSocket** with STOMP message broker.
- [ ] Set up `notifications` table and `ApplicationEventPublisher` (Spring Events) for async notification dispatching (`@Async`).
- [ ] Set up triggers for the following events:
  - Learner: PurchaseSuccess, CourseUpdated, CommentReply.
  - Trainer: NewEnrollment, CommentReply, ContentApproved, ContentRejected, StatementReady.
- [ ] Implement JavaMailSender for email notifications (OTP verification, Reset Password, Purchase Success).

### 🔌 Phase 3: Integration
- [ ] Integrate WebSocket client on frontend to listen to user-specific queues.
- [ ] Connect Notification Listing and Mark-as-read APIs.

### 🚨 Phase 4: Quality Assurance
- [ ] Test WebSocket connection recovery under network loss.
- [ ] Ensure email delivery runs asynchronously and does not block API threads.
