# Feature Specification: FE-19 — Dashboard

> Ref: [HanGo_Documentation.md](../HanGo_Documentation.md) §7.19 (DASH). Module tách riêng trong Feature Map 19-module (2026-08-10) — trước đây là mục "Platform Monitoring" gộp trong RBAC. Account/Role management is [03-account-management.md](03-account-management.md)/[04-role-permission-management.md](04-role-permission-management.md).

## 1. Business Context
Mỗi role có 1 dashboard riêng theo phạm vi của mình — không có 1 trang "Dashboard" chung cho mọi role. **Chỉ Administrator** giám sát AI Usage toàn hệ thống. **Không có số liệu doanh thu** trên Admin Platform Dashboard hay Course Manager Dashboard — doanh thu chỉ hiển thị trực tiếp trên Trainer Dashboard (phạm vi doanh thu của chính Trainer đó) và trên trang Settlement riêng của Course Manager ([14-payment-revenue.md](14-payment-revenue.md)).

## 2. Acceptance Criteria

**Frontend (Flutter):**
- [ ] Admin: `admin_dashboard_page.dart` tab Dashboard — stat card (Total Users/Roles/Courses/Enrollments), biểu đồ đăng ký 7 ngày, Top 5 Course theo enroll. **Không** có số tiền/doanh thu ở tab này.
- [ ] Admin: tab "AI Analytics" — tổng lượt gọi, tỉ lệ thành công, breakdown Chat/Embedding, biểu đồ 7 ngày.
- [ ] Admin: tab "Audit Log" — danh sách hành động Admin gần đây trên tài khoản/role.
- [ ] Course Manager: `course_manager_dashboard_page.dart` — stat card + chart tập trung vào số Course/Exam đang chờ/active/inactive, **không** có số tiền.
- [ ] Trainer: `trainer_dashboard_page.dart` — stat card (Courses/Learners/Exams/**Total Revenue**/Average Rating), biểu đồ doanh thu theo tháng, hoạt động gần đây.

**Backend (Spring Boot):**
- [ ] `GET /api/admin/dashboard/stats` — `totalUsers`, `totalRoles`, `totalCourses`, `totalEnrollments`, `weeklyLabels`/`weeklyValues` (đăng ký mới 7 ngày, số thật), `topCourses` (top 5 theo enroll). Không inject `PaymentRepository` cho endpoint này — xác nhận **không có** field doanh thu nào.
- [ ] `GET /api/admin/ai-usage` — `totalCalls`, `successCount`/`failureCount`, `chatCalls`/`embeddingCalls`, `successRate`, biểu đồ 7 ngày. Số liệu này **gộp chung** mọi tính năng gọi Gemini (AI Assistant + AI Recommendation + Learning Pathway/Mentor Chat) vì tất cả đi qua 1 điểm chốt `GeminiClientService` — chỉ tách theo `callType` (CHAT/EMBEDDING), không tách theo tính năng gọi.
- [ ] `GET /api/admin/audit-log?limit=` — hành động Admin trên user/role (tạo/sửa/status), **không** mở rộng sang approve/publish/payment ở module khác.
- [ ] `GET /api/v1/course-manager/dashboard` — `registeredUsersCount`, `activeCoursesCount`, `inactiveCoursesCount`, `examsCount`. Không có field doanh thu.
- [ ] `GET /api/v1/trainer/dashboard` — `coursesCount`, `learnersCount`, `examsCount`, `totalRevenue`, `averageRating`, `courses`, `recentActivities`, `monthlyRevenues` (12 tháng).

## 3. Technical Constraints
- **Aggregation kiểu hiện tại:** phần lớn dashboard dùng Java in-memory filter/group (`findAll()` rồi lọc), trừ Top Courses dùng SQL native `GROUP BY`/`LIMIT` — chưa có job `@Scheduled` tổng hợp trước, tính real-time mỗi lần gọi API.
- **Không tách được nguồn gọi AI trong AI Usage dashboard** — nếu cần biết riêng AI Assistant vs Learning Pathway gọi bao nhiêu, phải thêm field phân loại mới ở `AiUsageLog`, hiện chưa có.

## 4. Edge Cases
- **Tuần không có đăng ký mới:** biểu đồ hiển thị đúng số 0 (đã sửa từ lỗi tự bịa số cũ, xác nhận lại đúng ở đợt audit này).
- **Muốn xem doanh thu toàn platform (không phải riêng 1 Trainer):** Admin/Course Manager phải qua `GET /payment/manager/all` hoặc `MonthlyStatementController`, **không** có ở bất kỳ dashboard stat-card nào.
- **Muốn biết ai đã Approve/Reject 1 Course/Exam cụ thể:** Audit Log hiện tại **không** ghi nhận — chỉ ghi hành động trên tài khoản/role.

## 5. Non-functional Requirements
- **Performance:** chưa có SLA đo lường riêng cho các endpoint dashboard; khối lượng dữ liệu hiện tại chưa cần tối ưu thêm ngoài phần Top Courses đã dùng SQL native.
