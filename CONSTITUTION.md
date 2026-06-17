# HanGo Project Constitution

This document is the "Constitution" of the HanGo EdTech Platform project. All AI Coding Agents (such as Cursor, GitHub Copilot, Windsurf, etc.) and Developers participating in the project's development must strictly adhere to the rules and principles defined below.

## 1. Project Context & Vision
- **Project Name:** HanGo
- **Description:** An educational technology (EdTech) platform focused on personalizing learning experiences, assessing language proficiency, and applying AI to create optimal learning paths.
- **Platform:**
  - **Frontend:** Flutter (Web-first approach).
  - **Backend:** Java 21, Spring Boot.
  - **Database:** MySQL.
- **Primary Users:** Learner, Trainer (Instructor/Content Creator), Training Lead, Admin.

## 2. Core Architectural Principles
- **N-Tier Architecture (Backend):** Adhere to the one-way data flow `Controller` -> `Service` -> `Repository`. Absolutely no business logic should be written in the Controller.
- **Widget Segregation (Frontend):** Separate UI components into small, reusable Widgets in the `lib/shared/` directory. Do not write excessively long UI code in a single file.
- **State Management (Frontend):** Completely separate UI and Logic. Do not make direct API calls inside the `build()` function.

## 3. Frontend Guidelines (Flutter & UI/UX)
- **Framework & Libraries:** Dart `^3.12.0`, Flutter, Riverpod (state management), `go_router` (routing).
- **Colors & UI/UX:**
  - **Primary Color:** Teal Green (`#20B486`). 
  - **Background & Text:** Slate 50 (`#F8FAFC`) for background, Slate 800 (`#1E293B`) for text.
  - **ABSOLUTELY NO** use of Blue as the primary color.
- **Responsive Design:** 
  - Desktop: Fixed left sidebar (240px).
  - Mobile/Tablet: Sidebar automatically hides into a Drawer (Hamburger menu).
  - All screens must be wrapped in `LayoutBuilder` or `MediaQuery` to ensure responsiveness across multiple devices.

## 4. Backend Guidelines (Spring Boot)
- **Framework & Libraries:** Java 21, Spring Boot 3.x.
- **Entities & DTOs:** 
  - ABSOLUTELY DO NOT return `@Entity` directly from the Controller to the client. 
  - Always use DTOs (Data Transfer Objects) for Request/Response and use `MapStruct` to map between Entities and DTOs.
- **Lombok:** Optimize boilerplate code using annotations such as `@Data`, `@Builder`, `@NoArgsConstructor`, `@AllArgsConstructor`.
- **Validation:** Mandatory application of input validation annotations (e.g., `@Valid`, `@NotBlank`, `@NotNull`) on request DTOs.

## 5. Database Guidelines (MySQL)
- **Naming Conventions:** 
  - Database (Table/Column): Use `snake_case` (Example: `course_id`, `user_name`).
  - Java Entity Properties: Use `camelCase` (Example: `courseId`, `userName`).
- **Relationships & Performance:**
  - Clearly define foreign key constraints `@ManyToOne`, `@OneToMany`.
  - Always default to `fetch = FetchType.LAZY` for relationships to avoid N+1 Query issues.

## 6. Security, Data Privacy & Rules
- **Data Privacy:** All sensitive user information (Passwords, Emails, Phone Numbers) must be secured and encrypted (e.g., using BCrypt for passwords) before being saved to the database. Never log sensitive information into system log files.
- **Authentication & Authorization:** 
  - Use JWT (JSON Web Tokens) for all login sessions and API communication.
  - Strict Role-Based Access Control (Learner, Trainer, Lead, Admin) at the Controller level using annotations (e.g., `@PreAuthorize`).
- **Security Rules:** 
  - Prevent SQL Injection: Only use Parameterized Queries (Spring Data JPA handles this automatically), absolutely no manual SQL string concatenation.
  - Prevent XSS/CSRF: Sanitize input/output across the entire system and ensure standard Spring Security configurations.

## 7. Autonomy Boundary (Limits of AI Authority)
- **Do not arbitrarily change the Database Schema:** Any changes to Tables, Columns, Data Types, or dropping tables must be confirmed by a Developer. AI is only allowed to generate migration scripts for user review.
- **Do not arbitrarily expose environment data:** AI must not insert real credentials (real DB passwords, real API keys) into the code. Always use Environment variables or provide placeholders.
- **Do not break the original architecture:** If a system error occurs, AI must not arbitrarily delete or modify the entire original configuration files (e.g., `build.gradle`, `pubspec.yaml`, `application.yml`) without a specific request. Must ask for user opinion before performing destructive actions.

## 8. Git Conventions & Workflow
- **Branching Strategy:** Apply a simplified Git Flow model:
  - `main` / `master`: Contains approved code (Production ready).
  - `dev`: Main development branch.
  - `feature/feature-name`: Branch for developing new features.
  - `bugfix/bug-name`: Branch for fixing bugs.
- **Commit Messages:** Adhere to Conventional Commits to easily track progress:
  - `feat: [description]` (add a feature)
  - `fix: [description]` (fix a bug)
  - `docs: [description]` (update documentation)
  - `refactor: [description]` (restructure code)
- **Pull Request (PR):** All generated code should be pushed to a separate branch, not automatically committed directly to the `main` or `dev` branch.

## 9. Testing Requirements
- **Frontend:** Write Unit Tests and Widget Tests for important components and features.
- **Backend:** Mandatory Unit Tests using JUnit 5 and Mockito. Integrate Testcontainers for Integration Tests and database checking.

## 10. AI Prompting Workflow
When a Developer assigns a task to AI, Context must be provided in the following standard format:

```text
Role: You are a Senior Fullstack Developer (Flutter & Spring Boot).
Task: Based on [frontend_spec.md / backend_spec.md / CONSTITUTION.md], please code the [Feature Name] feature.
Constraints:
- Strictly adhere to the CONSTITUTION.md file (e.g., do not use the color Blue, use N-Tier architecture, separate DTOs).
- Include Unit Tests and ensure clean source code.
```
