# HanGo — Danh sách lỗi/lỗ hổng cần fix (test-fix-v1)

> **Tổng hợp từ:** `AUDIT_REPORT.md`, `TEST_AUDIT_REPORT.md`, `AUTH_FIX_REPORT.md`, `doc/specs/qa-report-for-dev-team.md`, `doc/specs/unit_test_plan.md` — tất cả các vòng test/audit đã chạy tính tới nay.
> **Ngày tổng hợp:** 2026-08-09. Các mục **🔴 Nghiêm trọng** và phần lớn **🟠 Cao** đã được **đọc lại trực tiếp trên code hiện tại** để xác nhận còn đúng hay đã fix rồi (không copy mù từ báo cáo cũ) — mục nào chưa re-verify được đánh dấu rõ "chưa re-check" để không ai hiểu nhầm là đã xác nhận.
> **Phạm vi bị loại trừ:** vai trò **Trainer Lead / Course Manager đã bị bỏ khỏi hệ thống** — mọi lỗi/gap chỉ liên quan riêng tới vai trò này (dashboard duyệt Course/Exam, Settlement, quản lý Ticket phía Course Manager, `itc-sheet`/`sys-sheet` liên quan) **không đưa vào danh sách dưới đây**, kể cả khi code vẫn còn sót lại — không cần fix cho phạm vi v1 này.

---

## Tóm tắt nhanh

| Mức độ | Số lượng còn mở | Ý nghĩa |
|---|---:|---|
| 🔴 Nghiêm trọng | 2 | Có thể bị khai thác ngay hôm nay, ảnh hưởng bảo mật/tiền bạc |
| 🟠 Cao | 4 | Bug thật hoặc rủi ro lớn, cần fix trước khi release |
| 🟡 Trung bình | 9 | Nợ kỹ thuật / thiếu an toàn nhưng chưa gây hại ngay | 
| 🟢 Thấp | 6 | Dọn dẹp, cosmetic, không ảnh hưởng người dùng thật |
| ✅ Đã fix (không cần làm gì) | 17 | Liệt kê ở cuối để không ai làm lại / hiểu nhầm còn tồn tại |

---

## 🔴 Nghiêm trọng (Critical)

### 1. Trainer có thể tạo/sửa ngân hàng câu hỏi của người khác — thiếu hoàn toàn phân quyền
**File:** `SectionQuestionController.java` (8 endpoint dưới `/api/v1/trainer/**`: liệt kê section, CRUD câu hỏi, tạo nhóm câu hỏi)
**Đã verify lại 2026-08-09:** ✅ còn đúng — grep toàn file, **0 annotation `@PreAuthorize`**, khác với mọi controller Trainer khác trong hệ thống.
**Ảnh hưởng:** Route này không nằm trong danh sách `permitAll()` của `SecurityConfig`, nên chỉ cần **đã đăng nhập** (kể cả role Learner) là gọi được — bất kỳ Learner nào cũng tạo/sửa được câu hỏi trong ngân hàng câu hỏi của Trainer.
**Đề xuất:** Thêm `@PreAuthorize("hasAnyRole('TRAINER','ADMINISTRATOR')")` cho cả 8 endpoint, giống `TrainerQuestionController` đang làm.

### 2. PayOS API key/secret từng bị commit dạng thật, đã lên remote công khai
**File:** lịch sử git, commit `efdd778` (đã lên `origin/dev`)
**Đã verify lại 2026-08-09:** ✅ `DEPLOY_GUIDE.md` hiện tại **đã redact** thành placeholder `YOUR_PAYOS_CLIENT_ID` / `YOUR_PAYOS_API_KEY` / `YOUR_PAYOS_CHECKSUM_KEY` — phần doc đã sửa xong.
**Ảnh hưởng còn lại (chưa xác nhận được từ code):** giá trị thật vẫn còn trong **lịch sử git** trên remote. Nếu 3 khóa PayOS thật đó **chưa được xoay vòng (rotate)** trên PayOS merchant dashboard, đây vẫn là một lỗ hổng đang mở — ai đọc được lịch sử git là lấy được khóa thanh toán thật.
**Đề xuất:** Xác nhận ngay với người giữ tài khoản PayOS xem đã rotate 3 khóa này chưa. Nếu chưa — rotate ngay, bất kể đã có ai lợi dụng hay chưa. Việc xóa khỏi lịch sử git (`git filter-repo`/BFG) là việc phá hoại lịch sử chung, cần có sự đồng ý rõ ràng trước khi làm.

---

## 🟠 Cao (High)

### 3. `ProfileUpdateRequest` không có bất kỳ validation nào (GAP-PROF-03)
**File:** `dto/ProfileUpdateRequest.java`
**Đã verify lại 2026-08-09:** ✅ còn đúng — đọc trực tiếp file, chỉ có `@Data`, không một annotation `@Email`/`@NotBlank`/`@Size` nào.
**Ảnh hưởng:** Cập nhật profile với email sai định dạng, tên rỗng, số điện thoại bậy bạ... đều được chấp nhận và lưu thẳng vào DB.
**Đề xuất:** Thêm `@Email` cho `email`, `@NotBlank` cho `fullName`, `@Size` hợp lý cho các field text — sửa nhanh, rủi ro thấp.

### 4. Không có error contract thống nhất — lộ tên class Java thật cho client
**File:** `GlobalExceptionHandler` (chỉ xử lý `ApiException`, dùng ở 6 file); `CourseController` bắt `RuntimeException` và trả về `e.getClass().getName() + ": " + e.getMessage()`
**Đã verify lại 2026-08-09:** ✅ còn đúng trong `CourseController`.
**Ảnh hưởng:** Payment, Cart, Notification, MonthlyStatement mỗi nơi tự bắt lỗi một kiểu khác nhau (`{"error":...}` vs `{"message":...}` vs lộ nguyên `com.hango.hango_backend...Exception`); không có handler cho lỗi validate (`MethodArgumentNotValidException`) nên rơi về `/error` mặc định của Spring.
**Đề xuất:** Thêm `@ExceptionHandler(Exception.class)` + `@ExceptionHandler(MethodArgumentNotValidException.class)` vào `GlobalExceptionHandler`, chuẩn hóa 1 format response duy nhất cho toàn bộ API.

### 5. Frontend không có HTTP client tập trung — logic gắn JWT lặp lại ~59 lần, 2 nơi lưu session song song
**File:** `lib/services/hango_api.dart`, `lib/data/services/auth_service.dart` + 9 repository/service khác trong `lib/data/`
**Đã verify lại 2026-08-09:** ✅ `dio` khai báo trong `pubspec.yaml` nhưng **0 file import** — xác nhận vẫn dùng `package:http` viết tay ở mọi nơi.
**Ảnh hưởng:** Header `Authorization: Bearer <token>` được gắn thủ công, copy-paste ở 13 file khác nhau — sửa logic auth (vd token hết hạn, tự động refresh) phải sửa 59 chỗ, rất dễ sót. Ngoài ra có 2 nơi lưu session không đồng bộ (`SharedPreferences` vs `flutter_secure_storage`).
**Đề xuất:** Việc lớn, nên làm theo lộ trình riêng (xem `ROADMAP.md`) — không phải fix 1-2 dòng, nhưng cần ghi nhận vì ảnh hưởng tốc độ fix các lỗi liên quan tới token sau này (token mới từ `AUTH_FIX_REPORT.md` — refresh token — chưa có nơi nào tự động gọi refresh khi gặp 401).

### 6. Frontend gần như không có test tự động
**File:** `hango-frontend/test/` — hiện có 4 file (`auth_service_session_test.dart`, `learning_pathway_node_tree_test.dart`, `trainer_ai_question_models_test.dart`, `widget_test.dart`)
**Đã verify lại 2026-08-09:** ✅ tăng nhẹ từ 2 lên 4 file so với lần audit trước, nhưng vẫn gần như 0/67 trang, 0/~15 repository/service class có test.
**Ảnh hưởng:** Luồng đăng nhập, luồng làm bài thi (timer/tự nộp bài) — 2 luồng quan trọng nhất với người dùng cuối — chưa có test tự động nào bảo vệ khỏi regression.
**Đề xuất:** Ưu tiên viết test cho `AuthService` (login/register/OTP) và `take_exam_page.dart` (timer/auto-submit) trước, theo đúng thứ tự đã đề xuất ở `TEST_AUDIT_REPORT.md` §3.

---

## 🟡 Trung bình (Medium)

| # | Vấn đề | Vị trí | Ghi chú |
|---|---|---|---|
| M1 | Course versioning (BR-CRS-03) — trạng thái không rõ ràng | `TrainerDashboardServiceImpl` | Báo cáo cũ nói "hoàn toàn chưa làm", nhưng đọc lại code 2026-08-09 thấy đã có logic `parentId` kiểu "V2 link về V1" — **cần QA test lại từ đầu luồng sửa Course đã Published**, đừng coi đây là gap còn treo 100% như cũ. |
| M2 | Không có Flyway/Liquibase — schema DB thay đổi hoàn toàn thủ công | `pom.xml`, `application.properties` | Tin vui: mặc định `ddl-auto` đã đổi từ `update` sang **`validate`** (an toàn hơn nhiều so với báo cáo cũ) ✅. Nhưng vẫn chưa có migration tool chính thức — thay đổi schema vẫn phải làm tay. |
| M3 | Package `sercurity`, `exeption` bị gõ sai chính tả nhưng đã dùng xuyên suốt codebase | toàn bộ `com.hango.hango_backend` | Đổi tên bây giờ đụng tới rất nhiều file import — nên làm riêng 1 PR, không gộp chung việc khác. Chưa re-check lại lần này. |
| M4 | `CONSTITUTION.md` yêu cầu dùng MapStruct nhưng code không dùng | toàn bộ `service/` | 100% mapping Entity↔DTO viết tay. Chưa re-check lại lần này — nên quyết định: dùng thật hoặc bỏ yêu cầu khỏi doc. |
| M5 | Hầu hết field status/type là `String` thô, không phải enum | `Course.status`, `Payment.status`, `Exam.status`... | Không có bảo vệ lúc compile-time khỏi gõ sai chuỗi trạng thái. Chưa re-check lại lần này. |
| M6 | Nhiều quan hệ dữ liệu là `Long` thô thay vì JPA relation | `Course.parentId`, `Payment.statementId`, `PathwayNode.parentNodeId`... | Hibernate không biết các FK này tồn tại, chỉ được đảm bảo bằng quy ước ở tầng service. Chưa re-check lại lần này. |
| M7 | Frontend có 2 class `Exam` không tương thích nhau | `lib/domain/model/exam_models.dart` vs `lib/domain/entities/exam.dart` | `learner_home_page.dart` import cả 2 cùng lúc — trôi dạt tổ chức code, không phải cố ý. Chưa re-check lại lần này. |
| M8 | Frontend có 2 tầng "services" song song, chưa gộp | `lib/services/` vs `lib/data/services/` | Nguyên nhân gốc của vấn đề #5 (2 nơi lưu session). Chưa re-check lại lần này. |
| M9 | `TrainerQuestionAIService.generatePayload` còn biến dead code (không còn ảnh hưởng hành vi thật) | `TrainerQuestionAIService.java:46-47` | Đã verify 2026-08-09: biến `categoryId`/`difficultyId` tính ở đây **không được dùng tới** (bị `buildUserInput()` tính lại riêng ở dòng 254-255). Tin vui: hành vi thực tế (AI vẫn nhận được default category/difficulty) **đã đúng**, đây chỉ còn là dọn dẹp code thừa, không phải bug chức năng như GAP-QB-01 mô tả ban đầu. |
| M10 | 12 file doc `doc/specs/01,02,04-11-*.md` chưa cập nhật từ 2026-07-16 | `doc/specs/` | Một số bị code hiện tại chứng minh sai (vd claim "Apache POI" trong khi `CourseImportService` tự parse XML thô). Theo nguyên tắc code-first của team, nên cập nhật lại cho khớp code khi có dịp. |

---

## 🟢 Thấp (Low)

| # | Vấn đề | Ghi chú |
|---|---|---|
| L1 | `TestDBController` — endpoint seed dữ liệu test với mật khẩu cứng `12345678` | Đã verify 2026-08-09: **rủi ro đã giảm mạnh** so với báo cáo cũ — giờ có `@Profile("dev")` + `@PreAuthorize(hasRole ADMINISTRATOR)`, không còn mở public như trước. Khuyến nghị gốc (xóa hẳn khỏi build deploy) vẫn chưa làm — nên xóa dứt điểm thay vì chỉ khóa lại, vì nó vẫn có thể ghi đè mật khẩu 1 tài khoản Trainer thật nếu lỡ chạy nhầm ở profile dev. |
| L2 | File rác không còn tham chiếu ở đâu | `lib/_debug_provider_check.dart`, `test.dart`, `test_uri.dart`, `analyze_output.txt`, `test/learning_pathway_node_tree_test.dart` (bản trùng ở root), `CheckDBApp.java`, `response.json`, `TODO_backend_ai.txt` — an toàn để xóa, chưa re-check lại lần này. |
| L3 | `CourseSessionDTO` là DTO của entity `Section` | Đặt tên trôi dạt ("Session" vs "Section"), dễ gây nhầm cho người mới đọc code. |
| L4 | `SecurityUtil.getCurrentUserId()` xử lý 1 nhánh principal không bao giờ xảy ra trong thực tế | Code thừa từ thiết kế auth cũ. |
| L5 | `PathwayReroutePolicyService.PolicyDecision` dùng public mutable field | Không đồng nhất với style Lombok (`@Getter/@Setter/@Builder`) dùng ở mọi nơi khác. |
| L6 | `hango-frontend/README.md` vẫn là boilerplate mặc định của `flutter create` | Chưa từng được viết lại cho riêng HanGo. |

---

## ✅ Đã fix — không cần làm gì thêm

Liệt kê ở đây để tránh làm lại hoặc hiểu nhầm là vẫn còn mở:

1. **CRIT-02** — `CommentController`/`LessonController` từng tin `@RequestParam Long userId` từ client (ai cũng giả danh được người khác để post/sửa/xóa/like comment, sửa quiz attempt). Đã verify 2026-08-09: cả 2 controller giờ dùng `@AuthenticationPrincipal UserDetailsImpl currentUser`, và `SecurityConfig` chỉ `permitAll()` cho method GET trên 2 route này — ghi (POST/PUT/DELETE) bắt buộc phải đăng nhập.
2. **GAP-EXM-01** — `answers` trong lịch sử làm bài thi luôn trả về rỗng do đọc JSON array bằng `Map.class`. Đã verify: giờ đọc đúng bằng `List.class` (dòng 239 `ExamService.java`).
3. **GAP-EXM-02** — Lọc Exam theo status khác PUBLISHED luôn trả rỗng (query 1 status rồi lọc lại chỉ giữ PUBLISHED). Đã verify: code hiện tại query đúng thẳng theo status được truyền vào, không còn lọc lại mâu thuẫn.
4. **GAP-EXM-03** — `saveExamAttempt` tin điểm client gửi lên, không tính lại. Đã verify: có biến `calculatedScore` được set lại cho `attempt.setScore(...)`.
5. **GAP-AUTH-01** — Login không chặn tài khoản status khác `INACTIVE` (vd `LOCKED` vẫn login được). Đã fix trong `AUTH_FIX_REPORT.md` (2026-08-01).
6. **MED-11** — Không có refresh token/logout, chỉ có 1 JWT 24h không thu hồi được. Đã có bảng `refresh_tokens` + endpoint `/refresh-token`, `/logout`.
7. Reset mật khẩu không cần OTP — ai biết email nạn nhân là đổi được mật khẩu. Đã fix (`AUTH_FIX_REPORT.md`, bug Critical mới phát hiện & fix chung đợt).
8. Verify email không cần token — gọi `GET /api/auth/verify?email=...` là tự xác minh được bất kỳ email nào. Đã fix (đổi sang token một lần, hết hạn 24h).
9. Google Login có thể bị giả mạo bằng token không chữ ký hợp lệ. Đã fix (bỏ nhánh fallback `parse()` không kiểm tra chữ ký).
10. Đăng nhập sai không giới hạn số lần (không khóa tài khoản). Đã fix (khóa 15 phút sau 5 lần sai).
11. OTP không giới hạn số lần thử, không có cooldown gửi lại. Đã fix.
12. Không yêu cầu độ phức tạp mật khẩu. Đã fix (bắt buộc hoa/thường/số/ký tự đặc biệt, 8-64 ký tự).
13. So khớp email phân biệt hoa/thường (`Test@a.com` và `test@a.com` đăng ký được 2 tài khoản khác nhau). Đã fix.
14. `forgotPassword` lộ thông tin email có tồn tại trong hệ thống hay không (user enumeration). Đã fix (luôn trả về thông báo chung chung).
15. **HIGH-01 (phần nguy hiểm nhất)** — mặc định `ddl-auto=update` trên production. Đã verify 2026-08-09: mặc định đã đổi thành `validate`.
16. **HIGH-02** — Tài liệu vẫn ghi "VNPay" trong khi hệ thống thật dùng PayOS. Đã fix ở Phase 3 (cập nhật lại các doc chính).
17. **HIGH-07** — `CONSTITUTION.md`/`agent_frontend.md` mô tả kiến trúc Riverpod + go_router không hề tồn tại trong code thật (thực tế là StatefulWidget + setState + 1 Provider gốc). Đã fix ở Phase 3 (doc cập nhật lại đúng thực tế).

---

## Ghi chú về phạm vi loại trừ Trainer Lead / Course Manager

Theo yêu cầu, các phát hiện sau **bị loại khỏi danh sách trên** vì gắn chặt với vai trò Trainer Lead/Course Manager đã bị bỏ:
- Toàn bộ workflow duyệt/publish Course & Exam phía Course Manager (`CourseManagerDashboardServiceImpl`), kể cả phần thiếu test và phần "2 luồng approve/reject Course không nhất quán" (vốn dĩ 1 trong 2 luồng đó chính là của Course Manager).
- `updateExamStatus` không phân role khi Trainer tự publish Exam — trước đây coi là gap vì "lẽ ra phải qua Course Manager duyệt"; giờ Course Manager không còn thì Trainer tự publish là hành vi mặc định, không còn là vấn đề cần fix.
- Endpoint quản lý Ticket phía Course Manager (`ManagementTicketController`), báo cáo Settlement phía Course Manager, các `itc-sheet-*`/`sys-sheet-*` dành riêng cho luồng Course Manager.
- `MED-13` (2 API notification trùng nhau, 1 cái chỉ dành cho `TRAINER_LEAD`) — sẽ tự hết trùng khi phần Course Manager bị gỡ.

Code hiện tại (backend lẫn frontend) **vẫn còn rất nhiều chỗ nhắc tới `TRAINER_LEAD`/`COURSE_MANAGER`** (RBAC, dashboard, sidebar...) — việc dọn code này (xóa hẳn hay giữ làm dead code) không nằm trong phạm vi tài liệu này, chỉ ảnh hưởng tới việc danh sách lỗi ở trên không tính các lỗi riêng của phần đó.
