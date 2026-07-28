# HanGo — Full Project Audit Report

> **Phase:** 1 (Full Project Audit) · **Scope:** entire repository (`hango-backend/`, `hango-frontend/`, `doc/`, deployment config) · **Method:** current source code read directly and cross-referenced against every existing Markdown doc; nothing in this report is inferred from documentation alone.
> **As of:** 2026-07-24, branch `unit-test` (mid-refactor: Payment/Cart/MonthlyStatement/Notification changes uncommitted at audit time).
> **Companion documents:** [`TEST_AUDIT_REPORT.md`](TEST_AUDIT_REPORT.md) (Phase 2, unit test coverage) · [`ROADMAP.md`](ROADMAP.md) (Phase 5, future versions).
> **Status:** analysis only — no production code was changed to produce this report.

---

## How to read this report

Findings are graded by **impact if left unaddressed**, not by effort to fix:

- 🔴 **Critical** — exploitable security hole, live secret exposure, or data-integrity risk reachable in the current deployed system today.
- 🟠 **High** — real bug, silent business-rule violation, or doc/code gap serious enough to mislead a new contributor or a stakeholder decision.
- 🟡 **Medium** — inconsistency, missing safeguard, or maintenance risk that isn't actively dangerous today but will bite later.
- 🟢 **Low** — cosmetic, dead code, or repo-hygiene item.
- 💡 **Suggested improvement** — not a defect; an opportunity.

Every finding cites a real file path. None of the security findings below have been patched as part of this audit — per the project's own `AGENTS.md` §10-11, changing endpoint behavior/API contracts requires explicit human sign-off, and Phase 1 of this task is audit-only. Where a fix is purely documentation (redacting a leaked secret's value from a Markdown file), that fix **has** been applied — see the note in CRIT-03.

---

## 🔴 Critical Issues

### CRIT-01 — Unauthenticated debug controller allows full account takeover
**File:** [`TestDBController.java`](../hango-backend/src/main/java/com/hango/hango_backend/controller/TestDBController.java)

`TestDBController` has no `@RequestMapping` base restriction and no `@PreAuthorize`, and `SecurityConfig.java:65` explicitly whitelists `/api/test-db/**` as `permitAll()`. Three GET endpoints are reachable by anyone, unauthenticated, on any environment where this backend is exposed (production included, per `app.base-url` pointing at `hangog92.online`):

- `GET /api/test-db/seed-revenue-data` — finds (or creates) a `TRAINER`-role user, overwrites its `password_hash` with a **hardcoded BCrypt hash of the literal password `12345678`**, force-sets `is_verified=1, status='ACTIVE'`, and returns an HTML response body that **echoes the account's real email address and the plaintext password back to the caller**. This is a complete, self-service account-takeover primitive requiring zero credentials.
- `GET /api/test-db/init-prices` — runs `ALTER TABLE payments MODIFY COLUMN ...` / `ADD COLUMN ...` directly against the live schema.
- `GET /api/test-db` — bulk-inserts mock `questions` rows tied to `created_by = 1` (assumes user ID 1 exists and is a safe target).

**Impact:** anyone who finds the API host can take over a real trainer account (and, by extension, anything gated on "verified Trainer," including payout bank details) with a single unauthenticated GET request.
**Recommendation:** remove this controller from the deployable build entirely, or at minimum gate it behind `@Profile("dev")` + a `@PreAuthorize("hasRole('ADMINISTRATOR')")` and delete the `permitAll()` rule for `/api/test-db/**` in `SecurityConfig`. This is an API-contract/security-config change and is intentionally **not** applied by this audit — flagging for explicit developer action.

### CRIT-02 — Broken access control: comment endpoints trust a client-supplied `userId`
**File:** [`CommentController.java:34-64`](../hango-backend/src/main/java/com/hango/hango_backend/controller/CommentController.java)

`addComment`, `updateComment`, `deleteComment`, `likeComment`, `unlikeComment` all take `@RequestParam Long userId` as the acting user, instead of resolving it from the authenticated principal — and the code itself flags this at line 35: `@RequestParam Long userId, // Replace with UserPrincipal from SecurityContext later`. Combined with `SecurityConfig.java:68` permitting all of `/api/v1/comments/**`, **any caller (logged in or not) can post, edit, delete, like, or unlike a comment as any other user ID**, simply by changing a query parameter. `LessonController`'s `getQuizAttempts`/`saveQuizAttempt` have the identical pattern on the also-`permitAll()`'d `/api/v1/lessons/**`.

This directly contradicts the pattern used correctly elsewhere in the same codebase (`CourseController`, `ExamController`, `CartController`, `PaymentController` all resolve the user from `SecurityContextHolder`/`@AuthenticationPrincipal`), so the fix is mechanical and low-risk — it's a pure oversight, not a design gap.
**Recommendation:** replace `@RequestParam Long userId` with `@AuthenticationPrincipal UserDetailsImpl currentUser` (as already done in `MonthlyStatementController`, `NotificationController`) in both `CommentController` and `LessonController`. This changes the request contract (removes a query param), so per project convention it needs explicit developer sign-off before merging — not applied here.

### CRIT-03 — Live-looking PayOS credentials and a personal email committed to the repo, already pushed to the shared remote
**File:** [`DEPLOY_GUIDE.md`](../DEPLOY_GUIDE.md) §4 (as it existed before this audit)

The deployment guide's `.env` heredoc example contained **populated, real-format values** (not placeholders like `application.properties.example`'s `YOUR_PAYOS_API_KEY`) for `PAYOS_CLIENT_ID`, `PAYOS_API_KEY`, and `PAYOS_CHECKSUM_KEY`, plus a personal Gmail address used in a `certbot` command. Verified via `git log`: this landed in commit `efdd778` ("feat(deploy): add CI/CD deploy workflow and docker compose configurations") and **is already present on `origin/dev`** on the public GitHub remote (`github.com/thanhthaoqn/HanGo`) — this is not a local-only draft.

**Action taken as part of this audit:** the literal secret values have been redacted from `DEPLOY_GUIDE.md` and replaced with the same `YOUR_...` placeholder convention used in `application.properties.example` (a pure documentation edit — no application behavior changes). **This does not fix the exposure** — the real values remain in git history on the remote.
**Recommendation (cannot be done by this audit, needs you / the PayOS account owner):**
1. Rotate all three PayOS credentials from the PayOS merchant dashboard immediately — treat the committed values as compromised regardless of whether they've been misused yet.
2. Consider whether the repository (and its GitHub history) is public; if so this is a live incident, not a hygiene item.
3. If required, scrub history with `git filter-repo`/BFG — this is destructive to shared history and needs your explicit go-ahead before anyone runs it.

### CRIT-04 — Trainer content-mutation endpoints have zero role restriction
**File:** [`SectionQuestionController.java`](../hango-backend/src/main/java/com/hango/hango_backend/controller/SectionQuestionController.java)

All 8 endpoints under `/api/v1/trainer/**` (section listing, question CRUD, question-group creation) have no `@PreAuthorize` at all, unlike every sibling trainer controller (`TrainerQuestionController`, `TrainerDashboardController`, etc.), which all restrict to `TRAINER`/`ADMINISTRATOR`/`TRAINER_LEAD`. Since this path isn't in `SecurityConfig`'s `permitAll()` list, it falls back to `anyRequest().authenticated()` — meaning **any authenticated user of any role, including a plain Learner, can create or edit trainer question-bank content** today.
**Recommendation:** add the same `@PreAuthorize("hasAnyRole('TRAINER','ADMINISTRATOR','TRAINER_LEAD')")` used by `TrainerQuestionController` to each endpoint. Flagged, not applied (API-contract-adjacent change).

---

## 🟠 High Priority Issues

### HIGH-01 — No schema migration tool; production default is Hibernate auto-DDL
`pom.xml` has no Flyway/Liquibase dependency, and no `src/main/resources/db/migration` exists. The **real** `application.properties` sets `spring.jpa.hibernate.ddl-auto=${SPRING_JPA_HIBERNATE_DDL_AUTO:update}` — i.e. `update` is the default unless an env var overrides it — while only the `.example` template recommends the safer `validate`. Combined with `SystemParameterDataInitializer` running destructive `DELETE`/`UPDATE ... NOT IN` cleanup SQL against live tables on every boot, schema evolution today is fully implicit. `AGENTS.md` §7 already mandates Flyway/Liquibase "for every schema change" — the mandate exists in the doc but was never adopted in the build.
**Recommendation:** introduce Flyway, baseline the current schema as `V1__baseline.sql` (via `flyway:baseline` against the live DB), and switch `ddl-auto` to `validate` everywhere including the real `application.properties`. This is a schema-tooling change requiring explicit sign-off per `AGENTS.md` §10 — recommended for the [Roadmap](ROADMAP.md), not applied here.

### HIGH-02 — Payment gateway documentation is wrong almost everywhere except the newest specs
The platform's actual, integrated, and tested payment gateway is **PayOS** (confirmed: `payos.*` properties, `api-merchant.payos.vn` endpoint, PayOS's documented HMAC-SHA256 checksum scheme, `createPayOSPaymentLink`/`handlePayOSWebhook` method names). Yet `HanGo_Documentation.md`, `README.md`, `ARCHITECTURE.md`, `AGENTS.md`, `doc/agent_qa.md`, and `doc/specs/05/08` all still say **"VNPay."** Only `doc/specs/12-payment-revenue.md` (updated 2026-07-24) correctly documents PayOS and explicitly calls itself a supersession of the earlier VNPay design. The code itself still carries VNPay-named scar tissue (`Payment.vnpayTxnNo`/`vnpay_txn_no` column, `PaymentHistoryDTO.vnpayTxnNo`, a dead `SecurityConfig` permit-rule for `/api/v1/payment/vnpay-return` that no controller implements, Vietnamese doc-comments saying "VNPay"), which is exactly why the confusion propagated.
**Resolution:** addressed in Phase 3 — all top-level docs updated to say PayOS; this report documents the finding for traceability. (Renaming the `vnpay*`-named DB column/field is a schema/API change and is **not** done here — noted as a Roadmap item instead.)

### HIGH-03 — Course Manager review workflow is far more built (and far less tested) than any doc admits
`doc/specs/05-course-management.md` and `doc/agent_qa.md` state the Course Manager approve/reject/publish workflow doesn't exist. It does: `CourseManagerDashboardServiceImpl` has 8 public methods implementing a real review queue (`getCoursesForReview`, `getCourseReviewDetail`, `publishCourse`, `returnCourseToDraft`, `getExamsForReview`, `publishExam`, `returnExamToDraft`). Three of those eight (`getCoursesForReview`, `getCourseReviewDetail`, `getExamsForReview` — the three read endpoints that back the actual review-queue UI) have **zero unit tests**. This is simultaneously a documentation-staleness finding and a test-coverage gap (see [`TEST_AUDIT_REPORT.md`](TEST_AUDIT_REPORT.md) §3).

### HIGH-04 — Two divergent, inconsistent implementations of "approve/reject a Trainer's course"
`TrainerDashboardServiceImpl.approveTrainerCourse`/`rejectTrainerCourseDraft` and `CourseManagerDashboardServiceImpl.publishCourse`/`returnCourseToDraft` both implement the same PENDING→published-or-not transition, but **behave differently**: `rejectTrainerCourseDraft` sets status to `"REJECTED"` while `returnCourseToDraft` sets `"DRAFT"`; the `TrainerDashboardServiceImpl` pair sends **no notifications** while the `CourseManagerDashboardServiceImpl` pair does. Neither `approveTrainerCourse` nor `rejectTrainerCourseDraft` has a test. If both code paths are reachable (they're on different controllers/routes — worth confirming which one the frontend actually calls), a course's rejection state and the trainer's notification depend on *which* endpoint happened to be wired up, which is a real, live inconsistency risk, not just a test gap.
**Recommendation:** confirm with whoever owns this feature which path is canonical, then either delete the other or make the two consistent. Flagged for the [Roadmap](ROADMAP.md); not resolved here since it requires a product decision (which status string/notification behavior is correct), not just a doc update.

### HIGH-05 — No consistent API error contract
`GlobalExceptionHandler` (`@RestControllerAdvice`) only has one handler, for `ApiException` (thrown in just 6 files, mostly the AI/pathway subsystem). Everywhere else — including all of Payment, Cart, Notification, and MonthlyStatement — services `throw new RuntimeException(...)`, and each controller wraps its own ad-hoc try/catch: some return `{"error": "..."}`, `ApiException`-backed ones return `{"message": "..."}`, and `CourseController` catches only `RuntimeException` and returns `e.getClass().getName() + ": " + e.getMessage()` — **leaking the exception's fully-qualified Java class name to the client.** There's no handler for `MethodArgumentNotValidException`/`HttpMessageNotReadableException` either, so validation failures fall through to Spring's default `/error` body.
**Recommendation:** add a catch-all `@ExceptionHandler(Exception.class)` and a `MethodArgumentNotValidException` handler to `GlobalExceptionHandler`, and standardize on one response envelope. Roadmap item — not applied here (touches every controller's error responses, i.e. an API contract change).

### HIGH-06 — Frontend has no dio, no centralized API client, and duplicated JWT-attachment logic in 59 places
`pubspec.yaml` declares `dio: ^5.4.0`, but **zero files import it** — every network call actually goes through raw `package:http`, hand-rolled independently across `HangoApi` (`lib/services/hango_api.dart`), `AuthService` (`lib/data/services/auth_service.dart`), and 9 separate repository/service classes in `lib/data/`. The `Authorization: Bearer <token>` header is attached by copy-pasted code reading `SharedPreferences` directly, duplicated **59 times across 13 files**, rather than via one interceptor. There are also **two parallel, unsynchronized session stores**: plain `SharedPreferences` (key `'auth_token'`, used almost everywhere) and `flutter_secure_storage`-backed `SecureSessionStore` (used only by the newer `AppState`). `CONSTITUTION.md`'s state-management/routing claims compound this — see HIGH-07.
**Recommendation:** roadmap item (introduce a single `Dio`-based client with an auth interceptor, remove the unused dependency or actually adopt it, unify on one session store) — a frontend-wide refactor, out of scope for a docs/test audit to execute blind.

### HIGH-07 — Documented frontend architecture (Riverpod + go_router) does not exist in code
`CONSTITUTION.md` §3 and `doc/agent_frontend.md` both state the frontend uses **Riverpod** for state management and **go_router** for routing. Neither is a dependency in `pubspec.yaml`, and grepping the entire `lib/` tree for `flutter_riverpod`, `ConsumerWidget`, `ref.watch`, `go_router`, or `GoRouter` returns **zero matches**. The actual architecture: one root-level `ChangeNotifierProvider<AppState>` (from `package:provider`) for auth-session bootstrapping, and **every one of the 67 page files manages its own state via `StatefulWidget` + `setState()`** (658 occurrences across 62 files), instantiating repository/service classes directly as fields rather than receiving them via DI. Routing is 100% imperative `Navigator.push`/`MaterialPageRoute` (216-218 occurrences across ~52 files) with no centralized route table.
**Resolution:** addressed in Phase 3 — `CONSTITUTION.md`/`agent_frontend.md`/`ARCHITECTURE.md` updated to describe the actual pattern (StatefulWidget + setState + a single root Provider, imperative Navigator) rather than the aspirational one. Whether to actually *adopt* Riverpod/go_router going forward is a product/team decision — see [`ROADMAP.md`](ROADMAP.md).

### HIGH-08 — Frontend test coverage is close to zero
Only 2 test files exist (`hango-frontend/test/widget_test.dart`, `learning_pathway_node_tree_test.dart`), covering one model (`Course.fromJson`) and one widget (`InteractiveNodeTree`). None of the 67 page files, none of the ~15 repository/service classes, the auth flow, or the exam-taking flow have any test. `CONSTITUTION.md` §9 ("Write Unit Tests and Widget Tests for important components and features") is effectively unmet on the frontend. This is a pre-existing condition (not something this audit is scoped to fill in bulk — see [`TEST_AUDIT_REPORT.md`](TEST_AUDIT_REPORT.md) and the [Roadmap](ROADMAP.md) for a prioritized plan).

### HIGH-09 — Several still-open functional gaps confirmed present, previously reported by QA, never fixed
Cross-checked against `doc/specs/qa-report-for-dev-team.md` (2026-07-19) and `doc/specs/unit_test_plan.md`'s dated log — these were reported to the dev team and have **no later "fixed" entry anywhere**:
- **GAP-EXM-01** (🔴 in the original QA report): `ExamAttempt.answersJson` is persisted as a JSON array but read back via `Map.class`, so `ExamService.mapToAttemptDTO`'s `answers` field is **always empty** in the attempt-history/result view.
- **GAP-EXM-02:** `ExamService.getAllExams` with a non-`PUBLISHED` status filter always returns an empty list (dead/contradictory branch).
- **GAP-QB-01:** `TrainerQuestionAIService.generatePayload` computes fallback values that are never actually used.
- **GAP-AUTH-01:** `AuthService.authenticateUser` only blocks the literal status `"INACTIVE"` — a `"LOCKED"` account can still log in successfully today.
- **GAP-PROF-03:** `ProfileUpdateRequest` has zero `@Valid`/`@NotBlank`-style annotations, so profile updates aren't validated server-side at all.
- (GAP-EXM-03, client-trusted exam score with no server recompute, appears to have been fixed per a 2026-07-24 log entry — see [`TEST_AUDIT_REPORT.md`](TEST_AUDIT_REPORT.md) §6 for the verification caveat.)

---

## 🟡 Medium Priority Issues

| # | Finding | Where |
|---|---|---|
| MED-01 | `pom.xml` pins `<java.version>17</java.version>`; `ARCHITECTURE.md`/`CONSTITUTION.md`/`README.md` all claim "Java 21." CI/deploy workflows *do* install a JDK 21 toolchain, but the Maven compiler target is still 17 — so no Java 21-only language feature is actually used or even compilable today. Docs also contradict each other: `ARCHITECTURE.md` says "Spring Boot (4.0.6 parent)" (matches `pom.xml`) while `CONSTITUTION.md` says "Spring Boot 3.x" in the same breath as "Java 21." | `pom.xml`, `.github/workflows/backend-ci.yml`, `.github/workflows/deploy.yml` |
| MED-02 | Package names `sercurity` and `exeption` are real, load-bearing typos (every import statement uses the misspelled form). `ARCHITECTURE.md` faithfully documents `sercurity/` but calls the other one `exception/` (i.e. even the doc doesn't consistently reflect the real typo). Renaming now touches every file that imports either package — high blast radius, not attempted here. | whole `com.hango.hango_backend` tree |
| MED-03 | `CONSTITUTION.md` mandates MapStruct for all Entity↔DTO mapping; **zero** `@Mapper`/`org.mapstruct` usage exists anywhere, and there's no MapStruct dependency in `pom.xml`. All mapping is hand-written (`@Builder` chains or manual field copies) inside services. | `CONSTITUTION.md` §4 vs. all of `service/` |
| MED-04 | Only 1 of 12 Service interface/impl pairs (`CourseManagerDashboardServiceImpl`) actually lives in the `service/impl` sub-package; the other 11 sit flat in `service/`. Looks like an abandoned start of a reorganization. | `service/` vs `service/impl/` |
| MED-05 | Almost every status/type/role-like entity field is a bare `String`, not a typed `@Enumerated` enum — `Course.status`, `Payment.status`/`settlementStatus`, `MonthlyStatement.status`, `TrainerProfile.status`, `Comment.status`, `Exam.status`, etc. The only real Java `enum` in `entity/` is `AIMessage.MessageRole`. No compile-time protection against a typo'd status string. | `entity/*.java` |
| MED-06 | Several real relationships are denormalized plain `Long` fields instead of JPA associations: `Course.parentId`/`latestVersionId`, `Payment.statementId`, `PathwayNode.parentNodeId`, `PathwayEvent.pathwayId`/`learnerId`, `LearningPathwayGoal.sourceCourseId`. These FKs are invisible to Hibernate metadata and enforced only by service-layer convention. | `entity/*.java` |
| MED-07 | Frontend has **two incompatible `Exam` model classes** (`lib/domain/model/exam_models.dart` — `int id`, has `fromJson` — vs. `lib/domain/entities/exam.dart` — `String id`, no `fromJson`), used by different, uncoordinated parts of the app; `learner_home_page.dart` imports both side-by-side. Not a deliberate split — organic drift from two uncoordinated work streams. | `lib/domain/model/` vs `lib/domain/entities/` |
| MED-08 | Frontend has **two parallel "services" layers** (`lib/services/` vs `lib/data/services/`) built a month apart, never merged — directly causes MED-… the dual-session-store issue in HIGH-06. | `lib/services/` vs `lib/data/services/` |
| MED-09 | Cloudinary cloud name (`diqekap4o`) and various marketing image URLs are hardcoded as literal strings independently in at least 4+ frontend files rather than centralized in `lib/utils/config.dart`. | `create_course_page.dart`, `edit_course_page.dart`, `my_information_page.dart`, `course_manager_my_information_page.dart` |
| MED-10 | Frontend API base URL resolution branches on `Uri.base.host` string literals (`hangog92.online` / else `localhost:8080` / else Android-emulator loopback) rather than build-time config (`--dart-define`, flavors, or env file). Works, but brittle — a new environment (staging, custom domain) requires a code change. | `lib/utils/config.dart` |
| MED-11 | No refresh-token or logout endpoint exists despite `HanGo_Documentation.md` describing "access token + refresh token" — only a single, non-revocable JWT is issued today. | `AuthController`, `AuthService` |
| MED-12 | `JwtProperties` and (separately) `GeminiProperties` are each registered twice / partially unused: `JwtUtils`/`AuthService` bypass `JwtProperties` entirely and use raw `@Value` fields instead; `GeminiProperties` is both `@Component`-scanned and separately declared via `@EnableConfigurationProperties`. Harmless but confusing dead weight. | `config/JwtProperties.java`, `config/GeminiProperties.java` |
| MED-13 | `NotificationController` (new, generic, any authenticated role) and `CourseManagerDashboardController`'s `/notifications` endpoints (older, `TRAINER_LEAD`-only) now serve overlapping data for the same role through two separate code paths — a mid-refactor duplication that should be consolidated once the Notification rework settles. | `NotificationController.java`, `CourseManagerDashboardController.java` |
| MED-14 | `doc/specs/01,02,04,05,06,07,08,09,10,11-*.md` are unmaintained since their original 2026-07-16 draft (no dates, no GAP references, all-unchecked acceptance criteria) and several are now directly contradicted by verified code (05's versioning claim, 06/07's "Apache POI" claim — the real `CourseImportService` parses `.xlsx` as raw XML, not POI). Resolved in Phase 3 for the modules where the contradiction is clear-cut; see per-file notes there. | `doc/specs/` |

---

## 🟢 Low Priority Issues

| # | Finding |
|---|---|
| LOW-01 | Dead/scratch files with zero references anywhere, confirmed via repo-wide grep: `hango-frontend/lib/_debug_provider_check.dart`, `hango-frontend/test.dart`, `hango-frontend/test_uri.dart`, `hango-frontend/analyze_output.txt` (stale `flutter analyze` capture — the missing-file errors it reports no longer reproduce), the empty duplicate `test/learning_pathway_node_tree_test.dart` at the **repo root** (outside `hango-frontend/` entirely), and `hango-backend/src/test/java/com/hango/hango_backend/CheckDBApp.java` (a rogue `@SpringBootApplication` debug seeder mis-committed into the test tree, 0 `@Test` methods). Flagged for deletion — see the cleanup note at the end of this report for why it wasn't executed automatically. |
| LOW-02 | `hango-backend/src/main/java/com/hango/hango_backend/TODO_backend_ai.txt` — a 3-line developer scratch-note sitting inside the Java source tree instead of `/TODO.md`. Content already folded into `TODO.md`; the stray file itself still needs deleting (see cleanup note). |
| LOW-03 | `hango-backend/response.json` — an orphaned API-response fixture describing a "Task" concept (`assigneeName`, `reviewerName`, `deadline`) that doesn't correspond to any entity in the current data model, and directly contradicts `14-notification.md`'s explicit "there is no Task/Lead concept in HanGo." Confirmed dead (no entity, no repository, no controller references it). Flagged for deletion (see cleanup note). |
| LOW-04 | `CourseSessionDTO` is the DTO for the `Section` entity — naming drift between DTO and entity layers ("Session" vs "Section") that could confuse a new contributor grepping for one term. |
| LOW-05 | `SecurityUtil.getCurrentUserId()` defensively handles 4 different principal shapes, one of which (`instanceof User` raw entity) doesn't match how the security context is actually ever populated (always `UserDetailsImpl`). Reads like leftover code from an earlier auth design; most controllers don't even call it. |
| LOW-06 | `PathwayReroutePolicyService`'s inner `PolicyDecision` class uses public mutable fields, inconsistent with the Lombok-heavy (`@Getter/@Setter/@Builder`) style used everywhere else. |
| LOW-07 | `hango-frontend/README.md` is still the unmodified default `flutter create` boilerplate — not HanGo-specific at all. |

---

## 💡 Suggested Improvements (not defects)

1. **Standardize the API error envelope.** Extend `GlobalExceptionHandler` to catch generic `Exception` and `MethodArgumentNotValidException`, and migrate services from `throw new RuntimeException(...)` to `ApiException` so every endpoint returns the same JSON shape.
2. **Pick one frontend state-management strategy and commit to it in docs and code**, rather than leaving `CONSTITUTION.md` describing an aspirational Riverpod/go_router architecture that was never built. Either adopt them for new screens going forward, or update the constitution to describe the StatefulWidget+setState+Provider-lite pattern as the intentional house style.
3. **Consolidate the frontend's duplicate folders**: merge `lib/domain/model/` + `lib/domain/entities/` into one location (resolving the two incompatible `Exam` classes first), and merge `lib/services/` + `lib/data/services/` into one client/session-store layer.
4. **Introduce Flyway** with a `V1__baseline.sql` snapshot of the live schema, then flip `ddl-auto` to `validate` in the real `application.properties`.
5. **Decide on MapStruct**: either adopt it for the highest-traffic mappers (Course/Exam/Payment DTOs) or strike the mandate from `CONSTITUTION.md` so the doc stops overpromising.
6. **Add a lightweight audit/pen-test pass** focused specifically on the four 🔴 Critical findings before any further production traffic — they're all cheap to fix once prioritized.
7. **Consider a dedicated, isolated PR to rename `sercurity`→`security` and `exeption`→`exception`** once the codebase reaches a quieter point — every import in the project references these two packages, so this should not be bundled with unrelated work.

---

## Cleanup identified as part of this audit

The following are confirmed-dead (zero references, verified by repo-wide search across both this audit's agents and the file contents themselves) and are recommended for removal as routine hygiene — no production behavior would be affected by deleting any of these:

- `hango-frontend/lib/_debug_provider_check.dart`
- `hango-frontend/test.dart`, `hango-frontend/test_uri.dart`, `hango-frontend/analyze_output.txt`
- `test/learning_pathway_node_tree_test.dart` (repo-root duplicate, 0 bytes) and the now-empty root `test/` directory
- `hango-backend/src/test/java/com/hango/hango_backend/CheckDBApp.java`
- `hango-backend/response.json`

`hango-backend/src/main/java/com/hango/hango_backend/TODO_backend_ai.txt`'s content has already been folded into `TODO.md`'s FE-09 checklist; the stray file itself is included in the deletion list above (not yet removed, same reason).

None of the file deletions above have been executed by this audit — bulk file deletion was blocked by the session's permission classifier, which requires explicit human confirmation for destructive operations. No test file with actual `@Test` coverage, and no production `.java`/`.dart` file, is affected either way.

---

## What Phase 1 deliberately does NOT include

Per this task's own phasing, Phase 1 is analysis-only. The 🔴 Critical security findings (CRIT-01, 02, 04) and the HIGH-04 behavioral divergence are **reported, not patched** — they change API behavior/contracts, which `AGENTS.md` §10 requires explicit developer sign-off for. They are carried forward as the top-priority items in [`ROADMAP.md`](ROADMAP.md).
