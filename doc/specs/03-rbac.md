# Feature Specification: FE-03 — Role & Permission Management (RBAC) & Dashboard

> Ref: [HanGo_Documentation.md](../HanGo_Documentation.md) §7.3 (RBAC)

## 1. Business Context
Role-Based Access Control (RBAC) ensures the right people have the right access. Administrators can manage users, roles, and platform permissions. Additionally, this module encompasses the Analytics Dashboard, providing Admins with visual reports (Charts, Statistics) on the system's operational performance, AI usage, and audit logs.

## 2. Acceptance Criteria

**Frontend (Flutter):**
- [ ] User list interface for Admin to view, search, and filter users by role and status.
- [ ] Activate / Deactivate (lock/unlock) user accounts.
- [ ] UI to manually create accounts (e.g., for Course Managers) and assign/update roles.
- [ ] Dedicated Dashboard screen for Admins at `lib/presentation/pages/dashboard/` utilizing `fl_chart` for Analytics.
- [ ] Metric Cards displaying overview numbers (Total Users, Total Courses, Total Revenue, AI Usage).

**Backend (Spring Boot):**
- [ ] API `GET /api/v1/admin/users`, `POST /api/v1/admin/users`, `PUT /api/v1/admin/users/{id}/roles` utilizing the `Role` and `User` entities.
- [ ] API `PUT /api/v1/admin/users/{id}/status` to lock/unlock accounts.
- [ ] API `GET /api/v1/admin/analytics/overview` and `GET /api/v1/admin/analytics/ai-usage`.
- [ ] API `GET /api/v1/admin/audit-logs` for viewing critical administrative actions.

## 3. Technical Constraints
- **Backend Authorization:** All endpoints in this module must be strictly protected with `@PreAuthorize("hasRole('ADMIN')")`.
- **Database:** Avoid loops in Java code to calculate analytics totals. Use SQL Aggregation Functions (`COUNT`, `SUM`, `GROUP BY`).
- **Entity Alignment:** Roles are stored in a many-to-many relationship using the `roles` table and `User.roles` set.

## 4. Edge Cases
- **Self-Locking:** Admin must be prevented from deactivating their own account (Return HTTP 400).
- **Heavy Query Processing:** Real-time `COUNT` queries might freeze the DB. Create a background Job (`@Scheduled`) to calculate statistics nightly if the dataset is large.

## 5. Non-functional Requirements
- **Performance:** APIs fetching Dashboard data must respond in `< 500ms`.
- **Security:** Ensure audit logs cannot be modified or deleted via API.
