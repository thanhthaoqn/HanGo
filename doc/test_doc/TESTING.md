# HanGo Testing Strategy

> **Xem thêm:** Chi tiết test cases từng module → [`unit_test_plan.md`](unit_test_plan.md)
> **QA Agent rules:** [`../agent_qa.md`](../agent_qa.md)

This document outlines the testing methodologies and expectations for both the Frontend (Flutter) and Backend (Spring Boot) of the HanGo platform.

## 0. Code-First Principle

Dự án thay đổi liên tục trong quá trình phát triển — method có thể bị đổi tên, tách/gộp class, hoặc chưa được implement dù spec đã mô tả. Vì vậy:

- **Nguồn chân lý cho việc viết test là code thực tế** (`hango-backend/src/main/java/...`, `hango-frontend/lib/...`), không phải mô tả trong markdown. Markdown (`HanGo_Documentation.md`, `doc/specs/*.md`) cho biết **ý định nghiệp vụ**; code cho biết **hành vi thật**. Khi hai bên lệch nhau, test phải phản ánh code hiện tại và ghi chú lại phần lệch (xem mẫu phản hồi ở [`AGENTS.md`](../AGENTS.md) §13) thay vì viết test theo doc rồi để nó fail.
- Trước khi viết test cho một method, **đọc lại source hiện tại** để xác nhận: tên method/class còn đúng không, signature (tham số/kiểu trả về) là gì, method đã tồn tại hay còn `[PLANNED]`.
- [`unit_test_plan.md`](unit_test_plan.md) là **kế hoạch sống** (living plan): Method List (§1) phải được đối chiếu lại với code mỗi khi có đợt cập nhật lớn, không viết một lần rồi coi là cố định. Cột trạng thái *Implemented / Planned* trong đó phản ánh tình trạng code tại thời điểm cập nhật gần nhất — không phải mục tiêu thiết kế lý tưởng.
- Không tự ý đánh dấu test case là "Passed" khi chưa thực sự chạy — trạng thái mặc định của một kế hoạch (plan) là **Untested**; chỉ cập nhật Passed/Failed sau khi test thật sự được viết và chạy.

## 1. Frontend Testing (Flutter)

### 1.1 Widget Testing (UI Components)
- **Scope:** Test individual UI components (e.g., Teal Buttons, Course Cards, Question Modals) to ensure they render correctly and respond to user interactions.
- **Tools:** `flutter_test`
- **Guidelines:**
  - Mock backend responses to test loading, error, and success states.
  - Verify that navigation works when buttons are pressed.
  - Check that dynamic elements (like the Exam Timer) update correctly.

### 1.2 Unit Testing (Business Logic)
- **Scope:** Test utility functions, data parsing, and state management logic (e.g., Riverpod providers or ViewModels).
- **Guidelines:**
  - Write tests for data models (parsing JSON from backend to Dart objects).
  - Test validation logic for forms (e.g., Email format checking in Login/Register).

### 1.3 Static Analysis
- Run `flutter analyze` locally and in CI/CD pipelines.
- Ensure 0 warnings and 0 errors based on the `analysis_options.yaml` (using `flutter_lints`).

## 2. Backend Testing (Spring Boot)

### 2.1 Unit Testing
- **Scope:** Service layer and utility classes.
- **Tools:** JUnit 5, Mockito.
- **Guidelines:**
  - Mock the Repository layer to test Service business logic in isolation.
  - Specifically test complex logic: Exam score calculation, and Authorization rules.

### 2.2 Integration Testing
- **Scope:** Controller -> Service -> Repository layer interaction.
- **Tools:** `@SpringBootTest`, `MockMvc`, Testcontainers (for database).
- **Guidelines:**
  - Use `MockMvc` to send HTTP requests to endpoints and verify the JSON response and HTTP status codes.
  - Test authentication endpoints with valid and invalid JWTs.
  - Use an in-memory database (H2) or Testcontainers (MySQL) to ensure database queries work correctly.

## 3. End-to-End (E2E) & User Acceptance Testing (UAT)

### 3.1 Critical User Journeys (CUJs)
E2E testing should cover the most important workflows defined in the SRS:
- **Learner Flow:** Login -> Browse Courses -> Start Exam -> Submit Exam -> View Results.
- **Trainer Flow:** Login -> Open Course Builder -> Create Curriculum -> Add Question -> Submit for Review.
- **Course Manager Flow:** Login -> View Pending Courses -> Approve Course.

### 3.2 AI Agent Testing
- AI responses are non-deterministic, making them hard to unit test.
- **Strategy:** Create a suite of "golden queries" (e.g., asking to explain Present Continuous tense).
- Verify that the AI response contains specific keywords and does not reveal direct answers.
- Monitor API latency and error rates during load testing.
