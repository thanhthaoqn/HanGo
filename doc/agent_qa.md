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
1. **Payment & Revenue** (FE-12): VNPay IPN idempotency, checksum verification, amount reconciliation, revenue split (Teacher 70% / Tutor 60%)
2. **RBAC / Authorization** (FE-03): Mọi API endpoint phải test với đúng role và sai role
3. **Exam Grading** (FE-08): Tính điểm tự động, 40 câu / 50 phút
4. **Authentication** (FE-01): JWT validation, refresh token, OTP verification

### 🟡 IMPORTANT — Cần có test
5. **Course Versioning** (FE-05, FE-06): Published course tạo version mới khi sửa
6. **Learning Progress** (FE-10): Sequential unlock (Lesson N → N+1)
7. **Recommendation** (FE-11): Weakness analysis theo SkillType

### 🟢 NORMAL — Test khi có thời gian
8. Các module còn lại (FE-02, FE-04, FE-07, FE-09, FE-13, FE-14)

---

## 4. Test Structure — Backend

```
hango-backend/src/test/java/com/.../
├── service/          # Unit tests (mock Repository)
│   ├── AuthServiceTest.java
│   ├── PaymentServiceTest.java
│   └── ExamServiceTest.java
├── controller/       # Integration tests (MockMvc)
│   ├── AuthControllerTest.java
│   └── ...
└── integration/      # Full stack tests (Testcontainers)
    └── PaymentFlowTest.java
```

**Quy tắc đặt tên:**
- Unit test: `{ClassName}Test.java`
- Method: `given{Condition}_when{Action}_then{Expected}`

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
mvnw test -Dtest=PaymentServiceTest

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
