# HanGo QA Agent Guidelines

> Tài liệu này định nghĩa các quy tắc cho **QA Agent** khi sinh và chạy test trên repo HanGo.
> Đọc cùng với [`/doc/TESTING.md`](TESTING.md) và [`/doc/specs/unit_test_plan.md`](specs/unit_test_plan.md).

---

## 1. Phạm vi & Domain

QA Agent hoạt động trên **toàn bộ repo** (không bị giới hạn domain) nhưng **chỉ được phép**:
- Tạo / sửa / chạy các file test
- Đọc source code để hiểu logic cần test
- **Không được sửa** production source code

---

## 2. Tech Stack & Tools

### Backend (Spring Boot)
| Công cụ | Mục đích |
|---|---|
| **JUnit 5** | Test framework chính |
| **Mockito** | Mock Repository/Service dependencies |
| **Spring Boot Test** (`@SpringBootTest`) | Integration testing |
| **MockMvc** | HTTP endpoint testing |
| **Testcontainers** | Database integration testing với MySQL thật |
| **H2** | In-memory DB fallback cho unit tests |

### Frontend (Flutter)
| Công cụ | Mục đích |
|---|---|
| **flutter_test** | Unit & Widget testing |
| **mockito** (Dart) | Mock dependencies |
| **flutter_lints** | Static analysis |

---

## 3. Test Priorities (Ưu tiên theo nghiệp vụ)

QA Agent phải ưu tiên test theo mức độ nghiệp vụ quan trọng:

### 🔴 CRITICAL — Bắt buộc có test trước khi Done
1. **Payment & Revenue** (FE-12): **PayOS** webhook idempotency, chữ ký HMAC-SHA256, đối soát amount, revenue split (Teacher/`PROFESSIONAL` 70% · Tutor/`PEER_TUTOR` 60%) — *đã có test đầy đủ tại `PaymentServiceImplTest`/`MonthlyStatementServiceImplTest`/`CartServiceImplTest`, cập nhật tên lớp cũ "VNPay IPN" vì cổng thanh toán thật là PayOS.*
2. **RBAC / Authorization** (FE-03): Mọi API endpoint phải test với đúng role và sai role
3. **Exam Grading** (FE-08): Tính điểm tự động, 40 câu / 50 phút
4. **Authentication** (FE-01): JWT validation, OTP verification — *lưu ý: hiện chỉ cấp 1 JWT, chưa có refresh token/logout endpoint thật (xem `AUDIT_REPORT.md` MED-11) — đừng viết test cho refresh token cho tới khi tính năng này thực sự tồn tại.*

### 🟡 IMPORTANT — Cần có test
5. **Course Versioning** (FE-05, FE-06): Published course tạo version mới khi sửa
6. **Learning Progress** (FE-10): Sequential unlock (Lesson N → N+1)
7. **Recommendation** (FE-11): Weakness analysis theo SkillType

### 🟢 NORMAL — Test khi có thời gian
8. Các module còn lại (FE-02, FE-04, FE-07, FE-09, FE-13, FE-14)

---

## 4. Test Structure — Backend

> **Cập nhật 2026-07-17 để khớp thực tế đang làm (chỉ đạo tester):** unit test **chỉ tập trung ở Service layer**. Không viết/duy trì test Controller (MockMvc) hay integration test (Testcontainers) — cấu trúc `controller/`/`integration/` bên dưới là **định hướng tương lai, chưa áp dụng**, không phải mô tả hiện trạng. Ngoại lệ: class không có Service riêng (business logic nằm thẳng trong Controller, ví dụ `AdminController.updateUserStatus`) vẫn được test trực tiếp bằng Mockito thuần (không phải MockMvc) vì đó là nơi duy nhất chứa logic cần test.

```
hango-backend/src/test/java/com/.../
├── service/          # Unit tests (mock Repository) — SCOPE HIỆN TẠI
│   ├── AuthServiceTest.java
│   ├── TrainerOnboardingServiceTest.java
│   └── ExamServiceTest.java
├── controller/       # Chỉ giữ các class KHÔNG có Service riêng (vd AdminControllerTest.java, Mockito thuần)
├── controller/       # [Định hướng tương lai — chưa làm] Integration tests (MockMvc) cho phần còn lại
└── integration/      # [Định hướng tương lai — chưa làm] Full stack tests (Testcontainers)
    └── PaymentFlowTest.java
```

**Quy tắc đặt tên (khớp code hiện tại):**
- Unit test: `{ClassName}Test.java`
- Method: `{methodUnderTest}Should{ExpectedBehavior}When{Condition}` (fluent style, ví dụ `authenticateUserShouldRejectInactiveAccount`) — không dùng `given/when/then` như bản cũ ghi.
- Comment trong file test: chỉ dùng divider 3 dòng theo tên method (`// === methodName ===`), không viết Javadoc giải thích logic production.

**Coverage requirement:** ≥ 80% cho Service layer của mọi module CRITICAL.

---

## 5. Test Structure — Frontend

```
hango-frontend/test/
├── unit/             # Business logic, data parsing, state
│   ├── models/
│   └── providers/
└── widget/           # UI component tests
    ├── shared/       # Shared components trong lib/shared/
    └── pages/
```

---

## 6. Acceptance Criteria Checklist

Trước khi viết test, QA Agent phải đọc Acceptance Criteria trong `/doc/specs/0X-<module>.md` và xác nhận test cover:
- [ ] Happy path (luồng thành công)
- [ ] Sad path (lỗi business logic: sai role, dữ liệu không hợp lệ)
- [ ] Edge case (boundary values, empty input, concurrent requests với idempotency)

---

## 7. Running Tests

```bash
# Backend — tất cả tests
cd hango-backend && mvnw test

# Backend — chỉ một class
mvnw test -Dtest=PaymentServiceImplTest

# Frontend — tất cả tests
cd hango-frontend && flutter test

# Frontend — static analysis
flutter analyze
```

---

## 8. Escalation

QA Agent PHẢI DỪNG và log vào `/TODO.md` mục `🛑 Escalated to Human` nếu:
- Test fail sau 3 lần fix mà không hiểu nguyên nhân
- Phát hiện production bug nghiêm trọng trong quá trình viết test
- Cần sửa production code để test pass (vượt phạm vi QA Agent)
