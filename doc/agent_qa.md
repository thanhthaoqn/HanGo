# HanGo QA Agent Guidelines

> Tài liệu này định nghĩa các quy tắc cho **QA Agent** khi sinh và chạy test trên repo HanGo.
> Đọc cùng với [`/doc/test_doc/TESTING.md`](test_doc/TESTING.md) và [`/doc/test_doc/unit_test_plan.md`](test_doc/unit_test_plan.md) — vị trí đã cập nhật 2026-08-10 (không còn `doc/TESTING.md`/`doc/specs/unit_test_plan.md` ở vị trí cũ).

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

> Mã module đã cập nhật 2026-08-10 để khớp Feature Map 19-module hiện tại (`HanGo_Documentation.md` §6). Xem bảng đối chiếu số cũ→mới ở `doc/specs/` nếu cần tra lại test case cũ viết theo mã FE trước đây.

QA Agent phải ưu tiên test theo mức độ nghiệp vụ quan trọng:

### 🔴 CRITICAL — Bắt buộc có test trước khi Done
1. **Payment & Revenue** (FE-14): **PayOS** webhook idempotency, chữ ký HMAC-SHA256, đối soát amount, revenue split (Teacher/`PROFESSIONAL` 70% · Tutor/`PEER_TUTOR` 60%), thuế TNCN 10% khi ≥2 triệu VND — *đã có test tại `PaymentServiceImplTest`/`MonthlyStatementServiceImplTest`/`CartServiceImplTest`.*
2. **Role and Permission Management** (FE-04) + **Account Management** (FE-03): RBAC giờ là ma trận động (`Permission`/`role_permissions`, `PUT /api/admin/roles/{roleName}/permissions`) — test cả 2 chiều: endpoint tôn trọng permission đã cấu hình, **và** các endpoint biết là chưa đọc permission code (`CourseManagerDashboardController`, `ManagementTicketController` — vẫn dùng `hasAnyRole` thuần) không bị kỳ vọng nhầm là đã theo ma trận.
3. **Exam Grading** (FE-09): Tính điểm tự động server-side, thang 10 — *lưu ý: "40 câu/50 phút" chỉ đúng cho 1 Exam đặt sẵn (Entry Placement Test, id=999), không phải rule chung cho mọi Exam — đừng viết test giả định mọi Exam đều 40 câu/50 phút.*
4. **Authentication** (FE-01): JWT + refresh token (đã có bảng `RefreshToken`, lưu hash, xoay vòng single-use), OTP verification, khoá 15 phút sau 5 lần sai mật khẩu.
5. **Ticket Management** (FE-16): module mới, **hiện chưa có test class nào** (`TicketServiceImpl` chưa có `TicketServiceImplTest`) — ưu tiên bổ sung, đặc biệt luồng Course Manager bị chặn xử lý category `PAYOUT_INFO_UPDATE`/`REFUND_REQUEST`.

### 🟡 IMPORTANT — Cần có test
6. **Course Versioning** (FE-06): Published course tạo version mới khi sửa — nhớ cover cả 2 đường tới `PUBLISHED` (review chuẩn qua Course Manager, và "legacy self-publish" của Trainer).
7. **Learning Progress** (FE-13): tính % hoàn thành, cờ `COMPLETED` — *sequential unlock (Lesson N → N+1) hiện chỉ enforce ở Frontend, chưa có ở server; nếu QA phát hiện gọi thẳng API bỏ qua được thứ tự, đây là gap đã biết (xem `HanGo_Documentation.md` §22), không phải phát hiện mới cần báo lại.*
8. **AI Recommendation** (FE-11): Weakness analysis từ câu trả lời sai, IDOR khả dĩ ở `recommendCoursesAI` (không verify chủ sở hữu `examAttemptId`) đáng được test riêng.
9. **Exam Matrix Management** (FE-10): generate Exam từ matrix lấy đúng số câu theo luật.

### 🟢 NORMAL — Test khi có thời gian
10. Các module còn lại: FE-02 (Profile), FE-05 (Trainer Application), FE-07 (Course Content), FE-08 (Question Bank), FE-12 (AI Assistant), FE-15 (Cart), FE-17 (Comment), FE-18 (Notification), FE-19 (Dashboard).

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
