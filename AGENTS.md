# HanGo Project: AI Agents Coordination Protocol

This document serves as the master orchestration protocol (Sơ đồ tổ chức & Giao thức điều phối) for all autonomous AI Agents working on the HanGo EdTech platform. It enforces strict boundaries, workflows, and quality gates to ensure seamless Multi-Agent collaboration and human-in-the-loop safety.

## 1. AI Team Composition & Capabilities (Sơ đồ nhân sự AI)

The HanGo virtual development team consists of three specialized AI Agents. Each agent is strictly confined to its specific domain and configuration.

| Agent Role | Domain Directory | Core Tech Stack | Configuration Profile |
| :--- | :--- | :--- | :--- |
| **Backend Agent** | `/hango-backend/` | Java 21, Spring Boot, Spring Data JPA, MySQL | [`/agents/backend.md`](agents/backend.md) |
| **Frontend Agent** | `/hango-frontend/` | Flutter, Dart `^3.12.0`, Dio, Clean Architecture | [`/agents/frontend.md`](agents/frontend.md) |
| **QA Agent** | Global (Test suites) | JUnit/Mockito (Backend), `flutter_test` (Frontend) | [`/agents/qa.md`](agents/qa.md) |

> **Constraint:** An Agent MUST NOT modify files outside its assigned `Domain Directory` unless explicitly coordinating a full-stack integration under Human supervision.

## 2. Multi-Agent Collaboration Workflow & Hand-off Protocol (Giao thức phối hợp)

To implement any of the 14 features defined in `/doc/specs/`, Agents must execute the following **Mockup-Driven (Frontend-First)** workflow. This ensures UI can be built and reviewed rapidly based on Figma designs before locking down the Backend.

1. **Human Trigger:** Human assigns a specific screen/feature, provides a Figma mockup link or image, and specifies the Agent role.
2. **Phase 1 - Frontend UI & Mock Data (Frontend Agent):**
   - Reads the Spec and studies the Figma design.
   - Builds the UI components pixel-perfectly in Flutter.
   - Implements repositories returning **Mock Data (Fake JSON)** to ensure the UI is fully interactive without a real API.
   - *Hand-off:* Frontend Agent updates `/TODO.md` marking the UI and Mock Data as `Done`.
3. **Phase 2 - Backend Execution & API Design (Backend Agent):**
   - Analyzes the Mock Data JSON structure created by the Frontend Agent and reads the Spec.
   - Designs Database Schema & Entities to support this data structure.
   - Builds API Contracts (DTOs & Controllers) and implements Service logic in Spring Boot.
   - *Hand-off:* Backend Agent updates `/TODO.md` marking API endpoints as `Done`.
4. **Phase 3 - Integration (Frontend Agent):**
   - Replaces the Mock Repositories with real `dio` API calls connecting to the Backend endpoints.
   - *Hand-off:* Frontend Agent marks Integration as `Done` in `/TODO.md`.
5. **Phase 4 - Quality Assurance (QA Agent):**
   - Reads the Spec's Acceptance Criteria and Edge Cases.
   - Generates and executes Unit/Integration/Widget tests for both Backend and Frontend.

## 3. Global Definition of Done - DoD (Tiêu chuẩn hoàn thành chung)

An AI Agent is **NOT** allowed to check off `[x] Done` in `/TODO.md` unless the following Validation Gates are passed:

- [ ] **Compilation:** Code compiles with exactly `0` errors. (Dart analysis 0 issues, Maven build success).
- [ ] **Linting:** Code passes all linting rules (`flutter_lints` for FE, standard Java conventions for BE).
- [ ] **Test Coverage:** All newly generated logic must be covered by Tests (Backend Unit Test coverage >= 80%). Tests must execute and `PASS 100%`.
- [ ] **Security:** No raw secrets/API keys are hardcoded. JWT validation and RBAC `@PreAuthorize` are enforced on all new APIs.
- [ ] **Version Control:** If committing, the commit message strictly follows Conventional Commits (e.g., `feat(auth): add login endpoint`).

## 4. Context Initialization Rules (Quy tắc nạp ngữ cảnh)

When an Agent starts a new session or takes over a task, it **MUST** forcibly load its memory context in the following exact sequence:

1. **Read Security Constitution:** [`/doc/CONSTITUTION.md`](doc/CONSTITUTION.md) (To internalize security rules and constraints).
2. **Read System Architecture:** [`/doc/ARCHITECTURE.md`](doc/ARCHITECTURE.md) (To understand the Clean Architecture and N-Tier layers).
3. **Read Specific Feature Spec:** [`/doc/specs/[id]-[feature].md`](doc/specs/) (To understand the exact Business Context, Acceptance Criteria, and Edge Cases).
4. **Read Current State:** [`/TODO.md`](TODO.md) (To identify what is `In Progress` and what remains to be done).

## 5. Escalation Boundaries (Lằn ranh đỏ gọi Con người)

AI Agents operate autonomously but must strictly obey the **Human-in-the-loop** escalation protocol. An Agent **MUST STOP**, revert to the last stable state, and log the issue in the `🛑 Escalated to Human` section of `/TODO.md` if:

- **The 3-Attempt Rule:** The Agent fails to fix a compilation error, failing test, or bug after 3 consecutive attempts.
- **Dependency Modification:** The Agent realizes a new, unapproved third-party library (Pub package/Maven dependency) needs to be installed.
- **Architectural Conflict:** The Agent detects a contradiction between the `/doc/specs/` document and the actual Database Schema or `/doc/ARCHITECTURE.md`.
- **Destructive Action:** The task requires dropping a Database table, force-deleting core modules, or rewriting global configurations (`pom.xml`, `pubspec.yaml`).
