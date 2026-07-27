# Feature Specification: FE-03 — Role & Permission Management (RBAC) & Dashboard

> Ref: [HanGo_Documentation.md](../HanGo_Documentation.md) §7.3 (RBAC)

## 1. Business Context
Role-Based Access Control (RBAC) ensures the right people have the right access. Administrators can manage users, roles, and platform permissions. Additionally, this module encompasses the Analytics Dashboard, providing Admins with visual reports (Charts, Statistics) on the system's operational performance, AI usage, and audit logs.

**Role model (as implemented):** roles are plain string tags (`Role.roleName`, e.g. `LEARNER`/`TRAINER`/`TRAINER_LEAD`/`ADMINISTRATOR`), linked to `User` via the `user_roles` many-to-many join table. There is **no granular permission entity** — authorization is 100% `@PreAuthorize("hasRole('X')")` checks hard-coded per endpoint across controllers. **Decision (2026-07-22, tester call):** keep it this way — do not build a dynamic permission matrix (`Permission`/`RolePermission` tables, `hasAuthority()` refactor across the whole codebase). The Roles screen stays a **static, read-only reference**, but its content must accurately describe what each role can actually do in code — not aspirational/marketing copy.

## 2. Acceptance Criteria

**Frontend (Flutter, `admin_dashboard_page.dart`):**
- [x] User list interface for Admin to view, search, and filter users by role and status (Accounts tab).
- [x] Activate / Deactivate (lock/unlock) user accounts.
- [x] UI to manually create accounts (Learner/Trainer/Course Manager/Admin) and assign/update roles.
- [x] Dashboard tab: Account/Roles/Courses/Enrollments summary cards, weekly registration chart, Top 5 Courses by enrollment. Custom-painted line chart (`LineChartPainter`), not `fl_chart` — no such dependency exists in this project.
- [x] AI Analytics tab: real Total AI Calls / Success Rate / Chat-vs-Embedding split + weekly call chart (previously 100% hardcoded mock numbers — replaced 2026-07-22).
- [x] Roles tab: static read-only cards per role, rewritten 2026-07-22 to match real enforced permissions instead of fabricated text.
- [x] Audit Log tab (new, 2026-07-22): list of recent admin actions on users/roles.

**Backend (Spring Boot, all in `AdminController` — no dedicated Service, per project convention for simple CRUD-style admin operations):**
- [x] `GET /api/admin/users?roleType=&search=&page=&size=` — list/search/filter (roleType: `learner`/`trainer`/`trainer_lead` or `course_manager`/`admin`/`staff`).
- [x] `GET /api/admin/users/{id}` — detail (returns 404, not 400, when not found — fixed 2026-07-22).
- [x] `POST /api/admin/users` — create account via `AuthService.createUserByAdmin`, role whitelisted to `LEARNER`/`TRAINER`/`TRAINER_LEAD`/`ADMINISTRATOR` (previously accepted **any** string and silently created garbage `Role` rows for typos — fixed 2026-07-22).
- [x] `PUT /api/admin/users/{id}/status` — activate/deactivate, status whitelisted to `ACTIVE`/`INACTIVE`, admin cannot lock their own account.
- [x] `PUT /api/admin/users/{id}` — update profile/email/status/role in one call; status now goes through the **same** whitelist + self-lock protection as the endpoint above (previously bypassed both — fixed 2026-07-22, see Edge Cases).
- [x] `GET /api/admin/dashboard/stats` — `totalUsers`, `totalRoles`, `totalCourses`, `totalEnrollments`, 7-day weekly registration counts (real, no longer fabricated — see Edge Cases), `topCourses` (top 5 by enrollment).
- [x] `GET /api/admin/ai-usage` — real call counts (`AiUsageLog`, populated by `GeminiClientService` on every `generateChatResponse`/`generateEmbedding` call), success rate, chat/embedding split, 7-day chart.
- [x] `GET /api/admin/audit-log?limit=` — recent `AuditLog` entries (who did what to which user, when). Scoped to actions taken **through this controller** (create account, update profile/role/status, activate/deactivate) — does **not** cover approve/publish/payment actions in other modules (Course review, Exam publish, Trainer onboarding, Revenue payout all log nothing here; that would be a much larger cross-module change, out of scope for this round).
- [ ] Endpoint paths differ from this doc's original draft (`/api/v1/admin/analytics/overview` etc. were never built that way) — actual paths are flat under `/api/admin/` as listed above; this doc has been corrected to match, per the project's "code is priority" policy.

## 3. Technical Constraints
- **Backend Authorization:** all endpoints `@PreAuthorize("hasRole('ADMINISTRATOR')")` — not `'ADMIN'` (corrected from original draft; `'ADMIN'` is normalized to `'ADMINISTRATOR'` only as a role-name alias when creating accounts, it is not a distinct Spring Security role).
- **Database aggregation:** dashboard/AI-usage stats mix in-memory Java aggregation (existing project-wide pattern — `userRepository.findAll()` then filter/group in Java) with one native SQL query for Top Courses (`CourseRepository.findTopCoursesByEnrollment`, `GROUP BY` + `LIMIT`). No nightly `@Scheduled` batch job — current data volume doesn't need it; revisit if `findAll()`-based aggregation becomes a real bottleneck.
- **Entity alignment:** `roles` table + `user_roles` join table, confirmed as described.
- **Course Manager role name:** the real Spring Security role is `TRAINER_LEAD`, not `COURSE_MANAGER` — `TrainerExamMatrixController` has one inconsistent `hasAnyRole(..., 'COURSE_MANAGER')` check that's effectively dead (no user ever holds that literal role name); flagged for dev, not fixed here (out of RBAC module scope).

## 4. Edge Cases
- **Self-Locking:** Admin cannot deactivate their own account — enforced identically on both `PUT /users/{id}/status` and `PUT /users/{id}` (the latter didn't have this check at all before 2026-07-22).
- **Status whitelist bypass (real bug, fixed 2026-07-22):** `PUT /api/admin/users/{id}` used to call `user.setStatus(updateRequest.getStatus().toUpperCase())` directly with **zero validation**, letting a caller set any arbitrary string (e.g. `"BANNED"`) and bypass both the whitelist and the self-lock check that `PUT /users/{id}/status` enforced. Now shares the same `ALLOWED_USER_STATUSES` whitelist and self-lock guard.
- **Role whitelist bypass (real bug, fixed 2026-07-22):** `AuthService.createUserByAdmin` accepted any non-empty role string; if it didn't already exist as a `Role` row, it silently created one (`roleRepository.save(new Role(typo))`), permanently polluting the `roles` table with garbage on a typo. Now whitelisted to `LEARNER`/`TRAINER`/`TRAINER_LEAD`/`ADMINISTRATOR`, throws `IllegalArgumentException` otherwise. Note the asymmetry this exposed: `updateUserByAdmin`'s role-update path already threw `"Role not found!"` for an unknown role (opposite behavior from create) — now both paths reject unknown roles, just with different messages (create explains the whitelist; update says not found, since by definition every valid role already exists as a row).
- **Fabricated dashboard data (real bug, fixed 2026-07-22):** `getDashboardStats` used to fabricate positive weekly registration numbers (`totalUsers / 7`-based) whenever no real signup happened in the last 7 days, indistinguishable from genuine data. Removed — weeks with no signups now correctly show all zeros.
- **Heavy Query Processing:** not currently a problem at this data scale; if it becomes one, the fix is proper SQL aggregation (as already done for Top Courses), not a background job.

## 5. Non-functional Requirements
- **Performance:** no explicit SLA enforced/measured; existing `findAll()`-based aggregation is consistent with the rest of the codebase's admin/dashboard endpoints (Comment Management, Course Manager Dashboard use the same pattern).
- **Security:** audit log entries are written by the backend only in response to specific admin actions; there is no API to modify/delete them (no `PUT`/`DELETE` endpoint exists for `/api/admin/audit-log`).
