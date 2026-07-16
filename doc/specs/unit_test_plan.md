# HanGo Unit Test Specification & Design Document

**Project Name:** Smart Language Self-Study Platform (HanGo)
**Project Code:** HANGO
**Test Environment Setup Description:**
1. **Backend:** Java 21, Spring Boot 3.x, JUnit 5, Mockito 5.x
2. **Frontend:** Dart ^3.12.0, Flutter SDK, flutter_test (Widget & Unit)
3. **IDE:** Visual Studio Code / IntelliJ IDEA 2024

> **Nguyên tắc:** tài liệu này là **kế hoạch sống**, không phải báo cáo kết quả. Method List (§1) được đối chiếu trực tiếp với `hango-backend/src/main/java/...` tại thời điểm cập nhật gần nhất (2026-07-13) — không suy từ mô tả trong `HanGo_Documentation.md`/`doc/specs/0X-*.md`, vì dự án thay đổi nhanh hơn tài liệu (xem [`TESTING.md`](../TESTING.md) §0). Mọi test case trong §2/§3 mặc định **Untested** cho tới khi thật sự được viết và chạy — không tự đánh dấu Passed.

---

## 1. Method List (grounded in current source code)

Trạng thái: **Implemented** = class/method tồn tại thật trong code · **Planned** = module chưa có Service backend, tên method là đề xuất theo convention hiện có (camelCase, không hậu tố `Async` — khác quy ước `.NET` của dự án tham khảo) · **Verify** = tồn tại nhưng hành vi/role-gating cần xác nhận lại khi viết test.

| # | Module | Class | Method Name | Signature (tham số → trả về) | Status |
|---|---|---|---|---|---|
| 1 | AUTH | AuthService | `authenticateUser` | `LoginRequest` → `LoginResponse` | Implemented |
| 2 | AUTH | AuthService | `registerUser` | `RegisterRequest` → `UserResponse` | Implemented |
| 3 | AUTH | AuthService | `googleLogin` | `GoogleLoginRequest` → `LoginResponse` | Implemented |
| 4 | AUTH | AuthService | `forgotPassword` | `ForgotPasswordRequest` → `void` | Implemented |
| 5 | AUTH | AuthService | `verifyOtp` | `VerifyOtpRequest` → `void` | Implemented |
| 6 | AUTH | AuthService | `resetPassword` | `ResetPasswordRequest` → `void` | Implemented |
| 7 | AUTH | AuthService | `verifyAccount` | `email` → `void` | Implemented |
| 8 | AUTH | AuthService | `resendVerificationEmail` | `email` → `void` | Implemented |
| 9 | AUTH | AuthService | `isAccountVerified` | `email` → `boolean` | Implemented |
| 10 | AUTH | UserDetailsServiceImpl | `loadUserByUsername` | `email` → `UserDetails` | Implemented |
| 10b | AUTH | — | `refreshToken` / `logout` | — | **Gap, not Planned-and-fine**: `HanGo_Documentation.md` §5 promises "access token + refresh token", but only a single JWT is issued anywhere in the codebase — no refresh/revoke endpoint exists. Raise with dev team before assuming this is just unbuilt-as-designed. |
| 11 | PROF | AuthService | `getUserProfile` | `email` → `UserResponse` | Implemented *(no dedicated ProfileService — lives in AuthService)* |
| 12 | PROF | AuthService | `updateProfile` | `email, ProfileUpdateRequest` → `UserResponse` | Implemented |
| 13 | PROF | AuthService | `changePassword` | `email, ChangePasswordRequest` → `void` | Implemented |
| 14 | PROF | AuthService | `updateAvatar` | `email, MultipartFile` → `UserResponse` | Implemented |
| 15 | PROF | AuthService | `getUserById` | `id` → `UserResponse` | Implemented |
| 16 | PROF | — | Learning Profile aggregation (FR-PROF-04) | — | Planned *(no endpoint found)* |
| 17 | PROF | — | Trainer public/brand profile page (📌 FR-PROF-05) | — | Planned |
| 18 | RBAC | AdminController | `getDashboardStats` | — → stats map | Implemented *(no dedicated Service — logic inline in Controller; test via MockMvc, not pure unit)* |
| 19 | RBAC | AdminController | `getUsers` | filters/paging → page of users | Implemented |
| 20 | RBAC | AdminController | `getUserDetail` | `id` → `UserResponse` | Implemented (delegates `AuthService.getUserById`) |
| 21 | RBAC | AdminController / AuthService | `createUserByAdmin` | `RegisterRequest` → `UserResponse` | Implemented |
| 22 | RBAC | AdminController | `updateUserByAdmin` | `id, AdminUserUpdateRequest` → `UserResponse` | Implemented |
| 23 | RBAC | AdminController | `updateUserStatus` | `id, status` → success map | Implemented — **no self-lock guard, no status whitelist** (see §3.3) |
| 24 | RBAC | — | AI Usage Logging (`@Aspect`) | — | Planned *(no `@Aspect` class exists at all in the codebase)* |
| 25 | RBAC | — | Audit Log | — | Planned |
| 25b | RBAC | — | `getPermissions` / `updatePermissions` | — | **Open item, not a firm Planned target** — `HanGo_Documentation.md` FR-RBAC-05 itself marks this 📌 (undecided: static or dynamic permissions). Confirm scope with team before writing acceptance UTCs. |
| 26 | TRN | — | `submitApplication` | — | Planned *(no `TrainerOnboardingService`; `TrainerDashboardService` is post-approval course/exam authoring, a different concern)* |
| 26b | TRN | — | `uploadDocuments` | — | Planned *(likely folded into `submitApplication`'s multipart request rather than a separate method — verify when built)* |
| 27 | TRN | — | `reviewApplication` | — | Planned |
| 28 | TRN | — | `activateTrainer` | — | Planned |
| 29 | CRS | CourseService | `getCourses` | `search, filterType, difficulty` → `List<CourseSummaryDTO>` | Implemented |
| 30 | CRS | CourseService | `getCourseDetail` | `id, currentUserId` → `CourseDetailDTO` | Implemented |
| 31 | CRS | TrainerDashboardService | `getTrainerCourses` | `email, status, search, sortBy, timePeriod` → `TrainerCoursesResponseDTO` | Implemented |
| 32 | CRS | TrainerDashboardService | `createTrainerCourse` | `email, TrainerCreateCourseRequestDTO` → `void` | Implemented |
| 33 | CRS | TrainerDashboardService | `updateTrainerCourse` | `id, email, TrainerCreateCourseRequestDTO` → `void` | Implemented — **Verify**: no distinct `course_versions`/clone-on-edit-published logic found; confirm whether editing a Published course actually creates a new version (BR-CRS-03/§9.7) or overwrites in place |
| 34 | CRS | TrainerDashboardService | `getTrainerDashboardSummary` | `email` → `TrainerDashboardSummaryDTO` | Implemented |
| 35 | CRS | — | Course Manager review/approve/reject/publish workflow | — | Planned *(no review-queue endpoint found in inventory)* |
| 36 | CRS | — | Price-tier suggestion (FR-CRS-06) | — | Planned |
| 37 | CNT | LessonService | `getLessonDetail` | `lessonId, userId` → `LessonDetailDTO` | Implemented |
| 38 | CNT | LessonService | `getQuizAttempts` | `lessonId, userId` → `List<LessonQuizAttemptDTO>` | Implemented |
| 39 | CNT | LessonService | `saveQuizAttempt` | `lessonId, userId, LessonQuizAttemptRequestDTO` → `LessonQuizAttemptDTO` | Implemented |
| 40 | CNT | TrainerDashboardService | Section CRUD | inline inside `updateTrainerCourse` | Implemented *(not a standalone method — no `SectionService`)* |
| 41 | CNT | — | `importSyllabusFromExcel` | — | Planned *(no Excel/Apache POI import found)* |
| 42 | QB | TrainerQuestionService | `getTrainerQuestions` | `email, type, search, sortBy` → `List<QuestionDTO>` | Implemented |
| 43 | QB | TrainerQuestionService | `createQuestionBankGroup` | `email, CreateGroupQuestionRequestDTO` → `Map<String,Object>` | Implemented |
| 44 | QB | TrainerQuestionService | `getQuestionDetail` | `email, id, isGroup` → `CreateGroupQuestionRequestDTO` | Implemented |
| 45 | QB | TrainerQuestionService | `updateQuestionBankGroup` | `email, id, isGroup, request` → `void` | Implemented |
| 46 | QB | TrainerQuestionService | `updateQuestionStatus` | `email, questionId, status, isGroup` → `void` | Implemented |
| 47 | QB | TrainerQuestionAIService | `generatePayload` | `CreateTrainerQuestionAIRequestDTO` → `CreateTrainerQuestionAIResponseDTO` | Implemented |
| 48 | EXM | ExamService | `getAllExams` | `status` → `List<ExamResponseDTO>` | Implemented |
| 49 | EXM | ExamService | `getExamAttempts` | `examId, userId` → `List<ExamAttemptResponseDTO>` | Implemented |
| 50 | EXM | ExamService | `getMyExamAttempts` | `userId` → `List<ExamAttemptResponseDTO>` | Implemented |
| 51 | EXM | ExamService | `saveExamAttempt` | `examId, userId, ExamAttemptRequestDTO` → `ExamAttemptResponseDTO` | Implemented — **Verify**: `request.getScore()` is trusted as client input, not recomputed server-side from correct answers (see §3.4) |
| 52 | EXM | ExamResultAnalyzerService | `analyzeLatestExamAttempt` | `ExamAttempt` → `ExamResultAnalysisDTO` | Implemented |
| 53 | EXM | ExamResultAnalyzerService | `analyzeLearnerAttempts` | `learnerId, List<ExamAttempt>` → `ExamResultAnalysisDTO` | Implemented |
| 54 | EXM | TrainerDashboardService | `createTrainerExam` / `saveExamQuestions` / `getExamQuestions` / `updateExamStatus` | various | Implemented — **Verify**: role-gating for Course Manager approve/self-publish (FR-EXM-03) inside `updateExamStatus`; also verify whether "publish" is just a status value passed to `updateExamStatus` or needs its own endpoint |
| 54b | EXM | — | Learner-facing "get full exam (with questions) to start attempt" | — | **Gap** — `ExamService` has no `getExamDetail`-equivalent found; `TrainerDashboardService.getExamQuestions` is Trainer-scoped only. Confirm how the Learner's "Take Exam" screen actually fetches questions before assuming a method exists. |
| 55 | AI | AIAssistantService | `sendMessage` | `learnerId, SendMessageRequest` → `SendMessageResponse` | Implemented |
| 56 | AI | AIAssistantService | `getConversationHistory` | `learnerId` → `List<AIConversation>` | Implemented |
| 57 | AI | ScopeGuardrailService | `checkScope` | `Lesson, userMessage[, practiceQuestions]` → `ScopeCheckResult` | Implemented |
| 58 | AI | AIPromptBuilder | `buildSystemPrompt` / `buildOutOfScopeFallback` | `Lesson[, questions]` → `String` | Implemented |
| 59 | AI | LessonEmbeddingService | `getOrComputeEmbedding` / `recomputeEmbedding` | `Lesson` → `List<Double>` | Implemented |
| 60 | AI | GeminiClientService | `generateChatResponse` / `generateEmbedding` / `checkAvailability` | — | Implemented *(thin wrapper over external API — prefer mocking at this boundary)* |
| 60b | AI | — | `buildContext` / `retrieveRelevantChunks` | — | **Not found as public methods** — if RAG-style retrieval exists, it's likely private/inline inside `AIAssistantService.sendMessage` or `ScopeGuardrailService`. Read `sendMessage`'s body before writing a unit test that mocks these as separate collaborators. |
| 61 | LRN | LessonService | `completeLesson` | `lessonId, userId, isCompleted` → `void` | Implemented |
| 61b | LRN | — | `continueLearning` / `getLearningHistory` / `getLearningProgress` | — | **Not found as standalone methods** — FR-LRN-04/05/07 promise this behavior, but progress % etc. is likely computed inline inside `getCourseDetail`/`getTrainerCourses` rather than a dedicated method. Verify before assuming a unit exists to test in isolation. |
| 62 | LRN | CourseService | `enrollCourse` / `unenrollCourse` | `courseId, userId` → `void` | Implemented |
| 63 | LRN | CourseRatingService | `getCourseReviews` / `addCourseReview` / `deleteCourseReview` | — | Implemented |
| 64 | LRN | LearningPathwayService | `generatePathway` | `studentId, PathwayGenerateRequestDTO` → `LearningPathwayResponseDTO` | Implemented |
| 65 | LRN | LearningPathwayService | `reroutePathway` / `getMyPathway` / `getPathwayById` / `chatWithMentor` / `applySchedule` / `getScheduleStatus` | — | Implemented |
| 66 | LRN | PathwayGoalMergeService | `mergePreview` / `mergeConfirm` | — | Implemented |
| 67 | LRN | PathwayMutationService | `applyFastTrackSkip` / `applyDetourInsertion` | — | Implemented |
| 68 | LRN | PathwayProgressSnapshotService | `getProgressSnapshot` | `pathwayId, learnerId` → `ProgressSnapshotDTO` | Implemented |
| 69 | LRN | PathwayReroutePolicyService | `evaluate` | `ProgressSnapshotDTO` → `PolicyDecision` | Implemented |
| 70 | LRN | PathwayTimeboxingScheduler | `schedule` | (static) → `List<NodeSchedule>` | Implemented *(plain static utility, not a Spring bean — easiest pure-unit target in the whole codebase)* |
| 71 | REC | ExamCourseRecommendationAIService | `recommendCoursesAI` | `examAttemptId` → `ExamCourseRecommendationAIResponseDTO` | Implemented |
| 72 | REC | ExamResultAnalyzerService | (shared with EXM — feeds Weakness Analysis) | — | Implemented |
| 73 | REC | LearningPathwayService | `generatePathway` (shared with LRN — AI Learning Pathway, FR-REC-04) | — | Implemented |
| 73b | REC | — | `recommendCoursesRule` (deterministic, non-AI rule-based match) | — | **Gap** — `HanGo_Documentation.md` separates FR-REC-02 (rule-based: weak SkillType → tagged Course, no AI) from FR-REC-03 (AI Recommendation). Only the AI version (`recommendCoursesAI`) was found; a pure rule-based fallback (e.g. for when AI is unavailable) doesn't appear to exist yet — confirm with dev team. |
| 74 | PAY | — | `createOrder` | — | Planned *(no `PaymentService`, no `Order`/`RevenueRecord`/`MonthlyStatement` entity found anywhere)* |
| 75 | PAY | — | `processVnpayIpn` | — | Planned |
| 76 | PAY | — | `generateMonthlyStatements` | — | Planned |
| 77 | PAY | — | `confirmMonthlyStatement` | — | Planned |
| 78 | PAY | — | `payStatement` | — | Planned |
| 79 | CMT | CommentService | `getCommentsByLesson` | `lessonId, currentUserId` → `List<CommentDTO>` | Implemented |
| 80 | CMT | CommentService | `addComment` | `lessonId, userId, CommentRequestDTO` → `CommentDTO` | Implemented |
| 81 | CMT | CommentService | `updateComment` | `commentId, userId, CommentRequestDTO` → `CommentDTO` | Implemented |
| 82 | CMT | CommentService | `deleteComment` | `commentId, userId` → `void` | Implemented — **Verify**: confirm this enforces "own comment only"; Admin moderation (FR-CMT-04, hide/delete *any* comment) not found as a distinct method |
| 83 | CMT | CommentService | `likeComment` / `unlikeComment` | `commentId, userId` → `CommentDTO` | Implemented |
| 84 | NTF | — | `publishNotification` | — | Planned *(no `NotificationService`, no WebSocket/STOMP config found)* |
| 85 | NTF | — | `getNotifications` / `getUnreadCount` / `markAsRead` / `markAllAsRead` | — | Planned |

> **Đề xuất bị loại khi rà lại với code (từ bản mở rộng của tester ngày 2026-07-13):** `register`→dùng `registerUser` (tên thật); `refreshToken`/`logout`→xem hàng 10b (gap, không phải method có sẵn); `assignRole`/`updateRole`→dư thừa, `updateUserByAdmin` đã nhận field `role`, HanGo không có Role CRUD động; `searchCourses`/`filterCourses`→là tham số của `getCourses`, không phải method riêng; `createQuestion`/`updateQuestion`/`deleteQuestion`→tên sai, dùng `createQuestionBankGroup`/`updateQuestionBankGroup`/`updateQuestionStatus`; `generateQuestionByAI`+`generateExplanationByAI`→gộp thành 1 method thật `generatePayload` (sinh câu hỏi+giải thích cùng lúc); `analyzeWeakness`→trùng với hàng 52 (`analyzeLatestExamAttempt`); `generateLearningPathwayRecommendation`→trùng với hàng 64 (`generatePathway`). Các đề xuất còn lại đã được thêm vào bảng trên dưới dạng hàng `Xb` kèm trạng thái Gap/Verify/Planned phù hợp.

---

## 2. Test Priority Plan (~100 UTC target)

Ưu tiên theo [`agent_qa.md`](agent_qa.md) §3 (🔴 Critical / 🟡 Important / 🟢 Normal). Mỗi module được chọn **method đại diện** để lên UTC ngay; các method còn lại trong §1 sẽ được lên UTC ở đợt sau theo cùng nguyên tắc. Trạng thái Passed/Failed/Untested phản ánh **thực tế chưa có test nào được chạy** — toàn bộ để Untested cho tới khi tester thực thi.

| # | Module | Priority | Method | Impl. Status | Passed | Failed | Untested | N | A | B | Planned Total |
|---|---|:--:|---|---|:--:|:--:|:--:|:--:|:--:|:--:|:--:|
| 1 | AUTH | 🔴 | `authenticateUser` | **Done** (2026-07-14) | 6 | 0 | 0 | 1 | 3 | 2 | 6 |
| 2 | AUTH | 🔴 | `googleLogin` | **Done, partial** (2026-07-14) | 1 | 0 | 0 | 0 | 1 | 0 | 1 (+1 blocked, see §3.2b) |
| 3 | RBAC | 🔴 | `updateUserStatus` | Implemented (gap found) | 0 | 0 | 10 | 4 | 4 | 2 | 10 |
| 4 | RBAC | 🔴 | `getUsers` | Implemented | 0 | 0 | 5 | 3 | 1 | 1 | 5 |
| 5 | EXM | 🔴 | `saveExamAttempt` | Implemented (risk found) | 0 | 0 | 10 | 4 | 4 | 2 | 10 |
| 6 | EXM | 🔴 | `analyzeLatestExamAttempt` | Implemented | 0 | 0 | 5 | 2 | 2 | 1 | 5 |
| 7 | PAY | 🔴 | `processVnpayIpn` | **Planned** | 0 | 0 | 10 | 3 | 5 | 2 | 10 |
| 8 | PAY | 🔴 | `generateMonthlyStatements` | **Planned** | 0 | 0 | 5 | 2 | 2 | 1 | 5 |
| 9 | CRS | 🟡 | `updateTrainerCourse` | Implemented | 0 | 0 | 6 | 3 | 2 | 1 | 6 |
| 10 | CNT | 🟡 | `saveQuizAttempt` | Implemented | 0 | 0 | 6 | 3 | 2 | 1 | 6 |
| 11 | LRN | 🟡 | `completeLesson` | Implemented | 0 | 0 | 6 | 3 | 2 | 1 | 6 |
| 12 | REC | 🟡 | `recommendCoursesAI` | Implemented | 0 | 0 | 6 | 3 | 2 | 1 | 6 |
| 13 | PROF | 🟢 | `updateProfile` | Implemented | 0 | 0 | 3 | 2 | 1 | 0 | 3 |
| 14 | TRN | 🟢 | `submitApplication` | **Planned** | 0 | 0 | 3 | 2 | 1 | 0 | 3 |
| 15 | QB | 🟢 | `createQuestionBankGroup` | Implemented | 0 | 0 | 3 | 2 | 1 | 0 | 3 |
| 16 | AI | 🟢 | `checkScope` | Implemented | 0 | 0 | 3 | 1 | 2 | 0 | 3 |
| 17 | CMT | 🟢 | `deleteComment` | Implemented | 0 | 0 | 3 | 1 | 2 | 0 | 3 |
| 18 | NTF | 🟢 | `publishNotification` | **Planned** | 0 | 0 | 3 | 2 | 1 | 0 | 3 |
| | | | | **Sub-total (18 methods)** | **0** | **0** | **102** | **47** | **39** | **16** | **102** |

Ghi chú xếp hạng:
- 🔴 Critical (4 module × 2 method, 10+5 UTC): Auth, RBAC, Exam grading, Payment — đúng theo `agent_qa.md` §3.
- 🟡 Important (6 UTC/module): Course versioning (CRS/CNT gộp theo agent_qa.md), Learning progress (LRN), Recommendation (REC).
- 🟢 Normal (3 UTC/module): các module còn lại (PROF, TRN, QB, AI, CMT, NTF).
- Tất cả method đánh dấu **Planned** vẫn được lên UTC (thiết kế test *trước*, để dùng làm acceptance criteria khi code được viết) — đúng tinh thần "coi dự án đã hoàn thành".
- **2026-07-14:** toàn bộ module AUTHENTICATION (không chỉ 2 method đại diện ở hàng 1-2) đã có test thật — 7 method còn lại của AUTH (`registerUser`, `forgotPassword`, `verifyOtp`, `resetPassword`, `verifyAccount`, `resendVerificationEmail`, `isAccountVerified`, `loadUserByUsername`) được cộng thêm **19 test Passed** ngoài phạm vi 18-method ban đầu — xem §3.2 và §3.2b. Sub-total 102 UTC ở trên **không** đổi vì đây là phần vượt kế hoạch (bonus), không thay thế hàng nào khác.
- **2026-07-14 (tiếp):** module PROFILE — cả 5 method thật (`getUserProfile`, `updateProfile`, `changePassword`, `updateAvatar`, `getUserById`; đều sống trong `AuthService`, không có `ProfileService` riêng) đã có **15 test Passed** trong cùng `AuthServiceTest.java`. `getLearningProfile`/`getTrainerPublicProfile` vẫn Planned (chưa có endpoint).
- **2026-07-14 (fix code production, theo yêu cầu tester):** đã sửa 3 bug tìm thấy khi test, kèm test mới cho từng fix (không đổi hành vi nơi khác):
  1. `AdminController.updateUserStatus` — thêm whitelist status (`ACTIVE`/`INACTIVE`, chặn giá trị khác) + chặn Admin tự đổi status chính mình. Test mới: `AdminControllerTest.java` (4 test).
  2. `AuthService.updateProfile` — reset `isVerified=false` khi user đổi email (trước đây giữ nguyên `true` dù email mới chưa xác minh). Test mới: `updateProfileShouldResetIsVerifiedWhenEmailChanges`.
  3. `AuthService.updateAvatar` — thêm validate file avatar (≤2MB, chỉ jpg/jpeg/png) đúng theo spec `02-profile-management.md`, trước đây không giới hạn gì. Test mới: `updateAvatarShouldRejectFileLargerThan2MB`, `updateAvatarShouldRejectUnsupportedContentType`.
  - Đã xóa `HangoBackendApplicationTests.java` (test giả — nuốt exception, không assert gì, theo xác nhận của tester).
- **2026-07-14 (fix vòng 2, theo yêu cầu tester "fix cả bảng"):**
  - Đã tách `GoogleIdTokenVerifier` thành `@Bean` (`GoogleAuthConfig.java`) → `googleLogin` hết bị chặn, có đủ test happy-path (JIT-provision, reuse account, inactive) — không còn `@Disabled`.
  - Đã xóa role chết `TRAINER_LEAD` khỏi `@PreAuthorize` của `uploadAvatar`.
  - Đã phân biệt HTTP status (404 khi không tìm thấy tài khoản) cho các endpoint không phải bước xác thực: `verifyAccount`, `resendVerification`, `resetPassword`, `uploadAvatar`, `getUserProfile`, `updateProfile`, `changePassword`. **Cố tình giữ nguyên 400 cho `/login` và `/google`** để tránh lộ thông tin tài khoản tồn tại hay không (account enumeration).
  - Đã bổ sung test Controller-layer đầy đủ (happy-path 200 + lỗi) cho toàn bộ endpoint AUTH (`AuthControllerTest.java`, 21 test) và PROFILE (`UserControllerTest.java`, 9 test) — trước đó chỉ có test Service-layer.
  - #1 (refresh token/logout) và #2 (khóa tài khoản sau 5 lần sai) **chưa implement được** — `application.properties.example` có `spring.jpa.hibernate.ddl-auto=validate`, thêm field/bảng mới vào entity mà chưa chạy migration SQL sẽ làm app **crash khi khởi động**. Đã chuẩn bị sẵn SQL migration + kế hoạch code, chờ dev chạy migration trước.
  - Tổng backend hiện tại: `mvnw test` → **108/108 pass, 0 skip**. Riêng AUTH+PROFILE: 81 test (33 Service + 21 Controller cho AUTH; 18 Service + 9 Controller cho PROFILE).
- **2026-07-14 (fix vòng 3 — DTO Validation, theo yêu cầu tester):**
  - Bổ sung 13 test dùng `@WebMvcTest` + MockMvc thật (không phải Mockito unit test thuần) để chạy qua đúng pipeline Spring Bean Validation (`@Valid`) mà unit test Service-layer không chạm tới được: `AuthControllerValidationTest.java` (10 test — `LoginRequest`, `RegisterRequest`, `GoogleLoginRequest`, `ForgotPasswordRequest`, `VerifyOtpRequest`, `ResetPasswordRequest`), `UserControllerValidationTest.java` (3 test — `ChangePasswordRequest` + 1 test phát hiện gap).
  - **Phát hiện thật:** `ProfileUpdateRequest.java` **không có annotation validation nào** (`@Email`, `@NotBlank`...) dù controller dùng `@Valid` — email sai định dạng hiện được chấp nhận (200) thay vì bị từ chối (400). Ghi lại làm bằng chứng (`updateProfileShouldCurrentlyAcceptMalformedEmailBecauseNoValidationAnnotationExists`), không tự sửa (đợt này chỉ được yêu cầu viết test).
  - **Ghi chú kỹ thuật cho lần sau:** `@WebMvcTest` trong Spring Boot 4.0.6 đổi package (`org.springframework.boot.webmvc.test.autoconfigure.WebMvcTest`, không phải `org.springframework.boot.test.autoconfigure.web.servlet` như bản cũ) và cần `@AutoConfigureMockMvc(addFilters = false)` để tránh bị chặn 403 bởi CSRF/security filter khi chỉ muốn test validation.
  - Đã quyết định **bỏ qua Frontend test** theo yêu cầu tester (rủi ro backend ưu tiên hơn dưới deadline gấp) và **bỏ qua #1/#2** (refresh token, brute-force lockout — vẫn chặn bởi `ddl-auto=validate`, chưa có migration).
  - Tổng backend hiện tại: `mvnw test` → **121/121 pass, 0 skip**.

---

## 3. Detailed Unit Test Case (UTC) Designs

Mẫu trình bày mỗi UTC gồm 2 phần: (a) **header block** (Module/Method/Created By/Executed By/Test requirement/Passed-Failed-Untested/N-A-B/Total), (b) **ma trận Condition/Confirm/Result** theo UTCID (tham khảo định dạng do tester cung cấp). `Created By`/`Executed By` để trống cho tester điền khi phân công thật.

### 3.1 UTC design for: `AuthService.authenticateUser`

> **Implemented** — [`AuthServiceTest.java`](../../hango-backend/src/test/java/com/hango/hango_backend/service/AuthServiceTest.java) (6 tests, all green as of 2026-07-14, `mvnw test -Dtest=AuthServiceTest`). Original design had 10 UTCID slots; 4 were dropped because they test `@Valid` DTO constraints (null/empty/255-char email) which Mockito never sees — those belong to a future MockMvc/`@WebMvcTest` layer, not this Service-level suite (see class javadoc for the rationale).

| Code Module | Authentication | Method | `authenticateUser` |
|---|---|---|---|
| Created By | tester | Executed By | Claude (pair-tested with tester) |
| Test requirement | Authenticate user credentials, check account status, record login timestamp, issue JWT session. | | |
| Passed / Failed / Untested | 6 / 0 / 0 | N / A / B | 1 / 3 / 2 |

```
UTC ID:                    UTCID01              UTCID02              UTCID03              UTCID04              UTCID05                   UTCID06
---------------------------------------------------------------------------------------------------------------------------------------------------
Test method (AuthServiceTest):
                    authenticateUser     ...BadCredentials     ...RejectInactive   ...RejectInactive    ...AllowLoginForNon        ...ThrowUsernameNotFound
                    ShouldReturnToken    ExceptionOnWrong      Account             CaseInsensitively    InactiveStatusSuchAsLocked WhenUserMissingAfterAuth
                    AndUpdateLastLogin   Password
---------------------------------------------------------------------------------------------------------------------------------------------------
Inputs:
 - Email            active@example.com  active@example.com  inactive@example.com inactive2@example.com locked@example.com        ghost@example.com
 - Password          correct             wrong                correct              correct              correct                    any
 - User.status       ACTIVE              ACTIVE               INACTIVE             "inactive" (lowercase) "LOCKED"*                 ACTIVE (user record missing)
---------------------------------------------------------------------------------------------------------------------------------------------------
Confirm / Expected Result:
 - Exp Return        LoginResponse       Error                Error                Error                LoginResponse**            Error
 - Exception         None                BadCredentialsEx     IllegalArgumentEx    IllegalArgumentEx    None**                     UsernameNotFoundEx
 - Save DB?          Yes (lastLoginAt)   No                   No                   No                   Yes**                      No
---------------------------------------------------------------------------------------------------------------------------------------------------
Case Type:           N                   A                    A                    B                    B                          A
Status:              Passed              Passed               Passed               Passed               Passed                     Passed
Exec Date:           2026-07-14          2026-07-14           2026-07-14           2026-07-14            2026-07-14                 2026-07-14
Defect ID:           —                   —                    —                    —                    —                          —
```

*`UTCID05` is a deliberate boundary/gap probe, not a spec assumption: current code (`AuthService.authenticateUser`) only rejects `status.equalsIgnoreCase("INACTIVE")`. A user with `status = "LOCKED"` (or any other non-`"INACTIVE"` string) **logs in successfully** — confirmed by running the test against real code. If the team intends `LOCKED` to block login (per `doc/specs/01-authentication.md` §4 lockout edge case), this test should start failing once the guard is added — update it then, don't soften it now to hide the gap.
**`googleLogin`'s equivalent risk is documented separately in §3.5-note; `refreshToken`/`logout` do not exist at all — see `unit_test_plan.md` §1 row 10b.

---

### 3.2 UTC design for: `AuthService.registerUser`

> **Implemented** — [`AuthServiceTest.java`](../../hango-backend/src/test/java/com/hango/hango_backend/service/AuthServiceTest.java) (5 tests, all green as of 2026-07-14). Dropped the `@Valid`-only boundary rows (invalid email format, short/null password, 255-char email) for the same reason as §3.1 — Mockito never runs Bean Validation, so those assert nothing at Service level.

| Code Module | Authentication | Method | `registerUser` |
|---|---|---|---|
| Created By | tester | Executed By | Claude (pair-tested with tester) |
| Test requirement | Register a new account, enforce email uniqueness, hash password, always assign default role, dispatch verification email. | | |
| Passed / Failed / Untested | 5 / 0 / 0 | N / A / B | 1 / 2 / 2 |

```
UTC ID:              UTCID01                UTCID02                UTCID03                  UTCID04                    UTCID05
----------------------------------------------------------------------------------------------------------------------------------
Test method (AuthServiceTest):
              registerUserShouldCreate  ...ShouldReject       ...ShouldCreateLearner   ...ShouldIgnoreClient       ...ShouldStillSucceed
              LearnerAccountAndSend     DuplicateEmail        RoleWhenItDoesNot        SuppliedRoleAndAlways       WhenVerificationEmail
              VerificationEmailOnHappy                        ExistYet                 AssignLearner               DispatchFails
----------------------------------------------------------------------------------------------------------------------------------
Inputs:
 - Email             new@example.com       existing@example.com   new2@example.com         new3@example.com           new4@example.com
 - Role field on DTO none                  none                   none                     "TRAINER"                  none
 - Precondition      "LEARNER" role exists existsByEmail=true     "LEARNER" role NOT found existsByEmail=false        emailService throws
----------------------------------------------------------------------------------------------------------------------------------
Confirm / Expected Result:
 - Exp Return        UserResponse           Error                  UserResponse             UserResponse (roles=[LEARNER]) UserResponse (no propagation)
 - Exception         None                   IllegalArgumentEx      None                     None                        None (caught internally)
 - Saved role        LEARNER                N/A                    LEARNER (newly created)  LEARNER (not TRAINER)      LEARNER
 - Password hashed   Yes                    N/A                    Yes                      Yes                         Yes
----------------------------------------------------------------------------------------------------------------------------------
Case Type:           N                      A                      B                        B                           A
Status:              Passed                 Passed                 Passed                   Passed                      Passed
Exec Date:           2026-07-14             2026-07-14             2026-07-14               2026-07-14                  2026-07-14
Defect ID:           —                      —                      —                        —                           —
```

*`UTCID04` verifies `registerUser` never honors an injected `"TRAINER"`/`"ADMINISTRATOR"` role from the request — confirmed in code: `registerUser` hardcodes role lookup to `"LEARNER"` regardless of DTO content.*
*`UTCID05` documents a real asymmetry: `registerUser` swallows email-dispatch failures (logs and continues), while `resendVerificationEmail` re-throws (see §3.7). Not a bug fix target here — just recorded so the difference in behaviour is intentional-looking, not accidental-looking.*

---

### 3.2b Remaining AUTHENTICATION module methods (consolidated)

> **Implemented** — 2026-07-14, all Passed. Full per-input/per-case detail is in the test source rather than repeated here as an ASCII matrix, to keep this section proportionate; open each file for the exact inputs/assertions.

| Method | Class | Test file | Tests | N / A / B | Key findings |
|---|---|---|:--:|:--:|---|
| `googleLogin` | AuthService | `AuthServiceTest.java` | 1 executed + 1 `@Disabled` | 0/1/0 | Happy-path (JIT-provision) **not unit-testable as written** — `GoogleIdTokenVerifier` is constructed inline via `new`, not injected. Only the malformed-token error path is covered. Recommend extracting an injectable verifier if real unit coverage is wanted. |
| `forgotPassword` | AuthService | `AuthServiceTest.java` | 2 | 1/1/0 | OTP is a 6-digit numeric string, ~5 min expiry — both asserted directly against saved entity. |
| `verifyOtp` | AuthService | `AuthServiceTest.java` | 3 | 1/1/1 | Valid OTP is **not deleted** by `verifyOtp` itself — only by `resetPassword`. Confirmed by asserting `delete()` is never called on the happy path. |
| `resetPassword` | AuthService | `AuthServiceTest.java` | 2 | 1/1/0 | — |
| `verifyAccount` | AuthService | `AuthServiceTest.java` | 2 | 1/1/0 | — |
| `resendVerificationEmail` | AuthService | `AuthServiceTest.java` | 4 | 1/2/1 | **Behavioural asymmetry vs `registerUser`**: this method re-throws `RuntimeException` on email-dispatch failure instead of swallowing it — documented, not "fixed". |
| `isAccountVerified` | AuthService | `AuthServiceTest.java` | 3 | 1/0/2 | Returns `false` (not an exception) both when the user doesn't exist and when `isVerified` is `null` — same external behaviour, different internal reason; worth knowing if a caller ever needs to distinguish "no such user" from "unverified". |
| `loadUserByUsername` | UserDetailsServiceImpl | `UserDetailsServiceImplTest.java` | 2 | 1/1/0 | Authorities are built as `"ROLE_" + roleName` — asserted directly. |
| | | **Sub-total** | **19 executed + 1 disabled** | **6/7/4** | |

**AUTHENTICATION module running total (§3.1 + §3.2 + §3.2b):** 30 tests executed, 30 passed, 0 failed, 1 `@Disabled` (documented gap) — verified via `cd hango-backend && mvnw test -Dtest=AuthServiceTest,UserDetailsServiceImplTest` (all green, 2026-07-14).

---

### 3.3 UTC design for: `AdminController.updateUserStatus` (RBAC)

| Code Module | Role & Permission (RBAC) | Method | `updateUserStatus` |
|---|---|---|---|
| Created By | _(TBD)_ | Executed By | _(TBD)_ |
| Test requirement | Admin locks/unlocks a target account; must reject self-lock and non-Admin callers. | | |
| Passed / Failed / Untested | 0 / 0 / 10 | N / A / B | 4 / 4 / 2 |

```
UTC ID:       UTCID01     UTCID02     UTCID03     UTCID04     UTCID05     UTCID06     UTCID07     UTCID08     UTCID09     UTCID10
----------------------------------------------------------------------------------------------------------------------------------
Precondition:
 - Caller role | ADMIN |   ADMIN   |   LEARNER |   ADMIN   |   ADMIN   |   ADMIN   |   ADMIN   |   ADMIN   |   ADMIN   |   ADMIN   |
 - Target id | valid |   valid   |   valid   |  not found|   valid   |   valid   |   valid   |   valid   | = caller* |   valid   |
----------------------------------------------------------------------------------------------------------------------------------
Inputs:
 - status    |INACTIVE| "active" |  ANY      |  ANY      | "ACTIVE"  | "banned"  | "xyz123"  |   null    | "INACTIVE"|256-char   |
----------------------------------------------------------------------------------------------------------------------------------
Confirm / Expected Result:
 - Exp HTTP  |  200  |    200    |    403*** |    404    |    200    |   200**   |   200**   |   400     |  400***   |   400/500 |
 - Saved status|"INACTIVE"|"ACTIVE"|  N/A    |    N/A    | "ACTIVE"  |"BANNED"** |"XYZ123"** |    N/A    | unchanged***| N/A      |
----------------------------------------------------------------------------------------------------------------------------------
Case Type:   |   N   |     N     |     A     |     A     |     N     |     B     |     B     |     A     |     B     |     B     |
Status:      | Untested | Untested | Untested | Untested | Untested | Untested | Untested | Untested | Untested | Untested |
Exec Date:   |   —   |     —     |     —     |     —     |     —     |     —     |     —     |     —     |     —     |     —     |
Defect ID:   |   —   |     —     |     —     |     —     |     —     |     —     |     —     |     —     |     —     |     —     |
```

`*` UTCID09 = Admin targets their **own** account id.
`**` UTCID06/07: current code has **no whitelist** on `status` — any string is uppercased and saved as-is (`user.setStatus(status.toUpperCase())`). Expected HTTP 200 reflects *actual* code today; if the team wants a fixed `AccountStatus` enum (Active/Locked, per `HanGo_Documentation.md` §12), this is the gap to raise.
`***` UTCID03/09: `@PreAuthorize("hasRole('ADMINISTRATOR')")` covers UTCID03 (non-admin caller → 403, framework-level, should already pass). **UTCID09 is expected to FAIL against current code** — there is no self-lock guard in `AdminController.updateUserStatus`, contradicting `doc/specs/03-rbac.md` §4 ("Self-Locking... Return HTTP 400") and the still-unchecked TODO item under FE-03 QA. Write this test now (expect it red) so it becomes the acceptance check once the guard is implemented — do not soften the assertion to match today's (wrong) behavior.

---

### 3.4 UTC design for: `ExamService.saveExamAttempt`

| Code Module | Exam Management | Method | `saveExamAttempt` |
|---|---|---|---|
| Created By | _(TBD)_ | Executed By | _(TBD)_ |
| Test requirement | Persist a Learner's exam submission (score + answers JSON), compute attempt number, return DTO. | | |
| Passed / Failed / Untested | 0 / 0 / 10 | N / A / B | 4 / 4 / 2 |

```
UTC ID:       UTCID01     UTCID02     UTCID03     UTCID04     UTCID05     UTCID06     UTCID07     UTCID08     UTCID09     UTCID10
----------------------------------------------------------------------------------------------------------------------------------
Precondition:
 - Exam ID   | valid |   valid   |  invalid  |   valid   |   valid   |   valid   |   valid   |   valid   |   valid   |   valid   |
 - User ID   | valid |   valid   |   valid   |  invalid  |   valid   |   valid   |   valid   |   valid   |   valid   |   valid   |
----------------------------------------------------------------------------------------------------------------------------------
Inputs (request.getScore() is taken as-is — NOT recomputed server-side from correct answers, see note*):
 - Score     | 8.5   |   10.0    |   7.0     |   7.0     | -1.0      | 11.5      | 0.0       | 8.5       | 8.5       | 8.5       |
 - Answers   | 40 items| 40 items| 40 items  | 40 items  | 40 items  | 40 items  | 40 items  | empty map | null      | malformed |
----------------------------------------------------------------------------------------------------------------------------------
Confirm / Expected Result:
 - Exp Return| DTO   |   DTO     |   Error   |   Error   |   DTO**   |   DTO**   |   DTO     |   DTO     |   DTO     |   DTO     |
 - Exception |  None |    None   |RuntimeEx  |RuntimeEx  |    None** |    None** |    None   |   None    |   None    |   None    |
 - answersJson saved| enriched| enriched|  N/A  |    N/A    | enriched  | enriched  | enriched  | "{}" (catch)| "{}" (catch)| "{}" (catch)|
 - attemptNumber|   n+1 |    n+1    |    N/A    |    N/A    |   n+1     |   n+1     |   n+1     |   n+1     |   n+1     |   n+1     |
----------------------------------------------------------------------------------------------------------------------------------
Case Type:   |   N   |     B     |     A     |     A     |     B     |     B     |     N     |     B     |     A     |     A     |
Status:      | Untested | Untested | Untested | Untested | Untested | Untested | Untested | Untested | Untested | Untested |
Exec Date:   |   —   |     —     |     —     |     —     |     —     |     —     |     —     |     —     |     —     |     —     |
Defect ID:   |   —   |     —     |     —     |     —     |     —     |     —     |     —     |     —     |     —     |     —     |
```

*`*` **Known risk to flag, not a spec assumption**: `ExamService.saveExamAttempt` persists `request.getScore()` directly — it does **not** recompute the score server-side from the exam's stored correct answers. A malicious/buggy client can submit any score (including `-1.0` or `11.5`, outside the documented 0–10 scale in `HanGo_Documentation.md` BR-EXM-01). Current code has no server-side validation range check either — `**` marks UTCID05/06 where the out-of-range score is still accepted and saved as-is (expected to currently **pass** against real code, which is itself the defect to report). This is exactly the kind of finding this plan exists to surface — write the test to assert *current* behavior, then file it as a defect for the dev team (client-trust / missing score-range validation), rather than asserting the "should be" behavior and calling it a false failure.*

---

### 3.5 UTC design for: `PaymentService.processVnpayIpn` — **[PLANNED, no code yet]**

| Code Module | Payment & Revenue | Method | `processVnpayIpn` |
|---|---|---|---|
| Created By | _(TBD)_ | Executed By | _(TBD)_ |
| Test requirement | Verify VNPay IPN checksum + amount, mark Order Paid idempotently, trigger auto-enroll + revenue split. **Design-only — `PaymentService`/`Order`/`RevenueRecord` do not exist in code yet; this UTC is the acceptance spec to build against**, per `doc/specs/12-payment-revenue.md` and BR-PAY-01..04. | | |
| Passed / Failed / Untested | 0 / 0 / 10 | N / A / B | 3 / 5 / 2 |

```
UTC ID:       UTCID01     UTCID02     UTCID03     UTCID04     UTCID05     UTCID06     UTCID07     UTCID08     UTCID09     UTCID10
----------------------------------------------------------------------------------------------------------------------------------
Precondition:
 - Order     |Pending|   Pending |   Pending |   Pending |   Paid*   |  Pending  |  Pending  |  Pending  |  Pending  |  Pending  |
----------------------------------------------------------------------------------------------------------------------------------
Inputs:
 - Checksum  | valid |   valid   |  INVALID  |   valid   |   valid   |   valid   |   valid   |   valid   |   valid   |   valid   |
 - Amount vs Order| match| match |    match  | MISMATCH  |   match   |   match   |   match   |   match   |   match   |   match   |
 - vnp_ResponseCode| "00" | "00" |    "00"   |    "00"   |    "00"   |  "24"(fail)| "00"     |    "00"   |    "00"   |    "00"   |
 - Duplicate IPN (same txn sent twice)|No| No|     No    |     No    |  Yes**    |     No    |     No    |     No    |     No    |    No     |
----------------------------------------------------------------------------------------------------------------------------------
Confirm / Expected Result:
 - Order status|  Paid |   Paid    | unchanged | unchanged |   Paid    |  Failed   |   Paid    |   Paid    |   Paid    |   Paid    |
 - Enrollment created|Yes| Yes  |     No    |     No    |No (already)|    No     |    Yes    |    Yes    |    Yes    |    Yes    |
 - RevenueRecord split| 70/30(Teacher)|60/40(Tutor)|N/A|N/A|No (already)|   N/A     |70/30      |60/40      |70/30      |70/30      |
 - HTTP response to VNPay| 200 |   200     |   200*** |   200***  |    200    |    200    |    200    |    200    |    200    |    200    |
----------------------------------------------------------------------------------------------------------------------------------
Case Type:   |   N   |     N     |     A     |     A     |     B     |     N     |     N     |     N     |     N     |     N     |
Status:      | Untested | Untested | Untested | Untested | Untested | Untested | Untested | Untested | Untested | Untested |
Exec Date:   |   —   |     —     |     —     |     —     |     —     |     —     |     —     |     —     |     —     |     —     |
Defect ID:   |   —   |     —     |     —     |     —     |     —     |     —     |     —     |     —     |     —     |     —     |
```

`*` UTCID05 = Order already `Paid` when a second IPN arrives — this is the idempotency case (NFR-03/FR-PAY-03).
`**` Duplicate delivery of the exact same VNPay transaction, distinct from a legitimately-Pending order.
`***` Must still return HTTP 200 to VNPay even on internal rejection (checksum/amount failure) — returning non-200 causes VNPay to retry; the *rejection* is internal (log + do not mutate Order), not surfaced as an HTTP error to the gateway.

---

### 3.6 UTC design for: `LearningPathwayService.generatePathway`

| Code Module | Recommendation / Learning | Method | `generatePathway` |
|---|---|---|---|
| Created By | _(TBD)_ | Executed By | _(TBD)_ |
| Test requirement | Build a learning roadmap from the student's latest Exam Attempt; enforce ownership; fall back gracefully when no published courses exist. | | |
| Passed / Failed / Untested | 0 / 0 / 8 | N / A / B | 4 / 3 / 1 |

```
UTC ID:       UTCID01     UTCID02     UTCID03     UTCID04     UTCID05     UTCID06     UTCID07     UTCID08
---------------------------------------------------------------------------------------------------------
Precondition:
 - studentId | valid     | valid     | invalid   | valid     | valid     | valid     | valid     | valid     |
 - examAttemptId (DTO)| valid | valid | valid    | invalid   | valid     | valid     | valid     | valid     |
 - Attempt.student == studentId| Yes | Yes    |    N/A    |    N/A    |    No     |    Yes    |    Yes    |    Yes    |
 - Published courses in DB| 5     | 5         |    N/A    |    N/A    |    N/A    |     0     |     5     |     5     |
---------------------------------------------------------------------------------------------------------
Inputs:
 - Gemini response|  Normal   |  Normal   |    N/A    |    N/A    |    N/A    |    N/A    |  Timeout  |  Malformed|
---------------------------------------------------------------------------------------------------------
Confirm / Expected Result:
 - Exp Return|   DTO     |   DTO     |ApiException 404|ApiException 404|ApiException 403|DTO (fallback msg)|DTO or Error*|DTO or Error*|
 - Uses fallback-to-all-courses|  No   |    No     |    N/A    |    N/A    |    N/A    |   Yes (empty pathway)|   No  |    No     |
---------------------------------------------------------------------------------------------------------
Case Type:   |   N   |     N     |     A     |     A     |     A     |     B     |     A     |     A     |
Status:      | Untested | Untested | Untested | Untested | Untested | Untested | Untested | Untested |
Exec Date:   |   —   |     —     |     —     |     —     |     —     |     —     |     —     |     —     |
Defect ID:   |   —   |     —     |     —     |     —     |     —     |     —     |     —     |     —     |
```

`*` UTCID07/08 depend on how `GeminiClientService` surfaces provider errors — **verify** the exact exception/fallback path when writing the test (mock `GeminiClientService` and inspect actual current handling; do not assume a fallback exists unless confirmed in code).

---

*Kế hoạch này bao phủ 18 method đại diện / ~102 UTC cho đợt đầu. Các method còn lại trong §1 (đã Implemented nhưng chưa lên UTC) và các module Planned sẽ được bổ sung UTC theo cùng khuôn mẫu ở các đợt tiếp theo — không mở rộng phạm vi tài liệu này quá mức cần thiết cho một kế hoạch ban đầu.*
