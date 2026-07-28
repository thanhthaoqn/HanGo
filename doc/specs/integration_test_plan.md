# HanGo — Integration Test Plan (manual, HTTP-level)

**Project Name:** HanGo — Smart Language Self-Study Platform
**Project Code:** HANGO
**Test Level:** Integration Testing (Controller → Service → Repository → DB), executed **manually** over real HTTP — no JUnit/MockMvc code, no Testcontainers/H2. This is a companion to, not a replacement for, the existing Service-layer unit tests (see [`unit_test_plan.md`](unit_test_plan.md)).
**Test Environment Setup Description:**
1. HanGo Backend (Spring Boot, Java 17) running locally — `cd hango-backend && mvnw spring-boot:run`, or a packaged jar. Default port from `application.properties` (`server.port`, typically `8080`).
2. Database: **MySQL 8.0**, pointed at a **disposable local/scratch schema** — never the production DB. Use `application.properties.example` as a template for a local `application.properties`.
3. HTTP client: **Postman** (recommended — collections + environments make Round 2/3 re-runs fast) or `curl`/VS Code REST Client.
4. Browser: **Microsoft Edge or Google Chrome**, DevTools (**F12**) — needed only for the test cases explicitly marked "DevTools Evidence: Yes" (see §2).
5. `doc/templates/*.xlsx` (Course/Exam/Question-Bank import templates) — needed for the Excel-import test cases in Course/Exam/Question-Bank sheets.

> **Code-first principle applies here too** (see `TESTING.md` §0): every test case below is written against the **real, current controller code** (all 26 `@RestController` classes read directly, cross-checked against `SecurityConfig.java`, `unit_test_plan.md`, and `AUDIT_REPORT.md`), not against the narrative in `HanGo_Documentation.md`/`doc/specs/0X-*.md` alone. Several test cases **deliberately target already-confirmed gaps** (missing `@PreAuthorize`, IDOR, answer leaks, unvalidated DTOs) so that running this plan either proves the gap still exists or proves it was fixed — never silently assume the secure/ideal behavior.
> **Status discipline:** every Round cell in every sheet starts **Pending**. Per standing project rule, never mark a case Passed/Failed until it has actually been executed.

---

## 1. Test Case List (master sheet)

One row per function. `Module` matches `doc/specs/0X-*.md` 1:1. `Sheet File` is the detailed CSV under `doc/specs/` containing that function's test cases.

| No | Function Name | Module | Controller | Description | Pre-Condition | Sheet File |
|---|---|---|---|---|---|---|
| 1 | Login | Authentication | AuthController | Email+password login, issues single JWT | Account exists | itc-sheet-authentication.csv |
| 2 | Register | Authentication | AuthController | Self-service Learner/Trainer registration | Email not in use | itc-sheet-authentication.csv |
| 3 | Google Login | Authentication | AuthController | Sign in with Google (JIT provisioning) | Valid Google ID token | itc-sheet-authentication.csv |
| 4 | Forgot Password | Authentication | AuthController | Sends 6-digit OTP by email | Registered email | itc-sheet-authentication.csv |
| 5 | Verify OTP | Authentication | AuthController | Validates OTP before reset | OTP requested | itc-sheet-authentication.csv |
| 6 | Reset Password | Authentication | AuthController | Sets new password via OTP flow | Valid unexpired OTP | itc-sheet-authentication.csv |
| 7 | Verify Account (email link) | Authentication | AuthController | Marks account verified via emailed link | Unverified account | itc-sheet-authentication.csv |
| 8 | Check Verification Status | Authentication | AuthController | Polls whether account is verified | none | itc-sheet-authentication.csv |
| 9 | Resend Verification Email | Authentication | AuthController | Re-sends the verification email | Unverified account | itc-sheet-authentication.csv |
| 10 | View Own Profile | Profile Management | UserController | `GET /api/v1/users/me` | Logged in | itc-sheet-profile.csv |
| 11 | Update Own Profile | Profile Management | UserController | `PUT /api/v1/users/me` | Logged in | itc-sheet-profile.csv |
| 12 | Change Password (logged-in) | Profile Management | UserController | `PUT /api/v1/users/change-password` | Logged in, knows current password | itc-sheet-profile.csv |
| 13 | Upload Avatar | Profile Management | AuthController | `POST /api/auth/profile/avatar` (Cloudinary) | Logged in, LEARNER/TRAINER/TRAINER_LEAD/ADMINISTRATOR | itc-sheet-profile.csv |
| 14 | View Dashboard Stats | RBAC / Account Mgmt | AdminController | Admin home stats | ADMINISTRATOR | itc-sheet-rbac.csv |
| 15 | View Account List | RBAC / Account Mgmt | AdminController | Paged/filtered user list | ADMINISTRATOR | itc-sheet-rbac.csv |
| 16 | View Account Detail | RBAC / Account Mgmt | AdminController | Single user detail | ADMINISTRATOR | itc-sheet-rbac.csv |
| 17 | Create Account | RBAC / Account Mgmt | AdminController | Admin creates a user directly | ADMINISTRATOR | itc-sheet-rbac.csv |
| 18 | Update Account | RBAC / Account Mgmt | AdminController | Edit user incl. role/status | ADMINISTRATOR | itc-sheet-rbac.csv |
| 19 | Update Account Status | RBAC / Account Mgmt | AdminController | Activate/deactivate a user | ADMINISTRATOR | itc-sheet-rbac.csv |
| 20 | View Audit Log | RBAC / Account Mgmt | AdminController | User-management action log | ADMINISTRATOR | itc-sheet-rbac.csv |
| 21 | View AI Usage Stats | RBAC / Account Mgmt | AdminController | Gemini call usage/cost stats | ADMINISTRATOR | itc-sheet-rbac.csv |
| 22 | Become Trainer | Trainer Onboarding | TrainerOnboardingController | Upgrades role to TRAINER immediately | Logged in (any role) | itc-sheet-trainer-onboarding.csv |
| 23 | View Own Trainer Profile | Trainer Onboarding | TrainerOnboardingController | JIT-creates profile if missing | TRAINER/ADMIN/TRAINER_LEAD | itc-sheet-trainer-onboarding.csv |
| 24 | Save Trainer Profile Draft | Trainer Onboarding | TrainerOnboardingController | Save without submitting | TRAINER/ADMIN/TRAINER_LEAD | itc-sheet-trainer-onboarding.csv |
| 25 | Submit Trainer Profile for Review | Trainer Onboarding | TrainerOnboardingController | Moves to review queue | TRAINER/ADMIN/TRAINER_LEAD | itc-sheet-trainer-onboarding.csv |
| 26 | View Trainer Profiles List (Admin) | Trainer Onboarding | TrainerOnboardingController | Search/filter applications | ADMINISTRATOR | itc-sheet-trainer-onboarding.csv |
| 27 | Review Trainer Profile (Admin) | Trainer Onboarding | TrainerOnboardingController | Approve (VERIFIED)/Suspend | ADMINISTRATOR | itc-sheet-trainer-onboarding.csv |
| 28 | Browse/Search Course List | Course Management | CourseController | Public catalog | none (public) | itc-sheet-course.csv |
| 29 | View Course Detail | Course Management | CourseController | Public detail + own progress if logged in | none (public) | itc-sheet-course.csv |
| 30 | Enroll Course | Course Management | CourseController | Free enroll / after purchase | Logged in | itc-sheet-course.csv |
| 31 | Unenroll Course | Course Management | CourseController | Leaves a course | Enrolled | itc-sheet-course.csv |
| 32 | Switch Course Version | Course Management | CourseController | Move enrollment to another version | Enrolled, versions exist | itc-sheet-course.csv |
| 33 | View / Add / Delete Course Review | Course Management | CourseController | Rating & review | Enrolled + COMPLETED for add | itc-sheet-course.csv |
| 34 | View Course Version History | Course Management | CourseController | List of versions | Course has versions | itc-sheet-course.csv |
| 35 | Upload Course File / Import Template / Import Excel | Course Management | TrainerDashboardController | Authoring file helpers | TRAINER/ADMIN/TRAINER_LEAD/COURSE_MANAGER | itc-sheet-course.csv |
| 36 | Create / Update / Delete Trainer Course | Course Management | TrainerDashboardController | Course CRUD (Draft) | TRAINER/ADMIN/TRAINER_LEAD/COURSE_MANAGER | itc-sheet-course.csv |
| 37 | Submit / Publish / Approve / Reject Trainer Course | Course Management | TrainerDashboardController | Trainer-side workflow (diverges from Course-Manager path, HIGH-04) | owner Trainer / ADMIN / TRAINER_LEAD / COURSE_MANAGER per-endpoint | itc-sheet-course.csv |
| 38 | View Trainer Dashboard / Course List | Course Management | TrainerDashboardController | Own courses, stats | TRAINER/ADMIN/TRAINER_LEAD/COURSE_MANAGER | itc-sheet-course.csv |
| 39 | View Course-Manager Dashboard | Course Management | CourseManagerDashboardController | Aggregate stats | TRAINER_LEAD/COURSE_MANAGER/ADMIN | itc-sheet-course.csv |
| 40 | View Courses for Review / Review Detail | Course Management | CourseManagerDashboardController | Review queue reads | TRAINER_LEAD/COURSE_MANAGER/ADMIN | itc-sheet-course.csv |
| 41 | Publish / Reject Course (Course Manager) | Course Management | CourseManagerDashboardController | Second, divergent approve/reject path (HIGH-04) | TRAINER_LEAD/COURSE_MANAGER/ADMIN | itc-sheet-course.csv |
| 42 | View Lesson Detail | Course Content Mgmt | LessonController | Lesson content + quiz questions | none (public, CRIT-02) | itc-sheet-course-content.csv |
| 43 | Mark Lesson Complete | Course Content Mgmt | LessonController | Progress tracking | userId param (CRIT-02: unchecked) | itc-sheet-course-content.csv |
| 44 | Get / Submit Quiz Attempt (Lesson) | Course Content Mgmt | LessonController | Lesson-quiz attempts | userId param (CRIT-02: unchecked) | itc-sheet-course-content.csv |
| 45 | View Sections & Question Counts | Course Content Mgmt | SectionQuestionController | Per-course section list | any authenticated (CRIT-04: no role gate) | itc-sheet-course-content.csv |
| 46 | View Section/Lesson Questions | Course Content Mgmt | SectionQuestionController | Paged question list incl. answers | any authenticated (CRIT-04) | itc-sheet-course-content.csv |
| 47 | Select Questions for Quiz | Course Content Mgmt | SectionQuestionController | Random/sequential picker | any authenticated (CRIT-04) | itc-sheet-course-content.csv |
| 48 | Save Questions to Lesson Quiz | Course Content Mgmt | SectionQuestionController | Attach questions to a lesson quiz | any authenticated (CRIT-04) | itc-sheet-course-content.csv |
| 49 | Create / Update Question (single) | Course Content Mgmt | SectionQuestionController | Question CRUD | any authenticated (CRIT-04) | itc-sheet-course-content.csv |
| 50 | Create Group Question (passage) | Course Content Mgmt | SectionQuestionController | Passage + sub-questions | any authenticated (CRIT-04) | itc-sheet-course-content.csv |
| 51 | View Trainer Question List | Question Bank Mgmt | TrainerQuestionController | List/search/sort | TRAINER/ADMIN/TRAINER_LEAD | itc-sheet-question-bank.csv |
| 52 | Create Question Bank Group | Question Bank Mgmt | TrainerQuestionController | Create single/group question | TRAINER/ADMIN/TRAINER_LEAD | itc-sheet-question-bank.csv |
| 53 | View Question Detail | Question Bank Mgmt | TrainerQuestionController | Fetch for edit | TRAINER/ADMIN/TRAINER_LEAD | itc-sheet-question-bank.csv |
| 54 | Update Question Bank Group | Question Bank Mgmt | TrainerQuestionController | Full delete+recreate on edit | TRAINER/ADMIN/TRAINER_LEAD | itc-sheet-question-bank.csv |
| 55 | Update Question Status | Question Bank Mgmt | TrainerQuestionController | Activate/Archive | TRAINER/ADMIN/TRAINER_LEAD | itc-sheet-question-bank.csv |
| 56 | Generate Question via AI | Question Bank Mgmt | TrainerQuestionAIController | LLM-generated question(s) | any authenticated (no role gate) | itc-sheet-question-bank.csv |
| 57 | Browse Exam List (Learner) | Exam Management | ExamController | Public list, status filter | none (public) | itc-sheet-exam.csv |
| 58 | View Exam Questions (take exam) | Exam Management | ExamController | Answer-safe question list | none (public) | itc-sheet-exam.csv |
| 59 | View My / Exam Attempts | Exam Management | ExamController | Attempt history | logged in | itc-sheet-exam.csv |
| 60 | Submit Exam Attempt | Exam Management | ExamController | Server-recomputed score | logged in | itc-sheet-exam.csv |
| 61 | Trainer Exam CRUD (create/questions/status/visibility/delete) | Exam Management | TrainerDashboardController | Exam authoring | TRAINER/ADMIN/TRAINER_LEAD/COURSE_MANAGER | itc-sheet-exam.csv |
| 62 | View Exams for Review / Publish / Reject | Exam Management | CourseManagerDashboardController | Exam review queue | TRAINER_LEAD/COURSE_MANAGER/ADMIN | itc-sheet-exam.csv |
| 63 | Exam Matrix CRUD + Generate | Exam Management | TrainerExamMatrixController / CourseManagerExamMatrixController | Criteria-based auto-exam build | role varies by endpoint (see sheet) | itc-sheet-exam.csv |
| 64 | Import Exam from Excel + Template | Exam Management | ExamImportController | Bulk exam+question import | TRAINER/ADMIN/TRAINER_LEAD | itc-sheet-exam.csv |
| 65 | Send Message to AI Assistant | AI Assistant | AIAssistantController | Scope-guarded lesson Q&A | logged in (service-layer guard only) | itc-sheet-ai-assistant.csv |
| 66 | View Conversation History | AI Assistant | AIAssistantController | Past AI chats | logged in (no guard — gap) | itc-sheet-ai-assistant.csv |
| 67 | Check AI Service Status | AI Assistant | AIAssistantController | Health check | none | itc-sheet-ai-assistant.csv |
| 68 | Generate Learning Pathway | Learning Mgmt | LearningPathwayController | AI-built roadmap from exam weakness | LEARNER | itc-sheet-learning.csv |
| 69 | View My / Pathway Detail | Learning Mgmt | LearningPathwayController | Own roadmap | LEARNER (ownership gap on `/{id}`) | itc-sheet-learning.csv |
| 70 | Reroute Pathway (+ suggestions/accept/decline) | Learning Mgmt | LearningPathwayController | Adaptive re-planning | LEARNER | itc-sheet-learning.csv |
| 71 | Apply / View Pathway Schedule | Learning Mgmt | LearningPathwayController | Timeboxing | LEARNER | itc-sheet-learning.csv |
| 72 | View Progress Snapshot | Learning Mgmt | LearningPathwayController | Per-node status | LEARNER | itc-sheet-learning.csv |
| 73 | Merge Preview / Confirm | Learning Mgmt | LearningPathwayController | Multi-course pathway merge | LEARNER | itc-sheet-learning.csv |
| 74 | Chat with Pathway Mentor | Learning Mgmt | LearningPathwayController | AI chat on pathway | LEARNER | itc-sheet-learning.csv |
| 75 | Recommend Courses via AI | Recommendation | ExamCourseRecommendationController | Weakness → course suggestion | logged in (IDOR gap, no ownership check) | itc-sheet-recommendation.csv |
| 76 | Create Payment (Checkout) | Payment & Revenue | PaymentController | PayOS checkout-link creation | logged in, non-empty cart/course | itc-sheet-payment.csv |
| 77 | Handle PayOS Webhook | Payment & Revenue | PaymentController | Server-to-server payment confirm | valid PENDING Payment + correct HMAC | itc-sheet-payment.csv |
| 78 | View My Payment History / Status | Payment & Revenue | PaymentController | Learner-side payment records | logged in | itc-sheet-payment.csv |
| 79 | Cart CRUD + Sync | Payment & Revenue | CartController | Get/add/remove/clear/sync | logged in | itc-sheet-payment.csv |
| 80 | View Trainer Revenue Summary / Statements | Payment & Revenue | MonthlyStatementController | Trainer-side earnings | TRAINER/TRAINER_LEAD/TEACHER | itc-sheet-payment.csv |
| 81 | Confirm Trainer Statement | Payment & Revenue | MonthlyStatementController | Trainer confirms figures | TRAINER/TRAINER_LEAD/TEACHER, owner | itc-sheet-payment.csv |
| 82 | View / Generate Course-Manager Statements | Payment & Revenue | MonthlyStatementController | Cutoff generation | TRAINER_LEAD/COURSE_MANAGER/ADMIN | itc-sheet-payment.csv |
| 83 | Settle Statement | Payment & Revenue | MonthlyStatementController | Marks PAID + bank ref | TRAINER_LEAD/COURSE_MANAGER/ADMIN | itc-sheet-payment.csv |
| 84 | View Lesson Comments | Comment Management | CommentController | Public comment thread | none (public, gap) | itc-sheet-comment.csv |
| 85 | Add / Update / Delete Comment | Comment Management | CommentController | No auth enforced (CRIT-02-class gap) | none (public, gap) | itc-sheet-comment.csv |
| 86 | Like / Unlike Comment | Comment Management | CommentController | Same gap as above | none (public, gap) | itc-sheet-comment.csv |
| 87 | View All / Detail Comments (Admin) | Comment Management | AdminCommentController | Moderation queue | ADMINISTRATOR | itc-sheet-comment.csv |
| 88 | Update Comment Status (Admin) | Comment Management | AdminCommentController | No status whitelist (gap) | ADMINISTRATOR | itc-sheet-comment.csv |
| 89 | Delete Comment (Admin) | Comment Management | AdminCommentController | Hard delete | ADMINISTRATOR | itc-sheet-comment.csv |
| 90 | View Notifications / Unread Count | Notification | NotificationController | Personal inbox (poll-based) | logged in | itc-sheet-notification.csv |
| 91 | Mark (All) Notifications as Read | Notification | NotificationController | Ownership/role-membership enforced | logged in | itc-sheet-notification.csv |
| 92 | View / Mark Course-Manager Notifications | Notification | CourseManagerDashboardController | TRAINER_LEAD-only inbox variant | TRAINER_LEAD only | itc-sheet-notification.csv |

**Excluded on purpose:** `TestDBController` (`/api/test-db/**`) is **not** in this plan — per `ROADMAP.md` P0#2 it is a known, unauthenticated credential-reset security hole slated for removal from the deploy build, not a feature to validate.

---

## 2. Column & convention legend (applies to every `itc-sheet-*.csv`)

Each CSV starts with a small feature-summary header (Feature name, Test requirement, Number of TCs, a Round 1/2/3 Passed/Failed/Pending/N-A rollup — all initialized to Pending), then the test-case table:

| Column | Meaning |
|---|---|
| Test Case ID | `<MODULE>_IT##` — `IT` = Integration Test, distinct from unit tests' `UTC##` so the two layers never collide. |
| Description | One line: what is being verified. |
| Procedure | Numbered concrete steps: HTTP method + path, headers, body. Steps prefixed **🔍** are DevTools/Network-tab inspection steps (see below). |
| Expected Result | What must be true for a Pass — status code, response fields, DB/UI side effects. Where the case targets a **confirmed gap**, the Expected Result states the **current (buggy) behavior**, with a Note explaining what the secure/correct behavior *should* be — so a tester isn't confused about which one counts as "Pass" today. |
| Pre-conditions | Data/state/role needed before starting. |
| DevTools Evidence | **Yes — <what to check>** or **No — response body is sufficient**. See below for when Yes applies. |
| Case Type | `N` (happy/normal path) / `A` (abnormal / error path) / `B` (boundary/edge case) — same convention as `utc-sheet-*.csv`. |
| Round 1/2/3 Status, Date, Tester | Filled in only after actually running the case. Status ∈ `Passed`/`Failed`/`Pending`/`N/A`. |
| Note | Cross-references to `unit_test_plan.md`/`AUDIT_REPORT.md` gap IDs, caveats, or follow-up items. |

### When DevTools (F12 → Network tab) is required

Mark **DevTools Evidence: Yes** whenever Postman's response pane alone can't prove the point — typically:
- **Proving a security gap**: confirming a request was sent with **no `Authorization` header at all** and still got a 200 (impersonation/missing-auth cases). Postman lets you omit the header on purpose, but the *grading/proof* value of DevTools is that it shows the **exact real request the running frontend (or your manual fetch) sent**, including cookies/headers you didn't set explicitly.
- **Response shape/leak checks**: confirming a field that should never appear (e.g. `correctIndex`, `isCorrect`, bank account details) is or isn't present in the raw JSON body, not just in a parsed/pretty-printed view that might hide extra fields.
- **Status code precision**: several controllers return `401` vs `403` vs `400` inconsistently for what looks like the same class of failure (see individual sheets) — the Network tab's top summary line is the authoritative source, not an assumption from the error message text.
- **Cookies/headers**: HanGo issues **one JWT, no refresh cookie** — any test case that might tempt someone to look for a `Set-Cookie`/refresh mechanism should explicitly confirm via DevTools **Headers** tab that none exists (documented as `GAP-AUTH-03`, not a bug to "find").

When a case is marked **Yes**, the Procedure column spells out exactly what to open: e.g. *"🔍 F12 → Network tab → find the request → **Headers** tab: confirm no `Authorization` header was sent → **Response** tab: confirm status `200` and body contains `id`."*

Cases marked **No** are fully verifiable from Postman's own response viewer (status code + JSON body) — no browser needed.

---

## 3. How to execute these tests yourself

### 3.1 Environment
1. Point `hango-backend/src/main/resources/application.properties` (copy from `.example`) at a **local scratch MySQL schema** — never a shared/prod DB, since these tests create/modify/delete real rows (users, courses, payments…).
2. `cd hango-backend && mvnw spring-boot:run`. Confirm it's up: `GET http://localhost:8080/api/v1/metadata/categories` should respond (401/200 depending on whether you're authenticated — either response means the server is alive).
3. Keep Postman open with an **Environment** holding variables: `baseUrl`, `tokenLearner`, `tokenTrainer`, `tokenTrainerLead`, `tokenAdmin` — refreshed each session since there is no refresh token (single JWT, see AUTH_IT gap notes).

### 3.2 Getting accounts for every role
HanGo roles: `LEARNER`, `TRAINER` (dual-mode, includes Learner capabilities), `TRAINER_LEAD` (= "Course Manager" — code accepts both `TRAINER_LEAD` and `COURSE_MANAGER` authority strings interchangeably in many `@PreAuthorize`s, a known cleanup-in-progress per `HanGo_Documentation.md` §2), `ADMINISTRATOR`.
- Register a LEARNER via `POST /api/auth/register`.
- Promote to TRAINER via `POST /api/v1/trainers/become-trainer` (see AUTH/TRN sheets) — grants the role immediately, no approval needed for dashboard access (only for publishing).
- TRAINER_LEAD/ADMINISTRATOR accounts must be seeded directly in the DB (no self-service upgrade path exists) — e.g. `UPDATE users u JOIN user_roles ur ON ... SET r.role_name='TRAINER_LEAD' WHERE u.email='...'` (check the actual schema/`Role`/`UserRole` tables before writing raw SQL — do this once per scratch DB, not on shared data).

### 3.3 Authenticating requests
1. `POST /api/auth/login` with `{email, password}` → copy the `token` field from the response.
2. Every subsequent request: header `Authorization: Bearer <token>`.
3. **There is no refresh endpoint** (`GAP-AUTH-03`) — when a token expires, log in again. Do not spend time looking for a refresh-token flow; it does not exist in this codebase.

### 3.4 Opening DevTools → Network tab (for any case marked "DevTools Evidence: Yes")
1. Open the relevant page in **Edge/Chrome**, press **F12** (or right-click → Inspect), go to the **Network** tab.
2. Tick **Fetch/XHR** filter to cut noise.
3. Trigger the action from the actual UI (or, if testing a raw endpoint with no UI yet, send the request from Postman — Postman itself has a **Console** with equivalent header/body visibility, use `View → Show Postman Console`).
4. Click the request row → **Headers** tab shows exactly what was sent (confirm/deny `Authorization`) and received (status line, `Set-Cookie` if any). **Response**/**Preview** tab shows the raw JSON body — expand every field, don't trust a summarized/collapsed view when checking for a leaked field like `correctIndex`.
5. For screenshots-as-evidence (e.g. for grading): capture the **Headers** tab (method/status/URL) and the **Response** tab together — a screenshot of just the status code without the URL/method is not sufficient proof of which test case it corresponds to.

### 3.5 Testing the PayOS webhook manually
PayOS calls back your server directly; it cannot reach `localhost`. To test `POST /api/v1/payment/payos-webhook` manually:
1. Create a payment via `POST /api/v1/payment/create` first, note the returned order/txnRef.
2. Build the webhook JSON payload yourself (see `PaymentServiceImplTest` for the exact field shape PayOS sends and how the HMAC-SHA256 signature over the sorted-key query string is computed) and sign it with the same `PAYOS_CHECKSUM_KEY` your local `application.properties` uses.
3. POST that payload directly to your own running server. This proves the signature-verification and idempotency logic without needing a real PayOS sandbox.

### 3.6 Testing Excel import flows
Use the real template files already in the repo: `doc/templates/Hango_Course_Import_Template.xlsx`, `Hango_Exam_Import_Template.xlsx`, `Hango_Question_Bank_Import_Template.xlsx`. Fill a copy with a few rows before uploading via Postman's `form-data` body type (key `file`, type File).

### 3.7 Recording results
For each test case you actually run: set that Round's **Status** to `Passed`/`Failed`/`N/A`, fill **Date** and **Tester**, and add a one-line **Note** if it failed or behaved differently than expected. Re-running the same sheet later (regression) fills Round 2, then Round 3 — don't overwrite a prior round's data.

---

## 4. Sheet index

| File | Module |
|---|---|
| `itc-sheet-authentication.csv` | Authentication |
| `itc-sheet-profile.csv` | Profile Management |
| `itc-sheet-rbac.csv` | RBAC / Account Management |
| `itc-sheet-trainer-onboarding.csv` | Trainer Onboarding |
| `itc-sheet-course.csv` | Course Management |
| `itc-sheet-course-content.csv` | Course Content Management |
| `itc-sheet-question-bank.csv` | Question Bank Management |
| `itc-sheet-exam.csv` | Exam Management |
| `itc-sheet-ai-assistant.csv` | AI Assistant |
| `itc-sheet-learning.csv` | Learning Management |
| `itc-sheet-recommendation.csv` | Recommendation |
| `itc-sheet-payment.csv` | Payment & Revenue |
| `itc-sheet-comment.csv` | Comment Management |
| `itc-sheet-notification.csv` | Notification |
