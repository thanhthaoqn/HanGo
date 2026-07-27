# HanGo — Roadmap sau v1.0

> **Phase:** 5 (Version Review) của đợt audit toàn dự án 2026-07-24. Tài liệu này là **bản kế hoạch cho các version sau khi v1.0 đóng lại** — không mô tả lại toàn bộ tính năng v1 (xem [`HanGo_Documentation.md`](HanGo_Documentation.md) cho việc đó), chỉ tập trung vào **việc cần làm tiếp theo, sắp xếp theo mức độ ưu tiên**.
> **Nguồn:** tổng hợp từ [`AUDIT_REPORT.md`](AUDIT_REPORT.md) (tất cả finding Critical/High/Medium), [`TEST_AUDIT_REPORT.md`](TEST_AUDIT_REPORT.md) (test gap còn lại), `HanGo_Documentation.md` §14.2 (Future phase đã chốt từ trước), và `TODO.md` (Phase 5 Agentic Upgrade của Learning Pathway).
> **Cách đọc:** mỗi mục có mức ưu tiên (P0 khẩn cấp nhất → P3 khi có thời gian) và lý do ngắn. Không có mốc thời gian cụ thể (chưa ai cam kết ngày) — thứ tự trong mỗi nhóm P là thứ tự khuyến nghị làm trước/sau trong nhóm đó.

---

## P0 — Bảo mật & Ổn định (nên làm trước khi mở rộng traffic thật)

Đây là những việc rẻ để sửa nhưng rủi ro cao nếu để lâu — không phải nợ kỹ thuật thông thường.

| # | Việc cần làm | Vì sao ưu tiên cao nhất | Tham chiếu |
|---|---|---|---|
| 1 | **Rotate credentials PayOS thật đã bị lộ** (đã commit trong `DEPLOY_GUIDE.md`, đã push lên `origin/dev`) — tạo key mới trên PayOS Merchant Dashboard, không chỉ xoá khỏi file hiện tại (git history vẫn còn). | Giá trị cũ coi như đã lộ ra ngoài, có thể đã hoặc sẽ bị lợi dụng. | `AUDIT_REPORT.md` CRIT-03 |
| 2 | **Xoá hoặc khoá `TestDBController`** (`/api/test-db/**`) khỏi build deploy thật — hiện không cần đăng nhập và có thể reset mật khẩu bất kỳ tài khoản Trainer nào về giá trị cố định rồi trả về email+mật khẩu trong response. | Chiếm quyền tài khoản hoàn toàn, không cần bất kỳ credential nào. | `AUDIT_REPORT.md` CRIT-01 |
| 3 | **Sửa `CommentController`/`LessonController` nhận `userId` từ client** — đổi sang lấy từ `SecurityContext`/`@AuthenticationPrincipal` giống các controller khác đã làm đúng (`CourseController`, `ExamController`, `PaymentController`). | Bất kỳ ai cũng mạo danh được user khác để đăng/sửa/xoá comment hoặc nộp quiz. | `AUDIT_REPORT.md` CRIT-02 |
| 4 | **Thêm `@PreAuthorize` cho `SectionQuestionController`** (8 endpoint CRUD câu hỏi/section của Trainer hiện không có role-gate nào). | Bất kỳ role nào đã đăng nhập (kể cả Learner) đều sửa được nội dung câu hỏi của Trainer khác. | `AUDIT_REPORT.md` CRIT-04 |
| 5 | Xác nhận không còn secret thật nào khác bị commit (rà lại git history, không chỉ working tree). | Một lần lộ thường không phải lần duy nhất — nên rà soát toàn diện thay vì vá từng chỗ. | — |

---

## P1 — Kiến trúc & Nợ kỹ thuật

Không khẩn cấp như P0 nhưng càng để lâu càng khó sửa (đặc biệt là 2 mục đầu — càng nhiều code mới viết theo pattern cũ thì càng tốn công đổi sau).

| # | Việc cần làm | Vì sao nên làm | Tham chiếu |
|---|---|---|---|
| 1 | **Thêm Flyway, baseline schema hiện tại** (`flyway:baseline` trên DB thật), chuyển `spring.jpa.hibernate.ddl-auto` sang `validate` ở `application.properties` thật (không chỉ ở `.example`). | Hiện tại 1 lần đổi field/entity vô tình có thể tự động ALTER TABLE trên schema thật — không có lịch sử version, không rollback được. | `AUDIT_REPORT.md` HIGH-01 |
| 2 | **Thống nhất 1 luồng approve/reject Course/Exam duy nhất** — hiện có 2 luồng độc lập (`TrainerDashboardServiceImpl` vs `CourseManagerDashboardServiceImpl`) với status/notification khác nhau. Cần xác nhận luồng nào frontend thực sự gọi, rồi xoá/hợp nhất luồng còn lại. | Rủi ro dữ liệu không nhất quán — trạng thái 1 course có thể khác nhau tuỳ endpoint nào được gọi. | `AUDIT_REPORT.md` HIGH-04 |
| 3 | **Chuẩn hoá error-handling response toàn API** — mở rộng `GlobalExceptionHandler` bắt thêm `Exception` chung + `MethodArgumentNotValidException`; chuyển các `throw new RuntimeException(...)` rải rác sang `ApiException` dần dần. | Hiện tại response lỗi không nhất quán (`{error}` vs `{message}` vs lộ tên class exception ra client). | `AUDIT_REPORT.md` HIGH-05 |
| 4 | **Quyết định rõ ràng về MapStruct** — hoặc adopt thật cho các mapper lớn nhất (Course/Exam/Payment), hoặc bỏ hẳn khỏi `CONSTITUTION.md` (đã tạm sửa thành "giữ nguyên style thủ công" trong đợt audit này, nhưng đây vẫn là quyết định đội ngũ nên chốt chính thức). | Tài liệu và thực tế đang khớp nhau (đã sửa), nhưng đây là lúc tốt để quyết định luôn thay vì để mãi ở trạng thái "tạm chưa". | `CONSTITUTION.md` §4 |
| 5 | **Frontend: hợp nhất `lib/domain/model/` + `lib/domain/entities/`** — có 2 class `Exam` không tương thích nhau, cần chọn 1 và migrate chỗ dùng còn lại. | Rủi ro bug khi 1 dev sửa nhầm class `Exam` không phải class đang thực sự dùng ở màn hình họ sửa. | `AUDIT_REPORT.md` MED-07 |
| 6 | **Frontend: hợp nhất `lib/services/` + `lib/data/services/`** — đặc biệt là 2 nơi lưu session (`SharedPreferences` vs `flutter_secure_storage`) hiện không đồng bộ tường minh. | 2 nguồn sự thật cho "user đã đăng nhập chưa" là rủi ro logic thật, không chỉ là gọn code. | `AUDIT_REPORT.md` MED-08 |
| 7 | **Frontend: giới thiệu 1 API client tập trung** (dù chọn `dio` thật hay giữ `http`) với 1 interceptor đính JWT — hiện đang copy-paste đọc `SharedPreferences` ở 59 chỗ across 13 file. | Giảm nguy cơ quên đính token ở 1 chỗ mới, dễ thêm retry/refresh-token sau này. | `AUDIT_REPORT.md` HIGH-06 |
| 8 | **Cân nhắc dedicated PR đổi tên package `sercurity`→`security`, `exeption`→`exception`** khi dự án có 1 khoảng lặng (không bundle chung với feature work). | Blast radius lớn (mọi file import 2 package này), nên làm riêng, review kỹ, không làm giữa lúc đang có tính năng khác dở dang. | `AUDIT_REPORT.md` MED-02 |
| 9 | Dọn dẹp: xoá các file rác đã xác nhận chết (`_debug_provider_check.dart`, `test.dart`/`test_uri.dart`/`analyze_output.txt`, `CheckDBApp.java`, `response.json`, thư mục `test/` rỗng ở gốc repo) — bị chặn tự động trong đợt audit này, cần làm thủ công hoặc xác nhận lại. | Rác nhỏ nhưng gây nhiễu khi tìm kiếm code / chạy `flutter analyze`. | `AUDIT_REPORT.md` LOW-01/02/03 |

---

## P2 — Test Coverage còn thiếu

Không chặn release nhưng nên làm trước khi các method này có thay đổi nghiệp vụ tiếp theo (dễ phát hiện regression hơn).

**Backend (theo thứ tự khuyến nghị):**
1. `CourseServiceImpl.switchCourseVersion` / `getCourseVersionHistory` — versioning logic, có tính toán progress carryover, khá phức tạp.
2. `TrainerDashboardServiceImpl.submitTrainerCourse` / `updateExamVisibility` / `deleteTrainerCourse` — 3 method còn thiếu trong 1 class đã test tốt phần lớn.
3. `TrainerDashboardServiceImpl.approveTrainerCourse` / `rejectTrainerCourseDraft` — **nên làm sau khi giải quyết P1#2** (thống nhất luồng approve/reject), tránh viết test khoá cứng 1 phía tuỳ ý của một sự không nhất quán sẽ bị xoá sau.
4. `CourseImportService.importWorkbook` — 737 dòng, đã hoãn nhiều đợt liên tiếp; xứng đáng 1 đợt test riêng thay vì cố nhét vào đợt khác.
5. Nếu có seam để mock: `GeminiClientService` (hiện tự dựng `WebClient` qua `@PostConstruct`, không inject được) — cần refactor nhỏ (constructor injection cho `WebClient.Builder`) trước khi test được.

**Frontend (gần như từ 0 — ưu tiên theo giá trị/rủi ro, không phải theo alphabet):**
1. `AuthService` (login/register/OTP/đổi mật khẩu) — luồng traffic cao nhất, ít thay đổi nhất nên ROI test tốt.
2. Luồng thi (`take_exam_page.dart` — timer/auto-submit) — đúng theo NFR-06 (Exam timer chính xác) đã cam kết trong `HanGo_Documentation.md`.
3. `CourseRepository`/`ExamRepository`/`PaymentRepository` — model parsing + lỗi mạng.
4. Form validate ở `login_page.dart`/`register_page.dart`.
5. Sau đó mới tính tới coverage rộng hơn cho 67 trang còn lại — không cần làm hết cùng lúc.

Chi tiết đầy đủ, bao gồm method nào đã có/thiếu test: [`TEST_AUDIT_REPORT.md`](TEST_AUDIT_REPORT.md).

---

## P3 — Tính năng / Business (ngoài phạm vi v1, đã chốt từ Decision Log)

Đây là các hạng mục **đã được xác nhận là ngoài phạm vi v1** (không phải phát hiện mới từ audit) — liệt kê lại ở đây kèm ưu tiên tương đối để dùng làm input lập kế hoạch version 2.

### 3.1 Ưu tiên cao hơn trong nhóm này
- **Refund policy & tự động payout cho Trainer** — hiện chi trả hoàn toàn thủ công (Course Manager chuyển khoản tay + record). Đây là điểm nghẽn vận hành rõ nhất khi số lượng Trainer tăng.
- **WebSocket/STOMP cho Notification realtime** — hiện chỉ REST polling; kiến trúc đã chừa sẵn chỗ (`NotificationService`/`Notification` entity đã đầy đủ), chỉ còn phần transport.
- **AI usage limit & cost model** — hiện log đầy đủ (`AiUsageLog`) nhưng không giới hạn/tính chi phí; rủi ro chi phí Gemini API không kiểm soát nếu traffic tăng.

### 3.2 Ưu tiên trung bình
- Mobile app native (hiện chỉ Flutter Web).
- Pass-score cho Quiz (hiện Quiz không có ngưỡng đạt/không đạt).
- Công thức price-tier chi tiết (hiện mới có 3 mốc 300k/500k/700k, chưa có công thức tính quy mô Course rõ ràng — `FR-CRS-06`/`TODO.md` FE-05 đã note việc này còn thiếu).
- GroupType mở rộng sang course-authoring & analytics (hiện GroupType chỉ dùng cho Exam/Question Bank).

### 3.3 Ưu tiên thấp hơn / cần thêm input kinh doanh trước khi làm
- Đa ngôn ngữ giao diện (hiện chỉ English).
- Role Finance riêng (hiện Course Manager kiêm luôn phần tài chính).

### 3.4 Learning Pathway — Agentic Upgrade (đã có khung sẵn trong `TODO.md` FE-11 Phase 5, chưa bắt đầu)
Đây là hạng mục lớn nhất trong danh sách future — nên tách thành các milestone nhỏ thay vì làm 1 lần:
1. Agent Tooling (function calling): `triggerReroute`, `getPathwayById`, `getUserProgressSnapshot` + orchestrator thực thi.
2. Long-term memory: `ai_chat_histories` (persist chat theo pathway) + profile memory (điểm mạnh/yếu học viên).
3. Prompt management: tách system prompt ra khỏi code sang config ngoài (`.st` template hoặc tương đương).
4. Human-in-the-loop: nút "Report bad roadmap" + rule tự động flag pathway bị reroute ≥3 lần cho Admin xem lại.
5. Guardrail cho agentic calls: validate ownership + `course_id` trên mọi tool invocation trước khi cho phép agent tự hành động.

---

## P4 — Polish / theo dõi thêm (không khẩn cấp)

- Chuẩn hoá field trạng thái sang Java enum thật thay vì `String` tự do (rủi ro compile-time thấp nhưng không có bảo vệ khỏi lỗi chính tả) — xem `AUDIT_REPORT.md` MED-05. Đây là thay đổi lớn (touch mọi entity), nên làm dần theo module khi module đó được chạm tới, không làm 1 lần toàn bộ.
- Cân nhắc model hoá lại các quan hệ đang là plain `Long` (`Course.parentId`/`latestVersionId`, `Payment.statementId`, `PathwayNode.parentNodeId`...) thành JPA association thật nếu ERD tooling/tra cứu quan hệ trở thành nhu cầu thường xuyên.
- `JwtProperties` (không được inject thật, `JwtUtils`/`AuthService` tự đọc `@Value` riêng) và double-registration của `GeminiProperties` — dọn khi tiện tay, không đáng 1 task riêng.
- `CourseSessionDTO` đặt tên khác `Section` entity — cân nhắc đổi tên nếu gây nhầm lẫn thật sự khi onboard người mới, không bắt buộc.

---

## Việc rõ ràng CHƯA cần làm (để tránh hiểu nhầm là "còn thiếu")

Những mục này đã được đội ngũ **quyết định giữ nguyên có chủ đích** — không phải nợ kỹ thuật, không nên tự ý "sửa" nếu không có input mới:
- RBAC static/read-only, không xây dựng permission matrix động (quyết định 2026-07-22).
- Course Manager review chỉ kiểm tra trình bày, không kiểm tra chuyên môn nội dung (BR-CRS-01, thiết kế gốc).
- Comment moderation dùng Rule Engine (blacklist + regex), không dùng AI (thiết kế gốc, xem `doc/specs/13-comment-management.md`).
- `GeminiClientService`/`CloudinaryService`/`EmailService` không có unit test riêng — ranh giới mock đã thống nhất nhiều đợt liên tiếp.

---

*Roadmap này nên được cập nhật mỗi khi có quyết định version mới — thêm mục vào đúng nhóm P, không tạo file roadmap riêng mới. Khi 1 mục hoàn thành, chuyển ghi chú tương ứng về `HanGo_Documentation.md` §14 (Decision Log) và xoá khỏi đây.*
