# Feature Specification: FT-05 - Question Bank Management

## 1. Business Context
The Assessment system requires a flexible and centralized question repository. The Question Bank Management feature allows Trainers to create, edit, and categorize questions (Multiple Choice, Fill in the Blank, True/False) by Category/Skill. Specifically, it provides the ability to bulk Import/Export via Excel files, saving significant time compared to manual data entry.

## 2. Acceptance Criteria

**Frontend (Flutter):**
- [ ] Question list UI with filters by Course, Question Type, and Difficulty Level.
- [ ] Dynamic question creation form supporting Question Type selection and rendering corresponding input fields (e.g., Multiple Choice has buttons to add A, B, C, D options).
- [ ] "Import from Excel" button opening a File Picker, selecting `.xlsx` files, and sending them via API.
- [ ] Display notifications for the total number of successfully imported questions or formatting errors.

**Backend (Spring Boot):**
- [ ] API `POST /api/v1/questions` to create a single question along with a list of `answers`.
- [ ] API `POST /api/v1/questions/import` to handle `MultipartFile`. Read Excel files using Apache POI.
- [ ] Validate Excel data: Missing correct answers, invalid data types.
- [ ] Manage Transactions when saving lists of `Question` and `Answer` to prevent relational data loss.

## 3. Technical Constraints
- **Backend:** The Apache POI library (or equivalent) must be configured securely to prevent XXE (XML External Entity) vulnerabilities when parsing `.xlsx` files.
- **Database:** The `answers` table strictly depends on `questions` via the `question_id` Foreign Key configured with `ON DELETE CASCADE`.
- **Test:** Requires Unit Tests using Mockito for Excel parsing logic (mocking valid standard files and files missing columns to test Exceptions).

## 4. Edge Cases
- **Oversized Excel File:** Backend limits Excel files to < 10MB and a maximum of 1000 rows. Exceeding this throws a `PayloadTooLargeException`.
- **Question without a Correct Answer:** Backend validation (DTO/Entity lifecycle) mandates that the `answers` array must have at least one object with `is_correct = true`.
- **Deleting a Question Currently in an Exam:** Block hard deletes. If a question already exists in `exam_questions`, only allow changing the status to `status = INACTIVE` (Soft delete) so as not to break historical exam data.

## 5. Non-functional Requirements
- **Performance:** Importing an Excel file with 1000 questions must complete in `< 3000ms`. Consider using Batch Insert in Hibernate.
- **Integrity:** When importing, if 999 questions are valid but 1 row has a formatting error -> Either fail the entire file or skip the bad row and report it (Default design: Rollback entirely so the Trainer can fix the file).
- **Logging:** Log the number of imported questions along with the `trainer_id`.
