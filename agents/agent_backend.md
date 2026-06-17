# HanGo Backend & Database Agent Guidelines

This document defines the strict rules that AI Coding Agents must adhere to when writing Backend code (Java/Spring Boot) and designing the Database system (MySQL) for the HanGo project.

## 1. Technologies & Platforms
- **Language:** Java 21.
- **Framework:** Spring Boot 3.x.
- **Database:** MySQL.
- **Supporting Tools:** Lombok, MapStruct.

## 2. Architecture & Design Patterns
- **N-Tier Architecture:**
  - Separate processing flow according to standard: `Controller` -> `Service` -> `Repository`.
  - Absolutely do not write Business Logic or interact directly with Database/Repository from the `Controller`.
- **Entities & DTOs:**
  - **FORBIDDEN** to directly return `@Entity` objects from `Controller` to Client APIs.
  - Independent Request DTO and Response DTO classes must be built.
  - Use the `MapStruct` library to create Mapper interfaces for automatic data mapping between Entities and DTOs.

## 3. Coding Standards
- **Boilerplate Optimization (Lombok):** Always use annotations such as `@Data`, `@Builder`, `@NoArgsConstructor`, `@AllArgsConstructor` in Model/Entity and DTO classes.
- **Data Validation:** 
  - Mandatory validation declarations in Request DTO classes using annotations (`@Valid`, `@NotBlank`, `@NotNull`, `@Size`...). 
  - There must be a common `GlobalExceptionHandler` (using `@ControllerAdvice`) to catch validation errors and return standard JSON formats.
- **Security & Authorization:**
  - Authentication via JWT.
  - Apply strict role-based access control via `@PreAuthorize` on API Endpoints corresponding to Roles (Learner, Trainer, Lead, Admin).
  - Do not manually concatenate SQL query strings to prevent SQL Injection (Use Spring Data JPA Repository).

## 4. Database Rules (MySQL)
- **Naming Conventions:**
  - In MySQL (Tables, Columns): Mandatory use of `snake_case` (Example: `course_id`, `created_at`).
  - In Java Entities (Properties): Mandatory use of `camelCase` (Example: `courseId`, `createdAt`).
- **Relationships:**
  - Clearly declare `@ManyToOne`, `@OneToMany`.
  - To optimize queries and prevent N+1 Query issues, always set the `fetch = FetchType.LAZY` attribute as the default for all relationships.

## 5. Testing Requirements
- Must generate Unit Tests for the Service Layer using the JUnit 5 and Mockito frameworks.
- Prioritize configuring and providing Integration Test scripts using Testcontainers instead of mocking the entire Database.
