# HanGo — System Test Plan (manual, end-to-end / black-box)

**Project Name:** HanGo — Smart Language Self-Study Platform
**Project Code:** HANGO
**Test Level:** System Testing — end-to-end, black-box, executed **manually through the actual running application** (Flutter frontend + Spring Boot backend + MySQL), not at the HTTP/API level. This is the third and outermost layer of the test pyramid already in place for HanGo:
1. [`unit_test_plan.md`](unit_test_plan.md) + `utc-sheet-*.csv` — automated Service-layer unit tests (JUnit).
2. [`integration_test_plan.md`](integration_test_plan.md) + `itc-sheet-*.csv` — manual, HTTP-level integration tests per controller/module (Postman).
3. **This document** + `sys-sheet-*.csv` — manual, UI-driven **end-to-end workflow** tests that cross multiple modules the way a real user actually experiences them, not one controller at a time.

**Test Environment Setup Description:**
1. **Backend:** HanGo Backend (Spring Boot, Java 17) running locally — `cd hango-backend && mvnw spring-boot:run`, pointed at a **disposable local/scratch MySQL 8.0 schema** (copy `application.properties.example`) — never the production DB, since these tests create/modify/delete real users, courses, payments, and enrollments.
2. **Frontend:** HanGo Frontend (Flutter) — `cd hango-frontend && flutter run` targeting a web (`-d chrome`) or emulator/device build pointed at the local backend's base URL.
3. **Email:** a reachable mailbox or local mail-catcher for OTP/verification/notification emails (`EmailService`), since several workflows (Auth, Trainer Onboarding, Payment, Statement settlement) depend on real emails being received.
4. **PayOS:** sandbox/test PayOS credentials configured in `application.properties` for the Payment & Revenue flows (`SYS_FLOW_ENR`), including the ability to complete a test payment and receive its webhook.
5. **AI Provider:** a valid Gemini API key configured for the AI Assistant / Recommendation / Learning Pathway flows (`SYS_FLOW_AIR`, `SYS_FLOW_PWY`) — these workflows cannot be meaningfully tested with the AI provider unreachable.
6. **Browser DevTools (F12):** only needed opportunistically, for the handful of cases that explicitly call for inspecting a raw response payload (e.g. confirming no `isCorrect` leak during an in-progress Exam, `SYS_FLOW_EXM_TC20`). Unlike the IT-level plan, System Test is UI-driven by default and does not carry a dedicated DevTools-evidence column.

> **Code-first principle applies here too** (see `TESTING.md` §0 and `integration_test_plan.md` §"Code-first principle"): every workflow and expected result below is written against the **current, real implementation** — cross-checked against all 14 `doc/specs/0X-*.md` feature specs (each carrying its own 2026-07-24 code-audit corrections) and the existing `itc-sheet-*.csv` / `unit_test_plan.md` findings — not against aspirational documentation. Several cases **deliberately target already-known gaps** (e.g. `GAP-EXM-01` answers-echo bug, `GAP-AUTH-03` no refresh token, the HIGH-04 dual approve/reject paths, unresolved ownership questions on Pathway/AI-conversation/Recommendation endpoints) so that running the plan either reconfirms the gap or proves it was fixed — never silently assumes the ideal/secure behavior.
> **Status discipline:** every Round cell in every sheet starts **Pending**. Per standing project rule, never mark a case Passed/Failed until it has actually been executed.

---

## 1. Test Case List (master sheet)

One row per end-to-end workflow. Each workflow deliberately **crosses multiple modules** the way a real user's journey does — see each sheet's own "Test requirement" line for the exact module coverage.

| No | Function Name | Sheet Name | Description | Pre-Condition |
|---|---|---|---|---|
| 1 | Authentication - Registration- Verification & Login Flow | sys-sheet-authentication-access-flow.csv | Self-registration, email verification, login/session, forgot/reset password via OTP, Google sign-in, and the role-based access boundary. | Mailbox reachable; Google OAuth2 test client configured. |
| 2 | Trainer Onboarding & Profile Approval Flow | sys-sheet-trainer-onboarding-flow.csv | Becoming a Trainer, building/submitting the profile application, Admin approve/reject/suspend, resubmission, and the publishing rights unlocked only after approval. | A Learner account able to become a Trainer; an Administrator account. |
| 3 | Course Authoring- Content Building & Publishing Flow | sys-sheet-course-authoring-publishing-flow.csv | Draft course creation, Section/Lesson/LessonBlock/Quiz authoring (manual + Excel import), Submit, Course Manager review/publish/reject (both existing review paths), public catalog visibility, and editing-a-Published-course versioning. | A VERIFIED Trainer account; a Course Manager (TRAINER_LEAD) account. |
| 4 | Course Discovery- Cart- PayOS Payment & Enrollment Flow | sys-sheet-course-purchase-enrollment-flow.csv | Browsing, free-course direct enrollment, Cart CRUD, PayOS checkout/QR payment, webhook-driven auto-enrollment and notifications, payment history, reviews, unenroll/switch-version. | At least one Published free course and one Published paid course; PayOS sandbox reachable. |
| 5 | Lesson Learning- Quiz & Progress Tracking Flow | sys-sheet-lesson-learning-progress-flow.csv | Sequential Lesson unlocking, Lesson Quiz attempts, progress-percentage tracking, Continue Learning resume, structure-change recalculation, lifetime access, access-boundary guards. | Learner enrolled in a multi-lesson course. |
| 6 | Exam Authoring- Matrix Generation- Review & Taking Flow | sys-sheet-exam-authoring-taking-flow.csv | Trainer/Course Manager Exam authoring (manual, matrix, Excel import), review/publish, and the Learner-side timed exam-taking, submission, scoring, and attempt history. | A VERIFIED Trainer, a Course Manager, and a Learner account. |
| 7 | AI-Generated Learning Pathway Flow | sys-sheet-ai-learning-pathway-flow.csv | Generating a roadmap from Exam-based Weakness Analysis, viewing pathway/nodes/schedule/progress, reroute suggestion accept/decline, multi-course merge, chatting with the Pathway Mentor. | Learner with at least one completed Exam attempt; Gemini API reachable. |
| 8 | AI Assistant Q&A & Course Recommendation Flow | sys-sheet-ai-assistant-recommendation-flow.csv | In-lesson AI Assistant chat (scope guardrail, prompt-injection resistance, Markdown rendering), conversation history, AI service status, AI usage logging, Exam-weakness-driven Course Recommendation. | Learner with Lesson access; Gemini API reachable. |
| 9 | Lesson Comment- Like & Moderation Flow | sys-sheet-comment-moderation-flow.csv | Posting on a Lesson/Quiz, the Rule Engine's APPROVED/PENDING/REJECTED outcomes and visibility rules, edit re-evaluation, reply/like, own-comment management, Admin moderation. | Two Learner accounts with access to the same Lesson; an Administrator account. |
| 10 | Cross-Module Notification Delivery & Read-Tracking Flow | sys-sheet-notification-delivery-flow.csv | Every implemented trigger surfacing to the right recipient, the polling-based Bell/inbox UI, ownership/role-broadcast read-state boundaries, dangling-linked-resource and Course-Manager-only inbox handling. | Events from other workflows already exercised (purchase, comment reply, review decisions, statement, low rating). |
| 11 | Trainer Revenue- Monthly Statement & Settlement Flow | sys-sheet-trainer-revenue-settlement-flow.csv | Course-sale revenue split by Trainer type, on-demand Monthly Statement generation, Trainer confirmation, manual bank-transfer settlement, and the Admin/revenue separation-of-duties boundary. | A Trainer with recent paid-course sales; a Course Manager and an Administrator account. |
| 12 | Account- Role & Access Administration Flow | sys-sheet-account-access-administration-flow.csv | Dashboard stats accuracy, account search/detail, account creation with role whitelisting, activate/deactivate and self-lock protection, Update Account whitelist guards, Audit Log's real scope, AI Usage stats, Administrator-only access boundary. | An Administrator account; several test user accounts across roles. |

**Total test cases across all 12 sheets: 207.**

**Excluded on purpose:** `TestDBController` (`/api/test-db/**`) is not exercised here either — same rationale as `integration_test_plan.md` (known unauthenticated credential-reset hole slated for removal, not a feature to validate). Profile Management (view/edit own profile, avatar, change password) is exercised inline as a supporting step inside other workflows (e.g. Trainer profile in Flow 2, account edits in Flow 12) rather than as its own top-level workflow, since it has no multi-actor end-to-end journey of its own beyond what `itc-sheet-profile.csv` already covers at the API level.

---

## 2. Column & convention legend (applies to every `sys-sheet-*.csv`)

Each CSV starts with a small workflow-summary header (Workflow, Test requirement, Number of TCs, a Round 1/2/3 Passed/Failed/Pending/N-A rollup — all initialized to Pending), then the test-case table. Rows with a stage name and empty remaining columns (e.g. `Self-Registration & Email Verification,,,,,...`) are section dividers grouping test cases by stage within the workflow — not test cases themselves.

| Column | Meaning |
|---|---|
| Test Case ID | `SYS_FLOW_<ABBR>_TC##` — distinct from the unit-test `UTC##` and integration-test `<MODULE>_IT##` conventions so all three layers never collide in the same tracker. `<ABBR>` matches the workflow: `AUTH`, `TRN`, `CRS`, `ENR`, `LRN`, `EXM`, `PWY`, `AIR`, `CMT`, `NTF`, `REV`, `ADM`. |
| Test Case Description | One line: what end-to-end behavior is being verified. |
| Test Case Procedure | Numbered concrete UI steps (open screen X, tap Y, enter Z) — written from the actual user's perspective, not raw HTTP calls. A 🔍 prefix marks the rare step that needs a DevTools/network inspection to verify (see §0 environment notes). |
| Expected Results | What must be true for a Pass — visible UI state, status transitions, notifications, cross-module side effects. Where a case targets a **known, already-documented gap**, Expected Results states the **current (as-built) behavior**, with a Note explaining the gap so a tester isn't confused about what counts as "Pass" today. |
| Pre-conditions | Data/state/role needed before starting. |
| Round 1/2/3 Status, Date, Tester | Filled in only after actually running the case. Status ∈ `Passed`/`Failed`/`Pending`/`N/A`. |
| Note | Cross-references to other `sys-sheet-*.csv` cases this one builds on, or to `unit_test_plan.md`/`integration_test_plan.md`/`AUDIT_REPORT.md` gap IDs. |

### Why this layer is organized by workflow, not by module/controller

`itc-sheet-*.csv` is organized **one file per backend module/controller** (Authentication, Course Management, Payment & Revenue, …) so every endpoint gets isolated HTTP-level coverage. This System Test layer is organized **one file per end-to-end business workflow** instead, because several of the most important behaviors in HanGo only show up when a journey **crosses module boundaries** — e.g. a course purchase (`SYS_FLOW_ENR`) has to succeed all the way through PayOS webhook → auto-enrollment → notification → My Learning visibility before a Learner can even start `SYS_FLOW_LRN`; a Trainer's course cannot reach `SYS_FLOW_CRS`'s publish step until `SYS_FLOW_TRN`'s approval finishes. Several sheets explicitly cross-reference test case IDs in sibling sheets (see each sheet's "Note" column and the "End-to-End" stage at the bottom of most sheets) — these chained references are intentional and mirror how a real user actually moves through the product.

---

## 3. How to execute these tests yourself

### 3.1 Environment
1. Start the backend against a scratch MySQL schema (see §0.1). Confirm it's up: `GET http://localhost:8080/api/v1/metadata/categories` should respond.
2. Start the Flutter frontend pointed at that backend (see §0.2). Prefer the web build (`flutter run -d chrome`) for the fastest iteration and for the cases that need DevTools.
3. Keep a running note of test accounts for every role you'll need: `LEARNER`, `TRAINER` (PROFESSIONAL and PEER_TUTOR, at least one VERIFIED), `TRAINER_LEAD`/Course Manager, `ADMINISTRATOR` — see `integration_test_plan.md` §3.2 for how to obtain/seed each one (self-service registration + `become-trainer` for Learner/Trainer; direct DB seed for `TRAINER_LEAD`/`ADMINISTRATOR`, since no self-service upgrade path exists for those two).

### 3.2 Execution order
Run the sheets roughly in the order listed in §1 — later sheets assume state produced by earlier ones (an approved Trainer from Flow 2 is needed to publish a course in Flow 3; a Published course is needed to test enrollment in Flow 4; an enrolled Learner is needed for Flow 5; a scored Exam attempt is needed to drive Flow 7/8's weakness-based recommendations; and so on). Within a sheet, follow the stage order top to bottom for the same reason — most "End-to-End" cases at the bottom of a sheet are cheap to run precisely because the individual stage cases above already built up the needed state.

### 3.3 Recording results
For each test case you actually run: set that Round's **Status** to `Passed`/`Failed`/`N/A`, fill **Date** and **Tester**, and add a one-line **Note** if it failed or behaved differently than expected. Re-running the same sheet later (regression) fills Round 2, then Round 3 — don't overwrite a prior round's data. When a case targets a known gap (see the Note column), record what you actually observed even if it matches the "current buggy behavior" described in Expected Results — that is a Pass for this layer's purpose (confirming the gap is unchanged), not a Fail.

### 3.4 When a case says "cross-reference"
Several cases point at a test case ID in another sheet instead of re-describing setup already covered elsewhere (e.g. `SYS_FLOW_NTF_TC01` says "cross-reference `SYS_FLOW_ENR_TC17`"). Run the referenced case first if you haven't already; don't skip the cross-referencing case itself, since it's checking a different observable outcome (here: that the notification actually shows up in the Bell, not that the payment itself succeeded).

---

## 4. Sheet index

| File | Workflow |
|---|---|
| `sys-sheet-authentication-access-flow.csv` | Authentication - Registration- Verification & Login |
| `sys-sheet-trainer-onboarding-flow.csv` | Trainer Onboarding & Profile Approval |
| `sys-sheet-course-authoring-publishing-flow.csv` | Course Authoring- Content Building & Publishing |
| `sys-sheet-course-purchase-enrollment-flow.csv` | Course Discovery- Cart- PayOS Payment & Enrollment |
| `sys-sheet-lesson-learning-progress-flow.csv` | Lesson Learning- Quiz & Progress Tracking |
| `sys-sheet-exam-authoring-taking-flow.csv` | Exam Authoring- Matrix Generation- Review & Taking |
| `sys-sheet-ai-learning-pathway-flow.csv` | AI-Generated Learning Pathway |
| `sys-sheet-ai-assistant-recommendation-flow.csv` | AI Assistant Q&A & Course Recommendation |
| `sys-sheet-comment-moderation-flow.csv` | Lesson Comment- Like & Moderation |
| `sys-sheet-notification-delivery-flow.csv` | Cross-Module Notification Delivery & Read-Tracking |
| `sys-sheet-trainer-revenue-settlement-flow.csv` | Trainer Revenue- Monthly Statement & Settlement |
| `sys-sheet-account-access-administration-flow.csv` | Account- Role & Access Administration |
