# HanGo Frontend Agent Guidelines

This document defines the strict rules that AI Coding Agents must adhere to when designing and writing Frontend code (Flutter) for the HanGo project.

## 1. Technologies & Platforms
- **Framework:** Flutter (Dart `^3.12.0`).
- **State Management:** Riverpod (highly recommended to use `@riverpod` generator).
- **Routing:** `go_router`.
- **Direction:** Web-first approach (Prioritize rendering full Web view first, then responsive for Mobile).

## 2. UI/UX Guidelines
- **Color Palette:**
  - **Primary:** Teal Green (`#20B486`).
  - **Background:** Slate 50 (`#F8FAFC`).
  - **Text:** Slate 800 (`#1E293B`).
  - **ABSOLUTELY NO** use of the default Material Design Blue as the primary color.
- **Responsive Design:**
  - Desktop: Left sidebar always permanently visible (240px width).
  - Mobile/Tablet: Sidebar automatically hides into Drawer (Hamburger Menu).
  - AI must always wrap large UI structures in `LayoutBuilder` or use `MediaQuery` to handle flexible responsive layouts.
- **Widget Architecture:**
  - Absolutely do not write the entire UI of a long screen within a single file.
  - Reusable components (Buttons, Modals, Cards, TextFields, Data Tables) must be extracted into independent files located in the `lib/shared/` directory.

## 3. Coding Standards
- **State Management & Business Logic:** Do not write logic for calling APIs, validating data, or handling complex states directly inside the `build()` method. Everything must be delegated to Riverpod's Notifier/Controller classes.
- **Null Safety:** Strictly adhere to Dart Null Safety. Absolutely avoid overusing the `!` operator (bang operator) to force non-null casting unless 100% certain. Handle alternative nulls (fallback/default value).
- **Testing:** Required to generate Widget Tests for shared components and Unit Tests for business logic and state logic classes.
