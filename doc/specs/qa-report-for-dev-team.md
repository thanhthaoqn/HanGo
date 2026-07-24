# Báo cáo QA gửi Dev Team — HanGo Backend Unit Test

**Người thực hiện:** DucPM (QA/Tester)
**Ngày:** 2026-07-19
**Phạm vi:** Unit test tầng Service (backend), theo nguyên tắc code-first — test bám sát hành vi thật của code hiện tại, không suy diễn từ tài liệu thiết kế.
**Kết quả hiện tại:** `mvnw clean test` → **359/359 pass, 0 skip**, 8 module đã test (AUTHENTICATION, PROFILE, TRAINER ONBOARDING, EXAM, LEARNING, COURSE + COURSE CONTENT, QUESTION BANK, AI ASSISTANT).

> Tài liệu chi tiết từng UTC nằm ở `doc/specs/utc-sheet-*.csv` (1 file/module, mỗi dòng = 1 testcase). Log đầy đủ theo từng đợt nằm ở `doc/specs/unit_test_plan.md`. File này là bản tổng hợp cấp cao để báo cáo, không thay thế 2 nguồn trên.

---

## 1. Tóm tắt nhanh cho người bận

- **359 unit test, 100% pass**, phủ 8/14 module nghiệp vụ chính (theo cách chia module trong `HanGo_Documentation.md` §7).
- **9 lỗi/gap thật sự đáng chú ý** được tìm thấy qua quá trình viết test (liệt kê ưu tiên ở Mục 3) — đa số là logic sai hoặc tính năng làm dở dang, chưa cái nào là lỗi bảo mật nghiêm trọng.
- **1 phát hiện tích cực đáng nói**: cơ chế "role Trainer cấp sớm nhưng chặn kiếm tiền cho tới khi Admin duyệt" (qua `TrainerProfile.status == VERIFIED`) đang hoạt động **nhất quán** ở cả 2 nơi độc lập (`publishTrainerCourse` và `enrollCourse`) — đây là thiết kế phòng thủ tốt, không phải lỗi.
- **Việc tôi KHÔNG làm, để dev biết rõ ranh giới**: không test Controller layer (quyết định có chủ đích, xem Mục 5), không test `GeminiClientService` (gọi HTTP thật, không có điểm nối để mock), không test `CourseImportService` (737 dòng, quá lớn, để dành đợt riêng).

---

## 2. Bảng tổng hợp theo module

| # | Module | Class đã test | Số test | Trạng thái | Bug/Gap tìm thấy |
|---|---|---|---:|---|---|
| 1 | AUTHENTICATION | AuthService, UserDetailsServiceImpl | 52 | ✅ Ổn định | GAP-AUTH-01, GAP-AUTH-03 (xem Mục 3) |
| 2 | PROFILE | AuthService (chung file) | *(gộp trong 52 ở trên)* | ✅ Ổn định | GAP-PROF-03 |
| 3 | TRAINER ONBOARDING | TrainerOnboardingServiceImpl | 32 | ✅ Ổn định | GAP-TRN-01 (đã làm rõ, không nghiêm trọng như tưởng ban đầu) |
| 4 | EXAM MANAGEMENT | ExamService, ExamResultAnalyzerService, TrainerExamMatrixServiceImpl | 41 | ✅ Ổn định | **GAP-EXM-01** (nghiêm trọng nhất trong toàn bộ báo cáo), GAP-EXM-02, GAP-EXM-03 |
| 5 | LEARNING MANAGEMENT | LessonServiceImpl (completeLesson), CourseServiceImpl (enroll), CourseRatingServiceImpl, PathwayMutationService, PathwayProgressSnapshotService, LearningPathwayService (+9 mới) | 74 mới + 15 có sẵn của dev | ✅ Ổn định | Không có gap mới; củng cố thêm bằng chứng cho cơ chế publish-gate |
| 6 | COURSE + COURSE CONTENT | TrainerDashboardServiceImpl (12 method), LessonServiceImpl.getLessonDetail, CourseManagerDashboardServiceImpl | 50 | ✅ Ổn định | Xác nhận dứt điểm gap versioning (BR-CRS-03), GAP `updateExamStatus` không phân vai trò, phát hiện `CourseImportService` chưa test |
| 7 | QUESTION BANK | TrainerQuestionServiceImpl, TrainerQuestionAIService | 44 | ✅ Ổn định | **GAP-QB-01** |
| 8 | AI ASSISTANT | AIAssistantService, ScopeGuardrailService, AIPromptBuilder, LessonEmbeddingService, VectorUtil | 39 | ✅ Ổn định | Không có gap — 3 lớp guardrail hoạt động đúng thiết kế |
| — | **Tổng** | 21 class Service | **359** | **100% pass** | **9 gap** |

Module **chưa test**: RBAC (mới có 4 test cho `AdminController.updateUserStatus`, còn `getUsers`/`getUserDetail`/`createUserByAdmin`/`updateUserByAdmin`/`getDashboardStats`/permissions chưa động tới), PAYMENT & REVENUE (chưa có code — 100% Planned), COMMENT MANAGEMENT, NOTIFICATION (chưa có code), RECOMMENDATION (`ExamCourseRecommendationAIService` chưa test).

---

## 3. Danh sách lỗi/gap ưu tiên xử lý

Xếp theo mức độ ảnh hưởng thực tế tới người dùng, không theo thứ tự tìm ra.

### 🔴 Ưu tiên cao

**GAP-EXM-01 — `answers` trong lịch sử làm bài luôn trả về rỗng dù đã lưu đúng trong DB**
- **Vị trí:** `ExamService.mapToAttemptDTO` (dòng ~178-186)
- **Chi tiết:** `saveExamAttempt` lưu `answersJson` dưới dạng **JSON array** (qua `enrichAnswers`), nhưng khi đọc lại để trả về cho client, code dùng `objectMapper.readValue(answersJson, Map.class)` — cố parse 1 mảng JSON thành kiểu Map. Lỗi này bị `catch (Exception e)` nuốt âm thầm, mặc định trả về map rỗng.
- **Ảnh hưởng:** Mọi API liên quan tới xem lại chi tiết từng câu trả lời (`saveExamAttempt` response, `getExamAttempts`, `getMyExamAttempts`) đều trả `answers` rỗng cho FE, dù dữ liệu `userAnswer`/`isCorrect`/`skill`/`topic` từng câu **đã được lưu đúng trong DB**. Learner xem lại bài thi sẽ không thấy được mình đã chọn đáp án nào.
- **Đề xuất fix:** Đổi kiểu đọc ở `mapToAttemptDTO` từ `Map.class` sang `List<Map<String,Object>>` (khớp với những gì `enrichAnswers` thực sự ghi ra), rồi convert sang cấu trúc phù hợp với `ExamAttemptResponseDTO.answers` (hiện đang khai báo kiểu `Map<String,Integer>` — kiểu này bản thân nó cũng không khớp với dữ liệu enrich thật, có thể cần xem lại luôn cả DTO này).
- **Test đã viết chứng minh:** `ExamServiceTest.saveExamAttemptShouldPersistEnrichedAnswersAsJsonArrayButEchoBackEmptyAnswersDueToTypeMismatch`

### 🟡 Ưu tiên trung bình

**Course versioning (BR-CRS-03 / §9.7) hoàn toàn chưa được cài đặt**
- **Vị trí:** `TrainerDashboardServiceImpl.updateTrainerCourse`
- **Chi tiết:** Tài liệu thiết kế yêu cầu sửa nội dung Course đã Published phải tạo version mới + qua duyệt lại. Code thực tế: sửa Course ở **bất kỳ trạng thái nào** (kể cả đã PUBLISHED) đều ghi đè trực tiếp lên cùng 1 row Course + toàn bộ Section/Lesson liên quan, không có bảng `course_versions`, không có cơ chế duyệt lại.
- **Ảnh hưởng:** Learner đang học 1 Course đã Published có thể thấy nội dung thay đổi đột ngột giữa chừng mà không có cảnh báo/duyệt lại — vi phạm kỳ vọng UX đã ghi trong doc.
- **Đề xuất:** Cần quyết định rõ: (a) implement thật cơ chế versioning, hoặc (b) nếu team đã chủ động bỏ tính năng này để làm nhanh MVP thì nên cập nhật lại `HanGo_Documentation.md` BR-CRS-03 cho khớp thực tế (tránh để tài liệu hứa hẹn tính năng không tồn tại).

**`updateExamStatus` không phân biệt vai trò người gọi — Trainer tự publish Exam của mình được, không qua Course Manager duyệt**
- **Vị trí:** `TrainerDashboardServiceImpl.updateExamStatus`
- **Chi tiết:** Method chỉ kiểm tra "người gọi có phải chủ sở hữu Exam hay không", không kiểm tra role. Bất kỳ Trainer nào cũng có thể tự đặt Exam của mình sang bất kỳ status nào, kể cả "PUBLISHED".
- **Câu hỏi cần dev xác nhận:** `HanGo_Documentation.md` FR-EXM-03 ghi "Exam do Course Manager tạo được self-publish" — hàm ý ngầm là Exam do **Trainer** tạo thì KHÔNG được tự publish, phải qua Course Manager duyệt (giống cơ chế `publishTrainerCourse` đang có cho Course). Nhưng code hiện tại không phân biệt gì cả. Đây có phải lỗ hổng thật hay là quyết định nghiệp vụ (Exam không cần duyệt như Course)? Cần dev confirm.

**Course Manager review/approve/reject workflow cho Course — vẫn hoàn toàn chưa tồn tại**
- Đã khảo sát lại 2 lần (đợt EXAM và đợt COURSE), xác nhận `CourseManagerDashboardServiceImpl` chỉ có 1 method thống kê dashboard (`getDashboardSummary`), không có bất kỳ endpoint/method approve-reject-publish nào cho Course Manager. Nếu đây vẫn là tính năng dự kiến (BR-G04 "Two-step governance" trong doc), cần lên kế hoạch code — hiện Trainer tự publish luôn sau khi được Admin verify hồ sơ (`publishTrainerCourse`), không qua bước Course Manager review nội dung nào cả.

### 🟢 Ưu tiên thấp (dead code / tính năng làm dở, không ảnh hưởng người dùng thật ngay)

**GAP-QB-01 — AI sinh câu hỏi luôn nhận `category`/`difficulty` = null thay vì giá trị mặc định**
- **Vị trí:** `TrainerQuestionAIService.generatePayload`
- **Chi tiết:** Code tính sẵn 2 biến fallback (`categoryId` mặc định 1L, `difficultyId` mặc định 14L khi Trainer không chọn) nhưng **không bao giờ dùng tới** — `buildUserInput()` đọc thẳng giá trị gốc (null) từ request. Biến fallback là dead code.
- **Ảnh hưởng:** Nhỏ — prompt gửi Gemini ghi "CATEGORY_ID(DEFAULT): null" thay vì số thật, nhưng vì đây chỉ là gợi ý ngữ cảnh cho AI (không phải giá trị bắt buộc), khả năng cao AI vẫn generate được câu hỏi bình thường, chỉ là mất đi 1 tín hiệu định hướng.
- **Đề xuất fix:** 2 dòng — đổi `buildUserInput` dùng biến `categoryId`/`difficultyId` đã tính thay vì `req.getCategoryId()`/`req.getDifficultyId()`. Rất nhanh để sửa.

**GAP-EXM-02 — Lọc danh sách Exam theo status khác 'PUBLISHED' luôn trả về rỗng**
- **Vị trí:** `ExamService.getAllExams(status)`
- **Chi tiết:** Khi `status` không phải `null`/`'ALL'`/`'PUBLISHED'` (ví dụ `'DRAFT'`), code query DB theo đúng status đó rồi **lọc lại trong bộ nhớ chỉ giữ status=='PUBLISHED'** — tự mâu thuẫn, không bao giờ khớp.
- **Ảnh hưởng:** Hiện tại chưa thấy caller nào thực sự dùng path này (Learner chỉ xem Exam đã Published), nên có thể là dead code an toàn. Vẫn nên dọn cho sạch hoặc xác nhận không ai gọi.

**GAP-EXM-03 — `saveExamAttempt` tin tưởng hoàn toàn điểm số client gửi lên**
- Không tính lại điểm từ đáp án đúng, không validate range 0-10 (BR-EXM-01). Client (buggy hoặc cố tình) có thể gửi điểm bất kỳ, kể cả âm hoặc >10. Đây là rủi ro tính toàn vẹn dữ liệu — nên cân nhắc thêm validate ở server trước khi launch chính thức (không cấp bách nếu FE luôn tính đúng, nhưng không nên dựa hoàn toàn vào FE).

**GAP-AUTH-01 — Đăng nhập không chặn tài khoản có status khác 'INACTIVE' (ví dụ 'LOCKED')**
- `authenticateUser` chỉ reject khi `status.equalsIgnoreCase("INACTIVE")`. Một tài khoản có status `"LOCKED"` (hoặc bất kỳ chuỗi nào khác) vẫn đăng nhập được bình thường. Đã giảm nhẹ 1 phần ở điểm vào Admin (`updateUserStatus` giờ chỉ cho phép set ACTIVE/INACTIVE), nhưng bản thân `authenticateUser` chưa sửa.

**GAP-PROF-03 — `ProfileUpdateRequest` không có annotation validation nào**
- Dù Controller dùng `@Valid`, DTO này không có `@Email`/`@NotBlank`/`@Size` gì cả → email sai định dạng vẫn được chấp nhận khi cập nhật profile. Sửa nhanh, chỉ cần thêm annotation.

---

## 4. Điểm tích cực đáng ghi nhận

- **Cơ chế publish-gate nhất quán:** `TrainerDashboardServiceImpl.publishTrainerCourse` và `CourseServiceImpl.enrollCourse` đều độc lập kiểm tra `TrainerProfile.status == 'VERIFIED'` trước khi cho phép publish/ghi danh — nghĩa là dù role Trainer được cấp sớm (ngay khi đăng ký hoặc gọi `become-trainer`), Trainer **không thể kiếm tiền được** cho tới khi Admin duyệt hồ sơ. Thiết kế phòng thủ 2 lớp độc lập này tốt, nên giữ nguyên.
- **3 lớp AI guardrail hoạt động đúng như comment mô tả:** embedding similarity check → prompt engineering → backend context check, kể cả các nhánh fail-open có chủ đích (lỗi gọi Gemini embedding thì vẫn cho qua để chat model tự chối khéo, lỗi sinh suggestedQuestions thì không làm hỏng câu trả lời chính) đều test pass, không có gap.
- **`saveQuizAttempt`/`getQuizAttempts` (Lesson quiz) không dính lỗi type-mismatch giống EXM** — vì `answers` ở đây khai báo nhất quán `Map<String,Integer>` từ đầu tới cuối, không qua bước "enrich thành array" như bên Exam. Đây là bằng chứng gián tiếp cho thấy GAP-EXM-01 là lỗi cục bộ (do enrich logic), không phải pattern lặp lại toàn hệ thống.

---

## 5. Ghi chú phạm vi (để dev hiểu rõ những gì KHÔNG có trong bộ test này)

Theo thống nhất với tester (2026-07-17), các quyết định sau là **chủ đích**, không phải thiếu sót:

1. **Không test Controller layer.** Toàn bộ 359 test đều ở tầng Service, dùng Mockito thuần. Trước đó (đợt AUTH/PROFILE) có viết ~59 test Controller nhưng đã xóa để tập trung tốc độ. Ngoại lệ: `AdminController` (4 test) — giữ lại vì không có Service riêng, logic self-lock/status-whitelist nằm thẳng trong Controller.
2. **Không test `GeminiClientService`** — tự dựng `WebClient` nội bộ, gọi HTTP thật, không có điểm nối để mock trong unit test. Mọi service khác dùng nó đều mock nó qua constructor injection (đúng cách).
3. **Không test `CourseImportService`** (737 dòng — tự parse XML thô bên trong file `.xlsx`, không dùng Apache POI). Đây là phát hiện tính năng thật đang tồn tại trong code nhưng trước đó bị đánh giá nhầm là "chưa làm" (Planned) ở khảo sát 2026-07-13 — cần 1 đợt test riêng vì độ phức tạp vượt xa mọi thứ đã test.
4. **Test file có sẵn của dev không bị động tới**: `LearningPathwayServiceTest.java` (9 test gốc), `PathwayGoalMergeServiceTest.java` (1), `PathwayReroutePolicyServiceTest.java` (3), `PathwayTimeboxingSchedulerTest.java` (2), `SectionQuestionControllerTest.java` (8) — đều do teammate tự viết, đã pass sẵn, được giữ nguyên và chỉ bổ sung thêm test cho phần chưa cover.

---

## 6. Đề xuất cho các bước tiếp theo

1. **Ưu tiên fix GAP-EXM-01** trước — ảnh hưởng trực tiếp tới trải nghiệm xem lại bài thi của Learner, và fix khá gọn (đổi kiểu parse + review lại DTO `answers`).
2. **Dev xác nhận ý định nghiệp vụ** cho 2 câu hỏi mở: (a) Course versioning có còn trong scope MVP không, (b) Exam có cần qua Course Manager duyệt trước khi Trainer publish không (giống Course) hay được thiết kế khác biệt có chủ đích.
3. **2 fix nhanh, ít rủi ro:** GAP-QB-01 (nối dây biến fallback, 2 dòng code) và GAP-PROF-03 (thêm validation annotation vào DTO).
4. **Test tiếp các module còn lại** theo thứ tự đề xuất: RBAC (đang dang dở, rủi ro bảo mật cao nhất trong các module chưa test) → COMMENT MANAGEMENT → RECOMMENDATION → rồi mới tới `CourseImportService` (khối lượng lớn, nên tách thành 1 đợt riêng có ước lượng thời gian rõ ràng).
5. **Retest toàn bộ từ đầu ở giai đoạn cuối dự án** (đã thống nhất với tester từ trước) — vì dự án đổi code liên tục theo ngày, một số test/finding trong báo cáo này có thể lệch khỏi thực tế nếu code thay đổi trước ngày release.
