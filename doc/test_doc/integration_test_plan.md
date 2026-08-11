# HanGo — Integration Test Plan (manual, HTTP-level)

**Project Name:** HanGo — Smart Language Self-Study Platform
**Project Code:** HANGO
**Test Level:** Integration Testing (Controller → Service → Repository → DB), executed **manually** over real HTTP — no JUnit/MockMvc code, no Testcontainers/H2. This is a companion to, not a replacement for, the Service-layer unit tests (see [`unit_test_plan.md`](unit_test_plan.md)) and the workflow-based System Tests (see [`system_test_plan.md`](system_test_plan.md)).

> **Rebuilt from scratch 2026-08-08.** This replaces the previous version of this plan (module list, IDs, and columns are all new — see §2 below for what changed and why). Every test case in every `itc-sheet-*.csv` was written against a fresh, full re-read of the current controller/service code (not the July version of this plan, not the narrative docs alone) — several test cases deliberately target newly-confirmed gaps and behavior changes, and a few correct assumptions from the prior version of this plan that no longer hold (e.g. Authentication now has refresh tokens and lockout; Comment Management's identity-spoofing gap appears fixed; several exam/course workflow endpoints changed their status-code/rollback behavior). Don't assume anything carried forward silently — each sheet's cases were re-derived from the code as it stands today.

**Test Environment Setup Description:**
1. HanGo Backend (Spring Boot, Java 17) running locally — `cd hango-backend && mvnw spring-boot:run`, or a packaged jar. Default port from `application.properties` (`server.port`, typically `8080`).
2. Database: **MySQL 8.0**, pointed at a **disposable local/scratch schema** — never the production DB. Use `application.properties.example` as a template for a local `application.properties`.
3. HTTP client: **Postman** (recommended — collections + environments make Round 2/3 re-runs fast) or `curl`/VS Code REST Client.
4. Browser: **Microsoft Edge or Google Chrome**, DevTools (**F12**) — needed for any test case whose Expected Result explicitly asks you to inspect the raw response body/headers/Content-Type (several cases in this rebuild specifically call out checking things Postman's pretty-printed view can hide, e.g. a leaked `correctIndex`/`isCorrect` field, or a `text/plain` Content-Type on a JSON-looking body).
5. `doc/templates/*.xlsx` (Course/Exam/Question-Bank import templates) — needed for the Excel-import test cases in Course/Exam/Question-Bank sheets.

> **Code-first principle applies here too** (see `TESTING.md` §0 / `unit_test_plan.md`'s standing rules): every test case is written against the **real, current controller/service code**, not the narrative in `HanGo_Documentation.md`/`doc/specs/0X-*.md` alone. Several test cases **deliberately target confirmed gaps** (missing `@PreAuthorize`, IDOR, masked error statuses, silent data-loss on update, non-rollback on partial import failure, etc.) so that running the case either proves the gap still exists or proves it was fixed — never silently assume the secure/ideal behavior when writing your own follow-up tests.
> **Status discipline:** every Round cell in every sheet starts **Pending** (see `itc-summary.csv`). Per standing project rule, never mark a case Passed/Failed until it has actually been executed.

---

## 1. Master files (read these first)

| File | Purpose |
|---|---|
| [`itc-function-index.csv`](itc-function-index.csv) | One row per distinct function across the whole backend (109 originally scoped down to the 104 that actually exist as live HTTP surface in this codebase), mapping `Function Name → Sheet Name (module) → Description → Pre-Condition`. Use this to find which `itc-sheet-*.csv` covers a given feature. |
| [`itc-summary.csv`](itc-summary.csv) | One row per module: `Passed / Failed / Pending / N/A / Number of test cases`, plus a Sub-total row (368 test cases across 17 modules). Update this after each execution round — it's the at-a-glance rollup for reporting. |

## 2. What changed vs. the previous version of this plan

The previous Integration Test layer (built 2026-07-25, 14 sheets) used a different structure: `<MODULE>_IT##` IDs, a combined "RBAC / Account Mgmt" module, a combined "Learning Mgmt" module, extra `DevTools Evidence`/`Case Type` columns on every row, and no master function-index/summary files. This rebuild:

1. **Uses `<MODULE>_FT##` IDs** (`FT` = Functional Test, matching the module-based reference format this rebuild follows) — deliberately distinct from both the unit-test `UTC##` convention and the System Test `SYS_FLOW_<ABBR>_TC##` convention, so no two layers' IDs ever collide.
2. **Splits "RBAC / Account Mgmt" into three sheets** — `Roles & Permissions Management` (the fixed-role/permission-assignment surface — note HanGo has **no** create/delete-role endpoint, only 4 fixed roles with configurable permission sets), `Account Management` (admin CRUD on other users' accounts), and `Profile Management` (self-service, already separate before) — because they're conceptually and code-wise distinct surfaces (`AdminController`'s two halves vs. `UserController`).
3. **Adds a `Dashboard & Reports` sheet** consolidating every pure read-only aggregate/stats endpoint that was previously scattered across the Account/Course/Course-Manager sheets (`AdminController`'s dashboard-stats/audit-log/ai-usage, `TrainerDashboardController`'s dashboard summary, `CourseManagerDashboardController`'s dashboard summary, plus the trainer course-list's bundled status-count badges).
4. **Adds a `Ticket Management` sheet** (`TicketController` + `ManagementTicketController`) — a fully real, shipped feature that was never covered by any prior IT-layer sheet at all. Its 16 test cases are first-time coverage, not a diff against an old baseline.
5. **Renames `Learning Mgmt` → `Learning Pathway`** and substantially expands it (9→31 test cases) — this feature (AI-generated adaptive roadmap, timeboxed scheduling, detour/fast-track reroute policy, mentor chat) grew considerably after the previous plan was written and was previously only partially documented; two endpoints the old plan documented (`merge-preview`/`merge-confirm`) turned out to have **no live HTTP route at all** in current code (see `LRN`→`PATHWAY_FT31`).
6. **Drops the `DevTools Evidence` and `Case Type` (N/A/B) columns.** Every sheet now uses exactly: `Test Case ID, Test Case Description, Test Case Procedure, Expected Results, Pre-conditions` — matching the reference format this rebuild follows. Where a case specifically needs a DevTools/Network-tab check (raw JSON inspection, Content-Type verification, etc.), that instruction is now written directly into the Procedure/Expected Results text instead of being flagged by a separate column.
7. **Adds a per-sheet header block** (`Feature`, `Test requirement`, `Number of TCs`, and a `Testing Round` Passed/Failed/Pending/N-A rollup table for Round 1/2/3) at the top of every CSV, ahead of the test-case table — this is new; the previous sheets went straight into the table.

## 3. Sheet index

| # | File | Module | TCs |
|---|---|---|---|
| 1 | `itc-sheet-authentication.csv` | Authentication | 42 |
| 2 | `itc-sheet-roles-permissions.csv` | Roles & Permissions Management | 10 |
| 3 | `itc-sheet-account.csv` | Account Management | 20 |
| 4 | `itc-sheet-profile.csv` | Profile Management | 14 |
| 5 | `itc-sheet-trainer-onboarding.csv` | Trainer Onboarding | 17 |
| 6 | `itc-sheet-course.csv` | Course Management | 58 |
| 7 | `itc-sheet-course-content.csv` | Course Content Management | 19 |
| 8 | `itc-sheet-question-bank.csv` | Question Bank Management | 20 |
| 9 | `itc-sheet-exam.csv` | Exam Management | 41 |
| 10 | `itc-sheet-ai-assistant.csv` | AI Assistant | 10 |
| 11 | `itc-sheet-learning-pathway.csv` | Learning Pathway | 31 |
| 12 | `itc-sheet-recommendation.csv` | Recommendation | 8 |
| 13 | `itc-sheet-payment.csv` | Payment & Revenue | 26 |
| 14 | `itc-sheet-comment.csv` | Comment Management | 15 |
| 15 | `itc-sheet-notification.csv` | Notification Management | 10 |
| 16 | `itc-sheet-ticket.csv` | Ticket Management | 16 |
| 17 | `itc-sheet-dashboard-reports.csv` | Dashboard & Reports | 11 |
| | | **Sub total** | **368** |

**Excluded on purpose:** `TestDBController` (`/api/test-db/**`) is **not** in this plan — it is a known, unauthenticated credential-reset security hole slated for removal from the deploy build, not a feature to validate.

---

## 4. Column &amp; convention legend (applies to every `itc-sheet-*.csv`)

Each CSV starts with a small feature-summary header:

```
Feature,<Module Name>
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
| Test Case ID | `<MODULE>_FT##` — `FT` = Functional Test. Module code is the sheet's Feature name, uppercased and stripped of spaces/punctuation (e.g. `Course Management` → `COURSE`, `Learning Pathway` → `PATHWAY`). |
| Test Case Description | One line: what is being verified. |
| Test Case Procedure | Numbered concrete steps: HTTP method + path, headers, body. Where a raw-response/DevTools check matters, the step says so explicitly (e.g. "inspect the raw JSON", "check the Content-Type header"). |
| Expected Results | What must be true for a Pass — status code, response fields, DB/notification side effects. Where the case targets a **confirmed gap or inconsistency**, the Expected Result states the **current (as-built) behavior**, not the ideal/secure one — so a tester isn't confused about which one counts as "Pass" today. Many of these are phrased as "confirm this still reproduces" rather than a flat assertion, since the codebase changes daily. |
| Pre-conditions | Data/state/role needed before starting. |

Rows above a section's first test case (e.g. `Login,,,,`) are sub-headers grouping test cases by function — they match the Function Name in `itc-function-index.csv`.

### Rounds and status discipline

Fill in Round 1/2/3 results **in the header block only** (this format doesn't carry a per-case Round column, unlike the System Test layer — see `itc-summary.csv` for the module-level rollup, and update each sheet's own header block as you execute it). Never mark a case Passed/Failed until it has actually been run; leave it in the Pending bucket until then.

---

## 5. How to execute these tests yourself

### 5.1 Environment
1. Point `hango-backend/src/main/resources/application.properties` (copy from `.example`) at a **local scratch MySQL schema** — never a shared/prod DB, since these tests create/modify/delete real rows (users, courses, payments…).
2. `cd hango-backend && mvnw spring-boot:run`. Confirm it's up: `GET http://localhost:8080/api/v1/metadata/categories` should respond 200 (this endpoint is fully public).
3. Keep Postman open with an **Environment** holding variables: `baseUrl`, `tokenLearner`, `tokenTrainer`, `tokenTrainerLead`, `tokenAdmin` — each session's access token is short-lived; use `POST /api/auth/refresh-token` with the matching refresh token to renew rather than re-logging in every time (Authentication now supports real refresh-token rotation, unlike the single-JWT-no-refresh design documented in the previous version of this plan).

### 5.2 Getting accounts for every role
HanGo roles: `LEARNER`, `TRAINER` (dual-mode, includes Learner capabilities), `TRAINER_LEAD` (= "Course Manager" — code accepts both `TRAINER_LEAD` and `COURSE_MANAGER` authority strings interchangeably in many `@PreAuthorize`s, a known cleanup-in-progress), `ADMINISTRATOR`.
- Register a LEARNER via `POST /api/auth/register`, then verify the account via the emailed link (or `POST /api/auth/resend-verification` if needed).
- Promote to TRAINER via `POST /api/v1/trainers/become-trainer` — grants the role immediately, no approval needed for dashboard access (only publishing/monetization is gated on `TrainerProfile.status=VERIFIED`, itself gated on Admin review).
- TRAINER_LEAD/ADMINISTRATOR accounts must be seeded directly in the DB (no self-service upgrade path exists) — e.g. via the `roles`/`user_roles` tables (check the actual schema before writing raw SQL — do this once per scratch DB, not on shared data).

### 5.3 Authenticating requests
1. `POST /api/auth/login` with `{email, password}` → copy `accessToken` and `refreshToken` from the response.
2. Every subsequent request: header `Authorization: Bearer <accessToken>`.
3. When the access token expires, `POST /api/auth/refresh-token` with `{refreshToken}` to get a new pair — the old refresh token is rotated/revoked on use, so always update both stored values.

### 5.4 Raw-response / Content-Type checks
Several cases in this rebuild specifically require inspecting the **raw** response body or headers, not a parsed/pretty view — e.g. confirming a `correctIndex`/`isCorrect` field is present in a quiz-question JSON payload before any attempt, or confirming a "JSON-looking" endpoint is actually served as `text/plain`. Use Postman's **raw** response view or the browser's DevTools **Network → Response** tab; don't rely on a client library that might silently coerce/hide the real shape.

### 5.5 Testing the PayOS webhook manually
PayOS calls back your server directly; it cannot reach `localhost`. To test `POST /api/v1/payment/payos-webhook` manually:
1. Create a payment via `POST /api/v1/payment/create` first, note the returned order/txnRef.
2. Build the webhook JSON payload yourself (see `PaymentServiceImplTest` for the exact field shape PayOS sends and how the HMAC-SHA256 signature over the sorted-key query string is computed) and sign it with the same `PAYOS_CHECKSUM_KEY` your local `application.properties` uses.
3. POST that payload directly to your own running server. This proves the signature-verification and idempotency logic without needing a real PayOS sandbox.

### 5.6 Testing Excel import flows
Use the real template files already in the repo: `doc/templates/Hango_Course_Import_Template.xlsx`, `Hango_Exam_Import_Template.xlsx`, `Hango_Question_Bank_Import_Template.xlsx`. Fill a copy with a few rows before uploading via Postman's `form-data` body type (key `file`, type File). Several new test cases in this rebuild (`COURSE_FT29-32`, `EXAM_FT26-29`) specifically exercise partial-failure/partial-commit scenarios — prepare workbooks with a mix of valid and deliberately-invalid rows for those.

### 5.7 Recording results
For each test case you actually run, update that sheet's **header-block** Round row (Passed/Failed/Pending/N-A counts) and roll the totals up into `itc-summary.csv`. Add a Note inline in your own execution tracker (or a copy of the sheet) if a case failed or behaved differently than expected. Re-running the same sheet later (regression) updates Round 2, then Round 3 — don't overwrite a prior round's recorded numbers.
