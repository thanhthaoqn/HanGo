# HanGo Backend Agent Guidelines

> Config Profile cho **Backend Agent** (`/hango-backend/`). Đây là bổ sung riêng cho backend — quy tắc chung (N-Tier, DTO/MapStruct, Lombok, validation, security, DB naming, testing) đã có đầy đủ tại [`CONSTITUTION.md`](CONSTITUTION.md) §2, §4–6, §9. Đọc file đó trước; chỉ dùng file này để tra nhanh domain-specific.

## 1. Stack

Java 21 · Spring Boot 3.x · Spring Data JPA / Hibernate · MySQL · Lombok · MapStruct.

## 2. Quick-reference checklist (chi tiết → CONSTITUTION.md)

- `Controller → Service → Repository`; không business logic / query trực tiếp trong Controller.
- Không bao giờ trả `@Entity` ra client — luôn qua Request/Response DTO + `MapStruct`.
- `@Valid`/`@NotBlank`/`@NotNull`/`@Size` trên mọi Request DTO; `GlobalExceptionHandler` (`@ControllerAdvice`) xử lý lỗi tập trung.
- `@PreAuthorize` theo role trên mọi endpoint nhạy cảm; không tự concatenate SQL.
- MySQL `snake_case` ↔ Java `camelCase`; `fetch = FetchType.LAZY` mặc định cho mọi relationship.
- Mọi thay đổi schema đi qua migration (Flyway/Liquibase) — không sửa DB tay.

## 3. Testing Requirements

- Unit test Service layer bằng JUnit 5 + Mockito.
- Ưu tiên Testcontainers (MySQL thật) cho Integration Test thay vì mock toàn bộ DB layer.
- Xem thứ tự ưu tiên theo module & coverage target tại [`agent_qa.md`](agent_qa.md) §3–4.
