# Feature Specification: FT-05 - Question Bank Management

## 1. Business Context
The Assessment system requires a flexible and centralized question repository. The Question Bank Management feature allows Trainers to create, edit, and categorize questions (Multiple Choice Single Choice) by Category/Skill (SkillType). It provides support for QuestionGroups (reading comprehension passages) and bulk Excel imports, as well as AI-powered draft generation for questions and explanations.

## 2. Acceptance Criteria

**Frontend (Flutter):**
- [ ] Question list UI with filters by Course, SkillType, and Difficulty Level.
- [ ] Question editor form supporting option input fields (A/B/C/D) and correct answer selection.
- [ ] QuestionGroup editor interface allowing Trainers to write comprehension passage contexts (context text) and add nested sub-questions.
- [ ] Integration with AI helpers: "AI Generate Question" and "AI Generate Explanation" draft buttons.
- [ ] "Import from Excel" button opening a File Picker for `.xlsx` template uploads.

**Backend (Spring Boot):**
- [ ] API `POST /api/v1/trainer/questions` to create single questions.
- [ ] API `POST /api/v1/trainer/questions/group` to create passage-based QuestionGroups.
- [ ] API `/api/v1/trainer/questions/select` to retrieve or randomise section questions for quizzes.
- [ ] AI prompt integrations to draft question bodies and explanations based on category and SkillType.
- [ ] API `POST /api/v1/questions/import` to parse bulk upload Excel files (.xlsx) using Apache POI.

## 3. Technical Constraints
- **Database Schema:** Questions are mapped to the `questions` table and options/choices are stored in the `question_options` table (fields: `id`, `question_id`, `option_text`, `is_correct`), using Foreign Keys with `ON DELETE CASCADE`.
- **Passage-Comprehension Groups:** QuestionGroups are stored in the `question_groups` table (fields: `id`, `title`, `group_type_param_id`, `context_text`), and child questions reference this via the `group_id` column.
- **AI Integration Guardrails:** AI-generated content is strictly considered a **draft**. The Trainer must manually review, edit, and save the content before it goes into the repository.

## 4. Edge Cases
- **Option without a Correct Option:** Backend validation mandates that the options list has at least one option with `is_correct = true`.
- **Deleting a Question Currently in use:** Prevent hard deletions if the question is linked in active `lesson_quizzes` or exams. Allow changing the question status to `INACTIVE` (Soft delete) to maintain integrity.

## 5. Non-functional Requirements
- **Performance:** Question generation and search filtering must respond in `< 500ms`.
- **Security:** Guard against XML External Entity (XXE) vulnerabilities in Apache POI when importing Excel files.

