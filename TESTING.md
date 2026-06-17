# HanGo Testing Strategy

This document outlines the testing methodologies and expectations for both the Frontend (Flutter) and Backend (Spring Boot) of the HanGo platform.

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
  - Specifically test complex logic: Exam score calculation, Task state transitions, and Authorization rules.

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
- **Lead Flow:** Login -> View Pending Courses -> Approve Course.

### 3.2 AI Agent Testing
- AI responses are non-deterministic, making them hard to unit test.
- **Strategy:** Create a suite of "golden queries" (e.g., asking to explain Present Continuous tense).
- Verify that the AI response contains specific keywords and does not reveal direct answers.
- Monitor API latency and error rates during load testing.
