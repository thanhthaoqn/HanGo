# Feature Specification: FE-07 — Question Bank Management

> Ref: [HanGo_Documentation.md](../HanGo_Documentation.md) §7.7 (QB)

## 1. Business Context
The Assessment system requires a flexible and centralized question repository, owned by each Trainer, reused by both Quiz (in Course content) and Exam. v1 supports exactly **one QuestionType: SingleChoice** (4 options A/B/C/D, exactly one correct answer) — no Multiple Choice / Fill-in-blank / True-False. Each Question has exactly **one SkillType** (BR-QB-01) and a Visibility (Public/Private). QuestionGroup lets several questions share a passage (SharedContent), used mainly for Exam. It also provides bulk Import/Export via Excel files, saving time versus manual entry.

## 2. Acceptance Criteria

**Frontend (Flutter):**
- [ ] Question list UI with filters by **SkillType, Difficulty, and Visibility**.
- [ ] Question creation form: Content, Explanation, exactly 4 options (A/B/C/D) with single correct-answer selection, SkillType, Difficulty, Visibility.
- [ ] QuestionGroup editor for shared-passage questions.
- [ ] AI-assisted "Generate Question & Explanation" draft button (Trainer must review/edit before saving — BR-AI-01).
- [ ] "Import from Excel" button opening a File Picker, selecting `.xlsx` files, and sending them via API.
- [ ] Display notifications for the total number of successfully imported questions or formatting errors.

**Backend (Spring Boot):**
- [ ] API `POST /api/v1/questions` to create a single question along with its 4 `answers` (options).
- [ ] API `POST /api/v1/questions/import` to handle `MultipartFile`. Read Excel files using Apache POI.
- [ ] Validate Excel data: exactly one correct answer per question, exactly one SkillType, invalid data types.
- [ ] Manage Transactions when saving lists of `Question` and `Answer` to prevent relational data loss.

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

