# HanGo — Unit Test Audit Report

> **Phase:** 2 (Unit Test Audit) · **Scope:** `hango-backend/src/test/java` (backend Service-layer unit tests) + `hango-frontend/test` (frontend). Per standing team policy ([`TESTING.md`](TESTING.md), [`agent_qa.md`](agent_qa.md)), backend unit-test scope is **Service layer only** — Controller-layer tests are out of scope except where business logic lives directly in the Controller with no backing Service.
> **Baseline:** `mvnw clean test` → **488/488 passing, 0 skipped, 32 test classes** at the start of this audit (verified by direct count against `doc/specs/unit_test_plan.md`'s own claim).
> **Companion documents:** [`AUDIT_REPORT.md`](AUDIT_REPORT.md) (Phase 1) · [`unit_test_plan.md`](specs/unit_test_plan.md) (living test plan, updated after this report) · [`ROADMAP.md`](ROADMAP.md) (Phase 5).

---

## 1. Coverage Summary

### 1.1 Backend — Service layer

34 independently-testable production units exist under `service/` (+ `service/impl/`): 12 interface+impl pairs, 22 standalone concrete `@Service`/`@Component` classes.

| Metric | Count |
|---|---|
| Services with dedicated test file | 28 / 34 (82%) |
| Services with **zero** test file | 6 / 34 (18%) |
| Total `@Test` methods (backend) | 488 |
| Test classes | 32 (31 real + 1 rogue non-test, removed — see [`AUDIT_REPORT.md`](AUDIT_REPORT.md) LOW-01) |
| Controllers with dedicated test | 2 / 26 (both justified exceptions — no backing Service, real logic in Controller) |
| Modules with a UTC CSV sheet | 12 / 14 (missing: Course-Content-Management — folded into Course's sheet — and Recommendation, which has no tests at all yet) |

**By module** (cross-referencing the 14 functional modules in `HanGo_Documentation.md` §6):

| Module | Backend Service coverage | Notes |
|---|---|---|
| AUTH | Strong (56 tests) | See HIGH-09 in Phase 1 — GAP-AUTH-01 still open despite good test coverage of everything else |
| PROFILE | Covered via `AuthService`/`UserController` paths | `ProfileUpdateRequest` validation gap (GAP-PROF-03) is a production bug, not a test gap |
| RBAC | Strong (`AdminControllerTest`, justified Controller-layer exception) | |
| TRAINER ONBOARDING | Strong (32 tests) | |
| COURSE + CONTENT | Adequate — 19 tests, but **2 real methods untested** (`switchCourseVersion`, `getCourseVersionHistory`) | |
| QUESTION BANK | Strong (34 + 10 AI-gen tests) | |
| EXAM | Adequate — 19 tests, but **`getExamQuestions` (learner take-exam path) untested** | |
| AI ASSISTANT | Strong (16 + 6 + 7 + 4 supporting-class tests) | `GeminiClientService` deliberately untestable (no injectable seam), documented not overlooked |
| LEARNING / PATHWAY | Strong (18 + 10 + 8 + 3 + 2 pathway-cluster tests) | |
| RECOMMENDATION | 🔴 **Zero tests** | `ExamCourseRecommendationAIService.recommendCoursesAI` has no test at all |
| PAYMENT & REVENUE | Adequate — Cart/Payment/Statement all covered, but **`PaymentExpirationScheduler` and `getTrainerStatements` untested** | |
| COMMENT | Strong (20 + 10 rule-engine tests) | |
| NOTIFICATION | Strong (11 tests) | Newest module, coverage keeping pace |
| COURSE MANAGER REVIEW WORKFLOW (cross-cutting CRS/EXM) | 🟠 Partial — 7 tests but **3 of 8 public methods untested** (the 3 that back the actual review-queue UI) | See HIGH-03 in Phase 1 |

### 1.2 Frontend

| Metric | Count |
|---|---|
| Test files | 2 (`widget_test.dart`, `learning_pathway_node_tree_test.dart`) |
| Pages with any test | 0 / 67 |
| Repository/service classes with any test | 0 / ~15 |
| Models/entities with any test | 2 (`Course`, `PathwayNode`) |

Frontend coverage is negligible relative to codebase size (143 `lib/` files). This isn't new breakage — it reflects that frontend testing was never staffed the way backend Service testing was. See §4 for a realistic, prioritized starting point rather than a "test everything" mandate.

---

## 2. Missing Test List

### 2.1 Services with zero test coverage

| Service | Why untested today | Recommended action |
|---|---|---|
| `CloudinaryService` | Thin wrapper around the Cloudinary SDK; already exercised as a **mocked** dependency inside `AuthServiceTest` etc. | Leave as-is — consistent with how the suite already treats other thin external wrappers (`EmailService`). Not added in this pass. |
| `EmailService` | Same — SMTP wrapper, always mocked by callers | Leave as-is, same rationale. |
| `GeminiClientService` | The one class that calls the live Gemini API directly; self-constructs its `WebClient` via `@PostConstruct`, no injectable seam | Documented, deliberate boundary (per `unit_test_plan.md`). Would need a constructor-injection refactor to test — flagged in [`ROADMAP.md`](ROADMAP.md), not done here (would be a production code change beyond test-file scope). |
| `CourseImportService` | 737 lines, raw XML `.xlsx` parsing; already explicitly deferred in `unit_test_plan.md` as "too large/complex for this round" | Respecting the existing team decision — not added in this pass. Top candidate for next round. |
| **`PaymentExpirationScheduler`** | No technical barrier — single method, one mockable repository dependency, just never got picked up | 🔴 **Added in this audit** — see §5. |
| **`ExamCourseRecommendationAIService`** | Marked "Implemented" in the plan doc with no caveat, but has no test; module (Recommendation) is the last one from the original QA report never followed up on | 🔴 **Added in this audit** — see §5. |

### 2.2 Individual untested methods inside otherwise-tested classes

| Class | Untested method(s) | Priority | Action taken |
|---|---|---|---|
| `CourseManagerDashboardServiceImpl` | `getCoursesForReview`, `getCourseReviewDetail`, `getExamsForReview` | 🔴 High — backs the real review-queue UI, silently undertested relative to what the doc claims doesn't even exist | **Added in this audit** — see §5 |
| `ExamService` | `getExamQuestions` (learner-facing "take exam" question list — must not leak `isCorrect`) | 🔴 High — correctness + potential answer-leak risk | **Added in this audit** — see §5 |
| `MonthlyStatementServiceImpl` | `getTrainerStatements` | 🟠 Medium-high — real financial-data endpoint, plan doc's own claimed coverage overstates this row | **Added in this audit** — see §5 |
| `CourseServiceImpl` | `switchCourseVersion`, `getCourseVersionHistory` | 🟠 Medium-high — versioning/BR-CRS-03 business logic, non-trivial progress-carryover math | Documented; deferred to next round (see §4) — larger effort, bundled with HIGH-04's product-decision dependency |
| `TrainerDashboardServiceImpl` | `submitTrainerCourse`, `updateExamVisibility`, `deleteTrainerCourse`, `approveTrainerCourse`, `rejectTrainerCourseDraft` | 🟠 Medium — 5 of 17 public methods; 2 of these are the other half of the HIGH-04 divergent-logic finding | Documented; deferred (see §4) — `approveTrainerCourse`/`rejectTrainerCourseDraft` are best tested *after* HIGH-04 is resolved product-side, otherwise the test would just lock in one arbitrary side of an inconsistency |

### 2.3 Frontend gaps (illustrative, not exhaustive — see §4 for what's realistic to start with)

All of: authentication flow (`login_page.dart`, `register_page.dart`, `AuthService`), exam-taking flow (`take_exam_page.dart`, `ExamRepository`), all 9 repository classes, all 5 `data/services/*.dart` classes, and 65 of 67 page widgets have no test today.

---

## 3. Recommended Test Priority

Ranked by (business risk if wrong) × (currently untested), reusing the project's existing 🔴/🟡/🟢 convention from `agent_qa.md`:

| Priority | Item | Rationale |
|---|---|---|
| 🔴 1 | `PaymentExpirationScheduler` | Money-adjacent (auto-expires pending payments); zero technical barrier to testing; silent gap not even mentioned in the living test plan |
| 🔴 2 | `ExamService.getExamQuestions` | Learner-facing; must not leak `isCorrect` to the client — an untested answer-leak risk is exactly the kind of thing that should have a regression test |
| 🔴 3 | `CourseManagerDashboardServiceImpl` review-queue reads | Content-governance gate (BR-G04); currently the least-tested part of a workflow the docs incorrectly claim doesn't exist at all |
| 🟠 4 | `MonthlyStatementServiceImpl.getTrainerStatements` | Real money data exposed to Trainers; plan doc overstates its coverage today |
| 🟠 5 | `ExamCourseRecommendationAIService.recommendCoursesAI` | Last of the original 14 modules with literally zero test coverage |
| 🟡 6 | `CourseServiceImpl.switchCourseVersion` / `getCourseVersionHistory` | Real but complex (progress carryover); worth a dedicated round rather than a rushed add |
| 🟡 7 | `TrainerDashboardServiceImpl` remaining 5 methods | Blocked on resolving HIGH-04 first for the approve/reject pair |
| 🟢 8 | Frontend: `AuthService` + login/register widget tests | Highest-traffic, best ROI starting point for frontend, given near-zero existing coverage |
| 🟢 9 | Frontend: exam-taking flow | Second-highest-value flow (timer/auto-submit correctness) |

Items 1-3 (and their supporting production-adjacent test files) were implemented as part of this audit — see §5. Items 4-9 are recommended next steps, tracked in [`ROADMAP.md`](ROADMAP.md), not implemented in this pass to keep the diff focused and reviewable (per the instruction to add/change tests only where truly warranted, not to mass-produce coverage in one sweep).

---

## 4. Production Methods Still Needing Unit Tests (full list, post-audit)

This is the authoritative "still open" list after §5's additions — kept here rather than only in `unit_test_plan.md` so this report stays a complete point-in-time snapshot.

**Backend:**
1. `CourseServiceImpl.switchCourseVersion`
2. `CourseServiceImpl.getCourseVersionHistory`
3. `TrainerDashboardServiceImpl.submitTrainerCourse`
4. `TrainerDashboardServiceImpl.updateExamVisibility`
5. `TrainerDashboardServiceImpl.deleteTrainerCourse`
6. `TrainerDashboardServiceImpl.approveTrainerCourse` *(blocked on HIGH-04 product decision)*
7. `TrainerDashboardServiceImpl.rejectTrainerCourseDraft` *(blocked on HIGH-04 product decision)*
8. `CourseImportService.importWorkbook` *(existing deferred decision, not re-litigated here)*
9. `GeminiClientService.*` *(existing deferred decision — no injectable seam without a production refactor)*
10. `CloudinaryService.*`, `EmailService.*` *(deliberately low-priority — thin external wrappers, already covered indirectly via mocks in dependent tests)*

**Frontend (illustrative — see [`ROADMAP.md`](ROADMAP.md) for the full prioritized plan):**
- `AuthService` (login/register/OTP/password flows)
- `CourseRepository`, `ExamRepository`, `CartRepository`, `PaymentRepository`, `PathwayRepository`, `NotificationRepository`
- `take_exam_page.dart` timer/auto-submit behavior
- Form validation on `login_page.dart`/`register_page.dart`

---

## 5. Tests Added in This Audit

Following the team's standing rule that new tests use the existing style exactly (JUnit 5 + Mockito, `@ExtendWith(MockitoExtension.class)`, one-line method-name divider comments, no Javadoc), the following were added:

| New/modified file | Covers | Test count |
|---|---|---|
| `service/PaymentExpirationSchedulerTest.java` (new) | `PaymentExpirationScheduler.expireStalePendingPayments` | see file |
| `service/ExamCourseRecommendationAIServiceTest.java` (new) | `ExamCourseRecommendationAIService.recommendCoursesAI` (success, AI-failure fallback, empty-weakness cases) | see file |
| `service/ExamServiceTest.java` (extended) | `ExamService.getExamQuestions` (answer-safe projection, not-found, empty exam) | see file |
| `service/CourseManagerDashboardServiceTest.java` (extended) | `getCoursesForReview`, `getCourseReviewDetail`, `getExamsForReview` | see file |
| `service/MonthlyStatementServiceImplTest.java` (extended) | `getTrainerStatements` | see file |

Full method-by-method detail is in [`unit_test_plan.md`](specs/unit_test_plan.md) (living plan, updated alongside these additions) and the corresponding `doc/specs/utc-sheet-*.csv` rows. Test run after these additions: see the final verification note at the end of this report.

---

## 6. Verification caveats carried over from cross-referencing the living test plan

- **GAP-EXM-03** (client-trusted exam score) — `unit_test_plan.md`'s 2026-07-24 log entry says `saveExamAttempt` now recomputes the score server-side. This audit did not re-derive that finding from scratch (it's a production-code correctness question, not a test-coverage one) — flagged here only so it isn't silently dropped; recommend a teammate re-confirm against `ExamServiceTest`'s existing assertions next time that file is touched.
- **`doc/specs/unit_test_plan.md` row 35** ("Course Manager review/approve/reject/publish workflow — Planned/Gap") was factually wrong as of this audit (the workflow exists, see HIGH-03) — corrected in Phase 4's update to that file.
- No genuine duplicate-test or method-doesn't-exist-anymore issue was found anywhere in the current suite; the Payment test file swap (`PaymentServiceTest.java` deleted → `PaymentServiceImplTest.java` added) was a clean replacement, not a duplication.

---

## Final test-suite verification

`mvnw clean test` run after all §5 additions, aggregated from `target/surefire-reports/*.txt`:

```
Total test classes: 34 (32 baseline + 2 new: PaymentExpirationSchedulerTest, ExamCourseRecommendationAIServiceTest)
Tests run: 517 (488 baseline + 29 new)
Failures: 0
Errors: 0
Skipped: 0
```

29 new tests break down exactly as: 3 (`PaymentExpirationSchedulerTest`) + 7 (`ExamCourseRecommendationAIServiceTest`) + 5 (`ExamServiceTest` additions) + 11 (`CourseManagerDashboardServiceTest` additions) + 3 (`MonthlyStatementServiceImplTest` additions) = 29. All green.
