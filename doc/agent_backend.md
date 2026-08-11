# HanGo Backend Agent Guidelines

> Config Profile cho **Backend Agent** (`/hango-backend/`). Đây là bổ sung riêng cho backend — quy tắc chung (N-Tier, DTO/MapStruct, Lombok, validation, security, DB naming, testing) đã có đầy đủ tại [`CONSTITUTION.md`](CONSTITUTION.md) §2, §4–6, §9. Đọc file đó trước; chỉ dùng file này để tra nhanh domain-specific.

## 1. Stack

Java 17 · Spring Boot 4.0.6 · Spring Data JPA / Hibernate · MySQL · Lombok.

*(Cập nhật 2026-07-24 để khớp `pom.xml`/code thật — không phải "Java 21/Spring Boot 3.x" như bản cũ. MapStruct đã bị bỏ khỏi danh sách stack: chưa từng được dùng trong code, xem dưới.)*

## 2. Quick-reference checklist (chi tiết → CONSTITUTION.md)

- `Controller → Service → Repository`; không business logic / query trực tiếp trong Controller (ngoại lệ hiện có: `AdminController`, `SectionQuestionController`, `TrainerQuestionAIController` — không có Service riêng hoặc Service không tự kiểm tra role).
- Không bao giờ trả `@Entity` ra client — luôn qua Request/Response DTO. **Mapping hiện tại là thủ công** (`@Builder` chain / copy field trong Service) — MapStruct **chưa** được dùng ở đâu trong code; giữ nguyên style thủ công cho nhất quán, không tự ý thêm MapStruct cho 1 DTO đơn lẻ.
- `@Valid`/`@NotBlank`/`@NotNull`/`@Size` trên mọi Request DTO; `GlobalExceptionHandler` (`@ControllerAdvice`) xử lý lỗi tập trung — **lưu ý:** hiện chỉ bắt `ApiException`, phần lớn Service ném `RuntimeException` thẳng nên không đi qua handler này (gap đã ghi nhận, xem `HanGo_Documentation.md` §22).
- Phân quyền hiện là **hybrid**: `@PreAuthorize("hasAuthority('MÃ_PERMISSION') or hasRole('ADMINISTRATOR')")` ở phần lớn endpoint (permission code lưu DB, Admin cấu hình được qua `PUT /api/admin/roles/{roleName}/permissions`), nhưng một số controller (`CourseManagerDashboardController`, `ManagementTicketController`) vẫn dùng thuần `hasAnyRole(...)` theo tên role. Không tự concatenate SQL. **Đã phát hiện thiếu `@PreAuthorize` hoàn toàn ở `SectionQuestionController`** (8 endpoint) **và `TrainerQuestionAIController`** (3 endpoint) — xem `HanGo_Documentation.md` §22 trước khi thêm endpoint mới vào 2 controller này.
- MySQL `snake_case` ↔ Java `camelCase`; `fetch = FetchType.LAZY` mặc định cho mọi relationship.
- **Trạng thái thật:** chưa có migration tool (Flyway/Liquibase) — schema qua Hibernate `ddl-auto`, mặc định hiện là **`validate`** (đã đổi từ `update`, an toàn hơn). Đừng tự thêm Flyway cho một task đơn lẻ mà không xác nhận trước.

## 3. Testing Requirements

- Unit test Service layer bằng JUnit 5 + Mockito — **đây là toàn bộ phạm vi test hiện tại** (~36 test class tính tới 2026-08-10; module Ticket mới chưa có test nào).
- Testcontainers/Integration Test **chưa được dùng** trong suite hiện tại — đây vẫn là định hướng tương lai (xem `agent_qa.md` §4), không phải việc cần làm ngay cho mỗi task mới trừ khi được giao riêng.
- Xem thứ tự ưu tiên theo module & coverage target tại [`agent_qa.md`](agent_qa.md) §3–4.
