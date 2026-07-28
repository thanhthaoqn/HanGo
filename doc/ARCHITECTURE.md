# HanGo System Architecture

> Tài liệu này mô tả chi tiết kiến trúc kỹ thuật. Cho business requirements, xem [`HanGo_Documentation.md`](HanGo_Documentation.md) v1.0 §5.

## 1. System Overview & Monitored Context

**System Overview:**
HanGo is an EdTech platform built on a modern Client-Server architecture. The system consists of independent layers that communicate via RESTful APIs, ensuring scalability, maintainability, and clear separation of concerns.
- **Frontend (Client):** A cross-platform application built with Flutter.
- **Backend (Server):** A RESTful API server built with Java 21 and Spring Boot.
- **Database:** A relational database using MySQL.

**Monitored Context:**
The system manages several core EdTech domains that dictate the architecture:
- **Identity & Access:** Role-based contexts for Learners, Trainers, Course Managers, and Admins.
- **Course Management:** Hierarchical content (Courses > Sections > Lessons).
- **Assessment:** Question Banks, Exams, and automated grading.
- **Learner Progress:** Tracking enrollments, exam attempts, and completion metrics.

## 2. Core Tech Stack & Constraints

**Frontend (Flutter):**
- **Framework:** Flutter (Dart SDK `^3.12.0`).
- **Networking & Storage:** `dio`, `http`, `shared_preferences`.
- **Authentication:** `google_sign_in` for OAuth integration.
- **Constraints:** Must support responsive design across different form factors (Mobile, Tablet, Web). State is managed via localized mechanisms, meaning data fetching and caching must be handled carefully without a heavy global state manager.

**Backend (Spring Boot):**
- **Core Framework:** Java 17, Spring Boot (4.0.6 parent). *(`pom.xml` pins `java.version=17`; CI/deploy workflows install a JDK 21 toolchain to build with, but the compiled language level is 17 — no Java 21-only syntax is used anywhere in the codebase as of 2026-07-24.)*
- **Data Access:** Spring Data JPA, Hibernate, MySQL Connector/J. Schema is managed via Hibernate `ddl-auto` (no Flyway/Liquibase yet — see `AUDIT_REPORT.md` HIGH-01).
- **Third-Party Integrations:** Google API Client (OAuth2), Cloudinary (Media storage), PayOS (payment gateway — supersedes an earlier VNPay design; some field/column names like `Payment.vnpayTxnNo` still carry the old name).
- **Constraints:** Must provide consistent JSON structures for all API responses (currently inconsistent across controllers — see `AUDIT_REPORT.md` HIGH-05).

**Database:**
- **System:** MySQL.
- **Constraints:** Data integrity relies heavily on relational constraints (Foreign Keys). Entities are strictly normalized.

## 3. Folder Structure & Code Patterns

### 3.1 Frontend Architecture (Clean/Layered Pattern)
The frontend separates UI from business logic and data fetching, allowing easier testing and maintenance.
- **`lib/data/`**: Handles data retrieval and storage (e.g., API services, local caching).
- **`lib/domain/`**: Core business logic, entities, and repository interfaces.
- **`lib/presentation/`**: The UI layer containing `pages/` (screens) and `widgets/` (reusable components).
- **`lib/utils/`**: Shared utilities and constants.

### 3.2 Backend Architecture (N-Tier Pattern)
The backend enforces a strict N-Tier pattern where Controllers only talk to Services, and Services talk to Repositories.
- **`config/`**: Security, CORS, and external Bean configurations.
- **`controller/`**: REST endpoints, routing, and DTO validation.
- **`service/`**: Core business logic and transaction management.
- **`repository/`**: Database interactions via Spring Data JPA.
- **`entity/`**: JPA models mapping directly to MySQL tables.
- **`dto/`**: Data Transfer Objects for API payloads (Entities are never exposed directly to the client). Mapping is done manually (`@Builder` chains / field copies) — no MapStruct is actually used despite earlier plans.
- **`exeption/`**: Global error handling (`@ControllerAdvice`) — package name is spelled this way in the real code (not "exception"). Currently only catches a custom `ApiException`; most services throw plain `RuntimeException` instead (see `AUDIT_REPORT.md` HIGH-05).
- **`sercurity/`**: JWT filters and authentication logic — package name is spelled this way in the real code (not "security").

## 4. Data Flow & Security Constraints

**Typical API Data Flow:**
1. **Client (Flutter)** initiates an HTTP request using `dio` (with JWT injected in headers).
2. **Backend Security Filter** intercepts the request, parsing and validating the JWT via `jjwt`.
3. **Controller** receives the request, validates the incoming DTO payload.
4. **Service** executes business logic (e.g., calculating exam scores, checking course ownership).
5. **Repository** queries or mutates the MySQL database.
6. **Service** returns a domain entity to the Controller, which maps it back to a Response DTO and returns it as a structured JSON.

**Security Constraints:**
- **Stateless Authentication:** Handled exclusively via JWT. Tokens must be stored securely on the client (`shared_preferences`).
- **Role-Based Access Control (RBAC):** Strict enforcement at both the API level and the UI routing level (e.g., Trainers cannot access Course Manager dashboards).
- **Payload Validation:** All incoming data must pass through DTO validation (`spring-boot-starter-validation`) before reaching business logic layers.

## 5. Architectural Quality Gates
- **Frontend Lints:** Enforcement of Dart coding standards and best practices via `flutter_lints`.
- **Backend Validation:** Mandatory usage of DTO validation annotations (e.g., `@NotNull`, `@Size`) to prevent malformed data from causing internal errors.
- **Centralized Error Handling:** `@ControllerAdvice` ensures that unexpected backend exceptions are caught and mapped to standard API error responses, preventing stack traces from leaking to the client.
- **Testing Layers:** The architecture supports integration testing (`spring-boot-starter-test`) for backend and widget/unit testing (`flutter_test`) for the frontend.
