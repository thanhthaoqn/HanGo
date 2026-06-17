# Feature Specification: FT-13 - Analytics Dashboard

## 1. Business Context
Data is the goldmine of an EdTech platform. The Analytics Dashboard provides Admins and Leads with visual reports (Charts, Statistics) on the system's operational performance: Total new learners, most enrolled courses, exam pass/fail rates. This data empowers the administration board to make decisions on improving content quality.

## 2. Acceptance Criteria

**Frontend (Flutter):**
- [ ] Dedicated Dashboard screen for Admins/Leads at `lib/presentation/pages/dashboard/`.
- [ ] Utilize charting packages (e.g., `fl_chart`) to render Bar Charts (New users per month) and Pie Charts (PASS/FAIL ratio).
- [ ] Metric Cards displaying overview numbers (Total Users, Total Courses, Total Revenue if applicable).
- [ ] Allow data filtering by time period (This week, This month, This year).

**Backend (Spring Boot):**
- [ ] API `GET /api/v1/analytics/overview` returns overall numbers (Count users, count courses).
- [ ] API `GET /api/v1/analytics/exams` returns aggregated group pass/fail statistics per exam.
- [ ] Data is returned in structured JSON arrays or Key-Value pairs suitable for Flutter to easily map into Chart DataPoints.

## 3. Technical Constraints
- **Database:** Avoid using loops in Java code to calculate totals. It is mandatory to use SQL Aggregation Functions (`COUNT`, `SUM`, `GROUP BY`) and Native Queries (or JPQL) at the Repository layer to optimize memory.
- **Backend:** Strict authorization using `@PreAuthorize("hasAnyRole('ADMIN', 'LEAD')")`. Learners and Trainers cannot view the system-wide dashboard (Trainers might have a localized dashboard just for their courses).

## 4. Edge Cases
- **Heavy Query Processing:** When the system has millions of records, real-time `COUNT` queries might freeze the DB.
  - *Solution:* Do not query real-time unless necessary. Create a background Job (using Spring's `@Scheduled`) to calculate statistics nightly at 2:00 AM and save to an `analytics_reports` table (or Redis cache). APIs will just retrieve the pre-calculated data.
- **Filtering by Period with No Data:** Frontend must display a "No data available in this period" UI state instead of rendering an empty, distorted chart.

## 5. Non-functional Requirements
- **Performance:** APIs fetching Dashboard data must respond in `< 500ms` (Achievable via caching or highly optimized queries).
- **Visualization:** UI/UX on the Frontend must respond smoothly when the user touches Chart bars to view detailed numbers (Tooltips).
