# HanGo — System Test Plan (manual, end-to-end / black-box)

**Project Name:** HanGo — Smart Language Self-Study Platform
**Project Code:** HANGO
**Test Level:** System Testing — end-to-end, black-box, executed **manually through the actual running application** (Flutter frontend + Spring Boot backend + MySQL), not at the HTTP/API level. This is the third and outermost layer of the test pyramid already in place for HanGo:
1. [`unit_test_plan.md`](unit_test_plan.md) + `utc-sheet-*.csv` — automated Service-layer unit tests (JUnit).
2. [`integration_test_plan.md`](integration_test_plan.md) + `itc-sheet-*.csv` — manual, HTTP-level integration tests per controller/module (Postman).
3. **This document** + `sys-sheet-*.csv` — manual, UI-driven **end-to-end workflow** tests that cross multiple modules the way a real user actually experiences them, not one controller at a time.

> **Rebuilt from scratch 2026-08-08**, same day as the Integration Test layer's own v2 rebuild. This replaces the previous version of this plan (12 sheets, built 2026-07-25) — see §2 below for what changed and why. Every test case in every `sys-sheet-*.csv` was re-derived against a fresh read of the current backend controllers/services **and** the current Flutter screens (not the July version of this plan, not `itc-sheet-*.csv` alone) — several test cases target newly-confirmed gaps and behavior changes, several old cases described features/paths that turned out not to exist in the current build, and a couple of previously-documented gaps appear to have been fixed since July. Don't assume anything carried forward silently.

**Test Environment Setup Description:**
1. **Backend:** HanGo Backend (Spring Boot, Java 17) running locally — `cd hango-backend && mvnw spring-boot:run`, pointed at a **disposable local/scratch MySQL 8.0 schema** (copy `application.properties.example`) — never the production DB, since these tests create/modify/delete real users, courses, payments, and enrollments.
2. **Frontend:** HanGo Frontend (Flutter) — `cd hango-frontend && flutter run` targeting a web (`-d chrome`) or emulator/device build pointed at the local backend's base URL.
3. **Email:** a reachable mailbox or local mail-catcher for OTP/verification/notification emails (`EmailService`), since several workflows (Auth, Trainer Onboarding, Payment, Statement settlement) depend on real emails being received.
4. **PayOS:** sandbox/test PayOS credentials configured in `application.properties` for the Payment & Revenue flows (`SYS_FLOW_ENR`), including the ability to complete a test payment and receive its webhook.
5. **AI Provider:** a valid Gemini API key configured for the AI Assistant / Recommendation / Learning Pathway flows (`SYS_FLOW_AIR`, `SYS_FLOW_PWY`) — these workflows cannot be meaningfully tested with the AI provider unreachable.
6. **Browser DevTools (F12):** only needed opportunistically, for the handful of cases marked with a 🔍 that explicitly call for inspecting a raw network request/response (e.g. confirming no HTTP call fires during a local-only "Clear history" action, or confirming a masked 500 instead of a clean 403 on an authorization failure). Unlike the IT-level plan, System Test is UI-driven by default and does not carry a dedicated DevTools-evidence column.

> **Code-first principle applies here too** (see `TESTING.md` §0 and `integration_test_plan.md`'s own code-first note): every workflow and expected result below is written against the **current, real implementation** — backend controllers/services cross-checked against the just-rebuilt `itc-sheet-*.csv`, and UI steps/labels cross-checked against the actual Flutter source under `hango-frontend/lib/presentation/pages/`. Several cases **deliberately target already-known gaps** (e.g. the exam timer being entirely client-side with no server deadline check, the Ticket module's masked-500-instead-of-403 authorization failures and cross-account message IDOR, several dead-code UI paths that are never wired to a button) so that running the plan either reconfirms the gap or proves it was fixed — never silently assumes the ideal/secure behavior.
> **Status discipline:** every Round cell in every sheet starts **Pending**. Per standing project rule, never mark a case Passed/Failed until it has actually been executed.

---

## 1. Master files (read these first)

| File | Purpose |
|---|---|
| [`sys-function-index.csv`](sys-function-index.csv) | One row per workflow, mapping `Function Name → Sheet Name → Description → Pre-Condition`. Since this layer is organized one-sheet-per-workflow (not one row per granular function, unlike the IT layer's `itc-function-index.csv`), Function Name and Sheet Name are two views of the same workflow. |
| [`sys-summary.csv`](sys-summary.csv) | One row per workflow: `Passed / Failed / Pending / N/A / Number of test cases`, plus a Sub-total row (255 test cases across 13 workflows). Update this after each execution round — it's the at-a-glance rollup for reporting. |

## 2. What changed vs. the previous version of this plan

The previous System Test layer (built 2026-07-25, 12 sheets) used the same workflow-based philosophy but a different row format and was already ~2 weeks stale against a fast-moving codebase. This rebuild:

1. **Drops the per-row `Round 1/2/3 Status/Date/Tester` and `Note` columns.** Every sheet now uses exactly `Test Case ID, Test Case Description, Test Case Procedure, Expected Results, Pre-conditions` — matching the same reference format `integration_test_plan.md`'s v2 rebuild follows, and matching the format the tester pasted for this rebuild. Round tracking now lives **only** in each sheet's header block (see §4), same as the IT layer. Cross-sheet references that used to live in the Note column (e.g. "Cross-reference SYS_FLOW_ENR_TC17") are now folded inline into the Procedure or Pre-conditions text of the referencing case.
2. **Adds two master files that didn't exist before**, mirroring the IT layer's `itc-function-index.csv`/`itc-summary.csv` shape: `sys-function-index.csv` and `sys-summary.csv`.
3. **Adds a 13th sheet: `sys-sheet-support-ticket-flow.csv`** (workflow abbreviation `TKT`) — the Ticket module (`TicketController` + `ManagementTicketController`, a real, fully-shipped feature with a dedicated `ticket` folder in the Flutter frontend) had **zero** System Test coverage until now, same gap the IT layer found and closed today. It carries forward two confirmed bugs from the IT-layer rebuild as UI-framed cases: authorization failures returning a masked generic 500 instead of a clean 403 in several places, and a confirmed IDOR where any authenticated user can post into another user's ticket thread with zero ownership check.
4. **`Dashboard & Reports` stays deliberately folded into the workflows it belongs to, not split into its own sheet** — same design principle as before, just now enumerated explicitly: Admin dashboard stats/Audit Log/AI Usage stats → `SYS_FLOW_ADM`; Trainer's own Dashboard (courses/revenue/rating/recent-activity) → `SYS_FLOW_REV`; Course-Manager Dashboard and the Trainer's own course-list status badges → `SYS_FLOW_CRS`. This layer is organized by end-to-end user journey, and a read-only stats view isn't one — it's a supporting step inside the journey that actually produces the numbers being displayed.
5. **Every sheet was re-verified against current code, not just reformatted** — re-reading the actual controllers/services and the actual Flutter screens surfaced real drift since July, in both directions:
   - **Confirmed-still-broken / newly found gaps:** the exam timer and question-count/duration rules are entirely client-side with no server-side enforcement (`SYS_FLOW_EXM`); no sequential-lesson locking or enrollment check exists on Lesson content despite the UI implying it (`SYS_FLOW_LRN`); the Course-Manager dashboard's `inactiveCoursesCount` undercounts because it queries the literal string `"PENDING"` instead of the real `PENDING_APPROVAL` status (`SYS_FLOW_CRS`); the AI-suggested Pathway reroute card and the old "multi-course merge" feature are dead code never wired to any button (`SYS_FLOW_PWY`); the Account-Administration "Update Account" role dropdown has no Learner option, so editing any field on a Learner account silently promotes them to Trainer (`SYS_FLOW_ADM`); a plain Learner and an Administrator both have **no reachable Ticket UI at all** despite the backend fully supporting their roles (`SYS_FLOW_TKT`).
   - **Confirmed fixed / no longer reproducible:** the exam-attempt "answers echo" bug (previously GAP-EXM-01) no longer reproduces against the current `ExamService`/`ExamReviewPage` code — reframed as a regression check rather than an expected-gap case.
   - **Confirmed removed/never-existed:** the old "dual approve/reject path" scenario for Course review (old `SYS_FLOW_CRS` TC15–18) — no such second path exists in `TrainerDashboardController`; only the single `CourseManagerDashboardController` review path is real. Drag-and-drop Section/Lesson reordering and a media-upload "Retry" option were also never implemented in the current frontend and have been removed from the plan.

## 3. Sheet index

| # | File | Workflow | TCs |
|---|---|---|---|
| 1 | `sys-sheet-authentication-access-flow.csv` | Authentication - Registration- Verification & Login | 21 |
| 2 | `sys-sheet-trainer-onboarding-flow.csv` | Trainer Onboarding & Profile Approval | 22 |
| 3 | `sys-sheet-course-authoring-publishing-flow.csv` | Course Authoring- Content Building & Publishing | 26 |
| 4 | `sys-sheet-course-purchase-enrollment-flow.csv` | Course Discovery- Cart- PayOS Payment & Enrollment | 22 |
| 5 | `sys-sheet-lesson-learning-progress-flow.csv` | Lesson Learning- Quiz & Progress Tracking | 17 |
| 6 | `sys-sheet-exam-authoring-taking-flow.csv` | Exam Authoring- Matrix Generation- Review & Taking | 22 |
| 7 | `sys-sheet-ai-learning-pathway-flow.csv` | AI-Generated Learning Pathway | 18 |
| 8 | `sys-sheet-ai-assistant-recommendation-flow.csv` | AI Assistant Q&A & Course Recommendation | 16 |
| 9 | `sys-sheet-comment-moderation-flow.csv` | Lesson Comment- Like & Moderation | 15 |
| 10 | `sys-sheet-notification-delivery-flow.csv` | Cross-Module Notification Delivery & Read-Tracking | 14 |
| 11 | `sys-sheet-trainer-revenue-settlement-flow.csv` | Trainer Revenue- Monthly Statement & Settlement | 21 |
| 12 | `sys-sheet-account-access-administration-flow.csv` | Account- Role & Access Administration | 25 |
| 13 | `sys-sheet-support-ticket-flow.csv` | Support Ticket Submission- Triage & Resolution | 16 |
| | | **Sub total** | **255** |

**Excluded on purpose:** `TestDBController` (`/api/test-db/**`) is not exercised here either — same rationale as `integration_test_plan.md` (known unauthenticated credential-reset hole slated for removal, not a feature to validate). Profile Management (view/edit own profile, avatar, change password) is exercised inline as a supporting step inside other workflows (e.g. Trainer profile in Flow 2, account edits in Flow 12) rather than as its own top-level workflow, since it has no multi-actor end-to-end journey of its own beyond what `itc-sheet-profile.csv` already covers at the API level.

---

## 4. Column & convention legend (applies to every `sys-sheet-*.csv`)

Each CSV starts with a small workflow-summary header:

```
Workflow,<workflow name>
Test requirement,<one line>
Number of TCs,<N>
Testing Round,Passed,Failed,Pending,N/A
Round 1,0,0,<N>,0
Round 2,0,0,<N>,0
Round 3,0,0,<N>,0
```

...then a blank line, then the test-case table:

| Column | Meaning |
|---|---|
| Test Case ID | `SYS_FLOW_<ABBR>_TC##` — distinct from the unit-test `UTC##` and integration-test `<MODULE>_FT##` conventions so all three layers never collide in the same tracker. `<ABBR>` matches the workflow: `AUTH`, `TRN`, `CRS`, `ENR`, `LRN`, `EXM`, `PWY`, `AIR`, `CMT`, `NTF`, `REV`, `ADM`, `TKT`. |
| Test Case Description | One line: what end-to-end behavior is being verified. |
| Test Case Procedure | Numbered concrete UI steps (open screen X, tap Y, enter Z) — written from the actual user's perspective, not raw HTTP calls. A 🔍 prefix marks the rare step that needs a DevTools/network inspection to verify. |
| Expected Results | What must be true for a Pass — visible UI state, status transitions, notifications, cross-module side effects. Where a case targets a **known, already-documented gap**, Expected Results states the **current (as-built) behavior**, with enough context that a tester isn't confused about what counts as "Pass" today. |
| Pre-conditions | Data/state/role needed before starting — including inline cross-references to other sheets' test case IDs where this case builds on state produced elsewhere (e.g. "builds on SYS_FLOW_ENR_TC17"). |

Rows above a group's first test case (e.g. `Self-Registration & Email Verification,,,,`) are stage-divider rows grouping test cases within the workflow — not test cases themselves.

### Rounds and status discipline

Fill in Round 1/2/3 results **in the header block only** (this format doesn't carry a per-case Round column). Never mark a case Passed/Failed until it has actually been run; leave it in the Pending bucket until then. Roll sheet-level totals up into `sys-summary.csv` after each round.

### Why this layer is organized by workflow, not by module/controller

`itc-sheet-*.csv` is organized **one file per backend module/controller** (Authentication, Course Management, Payment & Revenue, …) so every endpoint gets isolated HTTP-level coverage. This System Test layer is organized **one file per end-to-end business workflow** instead, because several of the most important behaviors in HanGo only show up when a journey **crosses module boundaries** — e.g. a course purchase (`SYS_FLOW_ENR`) has to succeed all the way through PayOS webhook → auto-enrollment → notification → My Learning visibility before a Learner can even start `SYS_FLOW_LRN`; a Trainer's course cannot reach `SYS_FLOW_CRS`'s publish step until `SYS_FLOW_TRN`'s approval and Agreement/Payout gate finish. Several sheets explicitly cross-reference test case IDs in sibling sheets inline in their Pre-conditions/Procedure text — these chained references are intentional and mirror how a real user actually moves through the product.

---

## 5. How to execute these tests yourself

### 5.1 Environment
1. Start the backend against a scratch MySQL schema (see §0.1). Confirm it's up: `GET http://localhost:8080/api/v1/metadata/categories` should respond.
2. Start the Flutter frontend pointed at that backend (see §0.2). Prefer the web build (`flutter run -d chrome`) for the fastest iteration and for the cases that need DevTools.
3. Keep a running note of test accounts for every role you'll need: `LEARNER`, `TRAINER` (PROFESSIONAL and PEER_TUTOR, at least one VERIFIED with the Agreement/Payout gate cleared), `TRAINER_LEAD`/Course Manager, `ADMINISTRATOR` — see `integration_test_plan.md` §5.2 for how to obtain/seed each one (self-service registration + `become-trainer` for Learner/Trainer; direct DB seed for `TRAINER_LEAD`/`ADMINISTRATOR`, since no self-service upgrade path exists for those two).

### 5.2 Execution order
Run the sheets roughly in the order listed in §3 — later sheets assume state produced by earlier ones (an approved Trainer from Flow 2 is needed to publish a course in Flow 3; a Published course is needed to test enrollment in Flow 4; an enrolled Learner is needed for Flow 5; a scored Exam attempt is needed to drive Flow 7/8's weakness-based recommendations; and so on). The new Ticket flow (13) has no hard dependency on the others and can be run any time after Flow 1 (needs a logged-in account). Within a sheet, follow the stage order top to bottom for the same reason — most "End-to-End" cases at the bottom of a sheet are cheap to run precisely because the individual stage cases above already built up the needed state.

### 5.3 Recording results
For each test case you actually run: update that sheet's **header-block** Round row (Passed/Failed/Pending/N-A counts), and roll the totals up into `sys-summary.csv`. Add a Note in your own execution tracker (or a copy of the sheet) if a case failed or behaved differently than expected. Re-running the same sheet later (regression) fills Round 2, then Round 3 — don't overwrite a prior round's recorded numbers. When a case targets a known gap (see its Expected Results text), record what you actually observed even if it matches the "current buggy behavior" described — that is a Pass for this layer's purpose (confirming the gap is unchanged), not a Fail.

### 5.4 When a case says "builds on" / cross-references another sheet
Several cases' Pre-conditions or Procedure text point at a test case ID in another sheet instead of re-describing setup already covered elsewhere (e.g. a Notification case says "builds on SYS_FLOW_ENR_TC17"). Run the referenced case first if you haven't already; don't skip the cross-referencing case itself, since it's checking a different observable outcome (here: that the notification actually shows up in the Bell, not that the payment itself succeeded).
