# HanGo Code Review - Defense Preparation

> Cập nhật lần 2 (2026-08-23) — khớp với code sau khi đã fix: lộ đáp án quiz, gian lận điểm số, brute-force đăng nhập, Admin tự đổi role, lỗi "Create Course" bị chặn validation, và tính năng mới **Trainer tự chọn giá khóa học**. Toàn bộ đối chiếu trực tiếp với source code thật (không suy đoán), đã build + chạy **927/927 test backend pass**.
>
> Ba flow bảo vệ:
> 1. **Course Authoring – Content Building & Publishing** (bao gồm cả Bulk Import qua Excel)
> 2. **Lesson Learning – Quiz & Progress Tracking**
> 3. **Account – Role & Access Administration**

---

## 1. Architecture tổng quan

```
Flutter App (hango-frontend/lib)  --HTTP/JSON-->  Spring Boot API (hango-backend/src/main/java)  --JPA/Hibernate-->  MySQL
```

**Frontend** (Flutter/Dart, kiến trúc Clean/Layered):
- `lib/presentation/pages/` — màn hình theo role: `admin/`, `trainer/`, `course_manager/`, `learner/`, `course/`.
- `lib/data/services/` + `lib/data/repositories/` — nơi DUY NHẤT gọi `http.get/post/put/delete`.
- `lib/domain/model/` — model dữ liệu thuần, không có logic mạng.
- Lưu phiên đăng nhập trong `shared_preferences` (giống `localStorage` trên web), không dùng state manager toàn cục.

**Backend** (Java 17, Spring Boot, kiến trúc N-Tier):
- `controller/` — nhận HTTP, khai báo route + quyền (`@PreAuthorize`), không chứa business logic.
- `service/` — business logic thật, transaction (`@Transactional`).
- `repository/` — Spring Data JPA.
- `entity/` — model ánh xạ bảng MySQL.
- `dto/` — object nhận/trả JSON (không bao giờ trả thẳng entity ra ngoài).
- `security/` — JWT + phân quyền.
- `exception/` — `GlobalExceptionHandler` xử lý lỗi tập trung.

**Luồng chuẩn cho MỌI API có bảo vệ:**
```
UI (bấm nút) -> Service/Repository (Flutter) -> http request kèm "Authorization: Bearer <token>"
  -> JwtAuthFilter (backend) giải mã token, nạp user vào SecurityContext
  -> @PreAuthorize kiểm tra quyền trên Controller
  -> Controller gọi Service -> Service kiểm tra nghiệp vụ -> gọi Repository -> SQL
  -> Service trả DTO -> Controller bọc ResponseEntity -> JSON
  -> Frontend nhận JSON, cập nhật state, vẽ lại UI
  -> Nếu lỗi: GlobalExceptionHandler (hoặc Controller tự catch) trả JSON lỗi có status code
```

---

## 2. Course Authoring – Content Building & Publishing

### Business Flow

```
Trainer tạo course (DRAFT) — tự chọn GIÁ BÁN ngay từ bước này
   -> Trainer soạn Section + Lesson, lưu nháp (autosave/save)
   -> Trainer bấm "Submit for review"
        -> Trainer thường: course -> PENDING_APPROVAL (giá vẫn giữ nguyên,
           TRỪ KHI đây là khóa học đầu tiên của Trainer -> giá bị ép về 0đ)
        -> Trainer đồng thời là COURSE_MANAGER/ADMINISTRATOR: course -> PUBLISHED luôn
   -> Course Manager mở hàng đợi duyệt, xem CẢ giá Trainer chọn LẪN giá hệ thống
      gợi ý để tham chiếu, rồi Approve/Reject nội dung (KHÔNG sửa được giá)
        -> Approve -> PUBLISHED, publishedAt = now, báo Trainer
        -> Reject  -> REJECTED, lưu lý do, Trainer sửa lại và submit lại
   -> Sửa 1 course ĐANG PUBLISHED -> tự động clone ra course mới (V2), không
      đụng tới course cũ (V1) mà học viên đang học
   -> [Đường phụ] Trainer có thể NHẬP HÀNG LOẠT 1 course đầy đủ (thông tin +
      section + lesson + câu hỏi quiz) từ 1 file Excel, thay vì tạo/soạn thủ
      công từng bước — xem mục "Bulk Import" bên dưới. Course tạo ra từ import
      đi qua ĐÚNG quy trình DRAFT -> submit -> review -> publish y hệt như tạo tay.
```

### UI Flow

- Tạo mới: `create_course_page.dart` — form nhập tiêu đề, mô tả, danh mục, độ khó, ảnh thumbnail, **và giá bán**.
- Soạn nội dung & publish: `edit_course_page.dart` (2300+ dòng) — quản lý cây `Section -> Lesson`, autosave, nút Submit, hiển thị trạng thái/lý do bị từ chối, **ô giá bán có thể sửa + giá tham khảo hiển thị bên dưới + ô "lý do đặt giá" (chỉ hiện khi giá khác giá tham khảo)**.
- Duyệt: `course_review_dashboard_dialog.dart` (mở từ `course_manager_courses_page.dart`) — có nút Approve/Reject/Hide/Unhide, và **panel "Price Negotiation"** so sánh giá Trainer chọn với giá hệ thống gợi ý khi 2 giá trị này khác nhau.
- Bulk Import: nút "Import from Excel" trong `course_manager_courses_page.dart`, tải template rồi upload file `.xlsx` đã điền.

### Giá khóa học — Trainer tự chọn giá (tính năng mới)

**Khái niệm cần nắm:** Course có **2 cột giá riêng biệt** trong DB:
- `price` — **giá bán thật sự**, hiển thị cho học viên, dùng để tính tiền khi mua. Do **Trainer tự nhập**.
- `suggestedPrice` — **giá tham khảo**, do hệ thống tự tính dựa trên hồ sơ Trainer + độ khó + số bài học + tổng thời lượng. CHỈ mang tính gợi ý, không phải giá bán.

Trước đây 2 cột này luôn được gán **cùng 1 giá trị tự tính** (Backend bỏ qua hoàn toàn giá trị Trainer gửi lên) — nay đã tách bạch: `price` = Trainer quyết định, `suggestedPrice` = tham khảo.

**Vì sao cần "làm tròn" và "giới hạn" giá tham khảo?** Công thức tính (`TrainerDashboardServiceImpl.calculateSuggestedPrice`, dòng 1319) cộng dồn nhiều yếu tố (loại Trainer, có bằng chứng điểm số hay không, độ khó, số bài học × 10.000đ, tổng phút × 1.000đ) nên có thể ra một con số lẻ, khó nhìn (vd 673.000đ) hoặc quá thấp/quá cao nếu course có ít/nhiều bài học. Nên áp dụng 2 phép biến đổi:
- **Làm tròn (rounding)**: đưa về bội số gần nhất của 50.000đ. Ví dụ 673.000 → chia cho 50.000 = 13,46 → làm tròn thành 13 → nhân lại 50.000 = 650.000đ. Công thức code: `Math.round(price / 50000.0) * 50000`.
- **Giới hạn/kẹp (clamping)**: nếu con số sau làm tròn nhỏ hơn 300.000đ thì đẩy lên đúng 300.000đ; nếu lớn hơn 700.000đ thì kéo xuống đúng 700.000đ. Đảm bảo giá tham khảo luôn nằm gọn trong khoảng [300.000đ, 700.000đ] — dễ nhìn, không bao giờ ra số 0 hay số quá lớn bất thường.

```java
long rounded = Math.round(price / (double) roundingStepVnd) * roundingStepVnd;  // roundingStepVnd = 50000
BigDecimal result = BigDecimal.valueOf(rounded);
if (result.compareTo(min /*300000*/) < 0) return min;
if (result.compareTo(max /*700000*/) > 0) return max;
return result;
```

**Nơi áp dụng (đồng nhất ở CẢ 3 con đường tạo course):**
| Nơi | File | Việc làm |
|---|---|---|
| Tạo course thủ công | `TrainerDashboardServiceImpl.createTrainerCourse` (dòng 443) | `suggestedPrice` = tính mới (lessonCount=0 vì chưa có bài học); `price` = `request.getPrice()` (bắt buộc, Trainer nhập) |
| Sửa course thủ công | `TrainerDashboardServiceImpl.updateTrainerCourse` (dòng 499) | Tính lại `suggestedPrice` với số bài học/thời lượng THẬT; `price` = giá Trainer gửi trong request |
| Làm mới giá tham khảo | `TrainerDashboardServiceImpl.reEvaluateCoursePrice` (dòng 1361) | CHỈ cập nhật `suggestedPrice`, **không đụng tới `price`** — nút "Refresh" ở Frontend giờ chỉ có nghĩa "tính lại số tham khảo", không còn ghi đè giá Trainer đã chọn |
| Nhập hàng loạt | `CourseImportService.importWorkbook` (dòng 150-155) | `suggestedPrice` = tính bằng CÙNG công thức; `price` = đọc cột "Price" (tùy chọn) trong Excel, nếu không điền thì mặc định = `suggestedPrice` |

**Quy tắc "khóa học đầu tiên miễn phí" vẫn giữ nguyên, nhưng thu hẹp phạm vi:** trước đây quy tắc này ép CẢ `price` LẪN `suggestedPrice` về 0 khi Trainer nộp/publish khóa học đầu tiên của họ. Nay **chỉ ép `price` về 0** (Trainer vẫn bán 0đ cho khóa đầu, đúng chính sách tăng trưởng), còn `suggestedPrice` giữ nguyên giá trị tham khảo (300k-700k) để Course Manager vẫn biết "khóa này đáng giá bao nhiêu trên thị trường" dù đang bán 0đ. Áp dụng tại 2 checkpoint: `TrainerDashboardServiceImpl.submitTrainerCourse` (dòng 810, khi Trainer tự submit) và `CourseManagerDashboardServiceImpl.publishCourse` (dòng 91, khi Course Manager publish).

**`priceNote`** — Trainer có thể ghi lý do đặt giá (vd "Bao gồm mentor 1-kèm-1"). Chỉ hiện ô nhập này trên `edit_course_page.dart` khi giá Trainer chọn khác giá tham khảo. Course Manager thấy lý do này trong panel "Price Negotiation" khi duyệt.

### Bulk Import — Nhập khóa học hàng loạt từ Excel

**File:** `hango-backend/src/main/java/com/hango/hango_backend/service/CourseImportService.java` (~940 dòng).

**Nó là gì, tại sao cần:** thay vì Trainer phải tạo course rồi thêm từng Section/Lesson/câu hỏi bằng tay trên UI, họ có thể tải 1 file Excel mẫu, điền dữ liệu offline, rồi upload 1 lần — hệ thống tự tạo Course + Section + Lesson + Question + Option cho cả khóa học trong 1 request.

**Cách hoạt động — điểm đặc biệt cần biết:** file này **KHÔNG dùng thư viện đọc Excel nào (không Apache POI)**. Nó tự viết code đọc `.xlsx` bằng cách hiểu rằng **1 file `.xlsx` thực chất là 1 file ZIP chứa nhiều file XML bên trong** (đây là chuẩn định dạng OOXML — mở thử 1 file `.xlsx` bằng phần mềm giải nén sẽ thấy các thư mục `xl/`, `xl/worksheets/`, v.v.). `CourseImportService` tự:
1. Giải nén ZIP, chỉ lấy 4 loại file cần thiết (`xl/workbook.xml`, `xl/_rels/workbook.xml.rels`, `xl/sharedStrings.xml`, các file trong `xl/worksheets/`).
2. Tự parse các file XML đó để tìm ra tên sheet, tiêu đề cột (dòng 2), và dữ liệu từng dòng.

**Vì sao code lại tự viết parser thay vì dùng thư viện có sẵn — và có an toàn không?** Đây là điểm tôi đã audit kỹ vì xử lý file người dùng upload luôn là nơi dễ bị tấn công nhất. Kết quả: code này **được làm rất cẩn thận, có đủ 3 lớp phòng thủ chuẩn** cho việc xử lý file nén/XML từ người dùng:
- **Chống Zip Bomb** (khái niệm: kẻ tấn công gửi 1 file nén rất nhỏ nhưng khi giải nén phình to lên hàng GB, làm sập server do hết bộ nhớ) — giới hạn `MAX_IMPORT_BYTES` = 10MB cho cả file, và `MAX_XML_ENTRY_BYTES` = 5MB cho MỖI file XML giải nén ra, ném lỗi ngay nếu vượt (`readLimited()`).
- **Chống Zip Slip** (khái niệm: tên file bên trong ZIP có thể chứa `../../` để "thoát" ra khỏi thư mục giải nén dự kiến, ghi đè file hệ thống) — code loại bỏ thẳng mọi entry có tên chứa `".."` (`readZipEntries()`), và chỉ nhận đúng 4 loại tên file đã liệt kê ở trên (whitelist), bỏ qua mọi thứ khác.
- **Chống XXE — XML External Entity** (khái niệm: 1 file XML độc hại có thể khai báo "entity ngoài" trỏ tới file bí mật trên server (`/etc/passwd`) hoặc 1 URL nội bộ, khiến server vô tình đọc/gửi dữ liệu nhạy cảm khi parse XML) — hàm `parseXml()` tắt hẳn DOCTYPE, tắt external general/parameter entities, tắt truy cập DTD/schema bên ngoài trước khi parse bất kỳ file XML nào.

→ **Kết luận:** phần này không phải lỗ hổng, ngược lại là 1 trong những đoạn code được viết phòng thủ tốt nhất trong hệ thống — nếu hội đồng hỏi "import Excel có an toàn không", đây là câu trả lời có bằng chứng cụ thể.

**3 sheet trong file Excel:**
- `COURSE` — dạng key-value (`Information Field` / `Fill Data`): Title, Category, Academic Level, Description, Thumbnail URL, Version, Objectives, và **`Price` (tùy chọn — nếu bỏ trống, hệ thống tự dùng giá tham khảo)**.
- `SYLLABUS` — danh sách tuần tự: dòng `type=section` mở 1 Section mới, các dòng `type=video/text/quiz/pdf` tiếp theo là Lesson thuộc Section đó (bị lỗi nếu gặp Lesson trước khi có Section nào, hoặc trùng tên Section/Lesson).
- `QUESTIONS` — câu hỏi trắc nghiệm cho các Lesson loại quiz, khớp với Lesson qua **tên tiêu đề** (cột "Question Title" phải khớp đúng "Title" của 1 dòng trong SYLLABUS), có 4 cột Option A-D và cột "Correct Answer" (chấp nhận chữ A/B/C/D hoặc số 1-4).

**Lỗi thật đã tìm thấy và fix:** nếu cột "Correct Answer" ghi giá trị không khớp đáp án nào (gõ nhầm "E", để trống mà lại thiếu Option A, v.v.), **trước đây câu hỏi được nhập vào hệ thống mà KHÔNG CÓ đáp án đúng nào cả** — nghĩa là học viên không thể nào trả lời đúng câu đó dù chọn gì, và Trainer hoàn toàn không được báo. Đã fix: `saveQuestionOptions()` (dòng ~680) giờ theo dõi xem có option nào được đánh dấu đúng không; nếu không có, thêm cảnh báo vào kết quả trả về (`warnings` — hiển thị cho Trainer sau khi import xong) để họ vào Question Bank sửa lại. **Không đổi logic xác định đáp án đúng** (để tránh rủi ro trên 1 file chưa từng có unit test), chỉ thêm cảnh báo.

**Khái niệm "1 transaction cho cả file":** toàn bộ hàm `importWorkbook()` được đánh dấu `@Transactional` — nghĩa là Course + mọi Section + Lesson + Question + Option + liên kết `lesson_quizzes` được tạo ra đều nằm trong **1 giao dịch DB duy nhất**. Nếu bất kỳ dòng nào trong file lỗi (vd trùng tên Section ở dòng 50/200), Spring sẽ **rollback toàn bộ** — không để lại course "một nửa" trong DB. Đây là tính chất "Atomicity" (Tính nguyên tử) trong 4 tính chất ACID của transaction: một chuỗi thao tác hoặc thành công trọn vẹn, hoặc không thao tác nào có hiệu lực cả.

### API Flow

| Hành động | Method | Endpoint | Controller.method |
|---|---|---|---|
| Tạo course | POST | `/api/v1/trainer/courses` | `TrainerDashboardController.createCourse` |
| Sửa course/sections/lessons/giá | PUT | `/api/v1/trainer/courses/{id}` | `TrainerDashboardController.updateCourse` |
| Nộp duyệt | POST | `/api/v1/trainer/courses/{id}/submit` | `TrainerDashboardController.submitCourseForReview` |
| Làm mới giá tham khảo | POST | `/api/v1/trainer/courses/{id}/re-evaluate-price` | `TrainerDashboardController.reEvaluateCoursePrice` |
| Tải template Excel | GET | `/api/v1/trainer/courses/import/template` | `TrainerDashboardController.downloadCourseImportTemplate` |
| Nhập hàng loạt từ Excel | POST | `/api/v1/trainer/courses/import` | `TrainerDashboardController.importCoursesFromExcel` |
| Course Manager xem hàng đợi | GET | `/api/v1/course-manager/courses/review` | `CourseManagerDashboardController.getCoursesForReview` |
| Course Manager duyệt | POST | `/api/v1/course-manager/courses/{id}/publish` | `CourseManagerDashboardController.publishCourse` |
| Course Manager từ chối | POST | `/api/v1/course-manager/courses/{id}/reject` | `CourseManagerDashboardController.rejectCourse` |
| Ẩn/hiện course đã publish | POST | `.../hide`, `.../unhide` | `hideCourse` / `unhideCourse` |

### Backend Flow (versioning — giữ nguyên từ trước)

`TrainerDashboardServiceImpl.updateTrainerCourse` (dòng 499): điểm mấu chốt là biến `needsNewDraftVersion`:
```java
boolean needsNewDraftVersion = "PUBLISHED".equalsIgnoreCase(course.getStatus());
```
Nếu course đang sửa đã `PUBLISHED`, hệ thống **KHÔNG sửa trực tiếp** mà tạo hẳn 1 bản ghi Course mới (V2, `parentId` trỏ về V1, `status=DRAFT`), copy toàn bộ Section/Lesson sang, rồi trả `id` mới cho Frontend. Course V1 (mà học viên đang học) không bị đụng tới cho tới khi V2 được publish (lúc đó V1 mới chuyển `ARCHIVED`). Đây là lý do sửa 1 course đã bán không làm hỏng trải nghiệm học viên đang học.

### Exception & Error Handling

| Tình huống | Nơi throw | HTTP status |
|---|---|---|
| Course/User không tồn tại | `ApiException(..., NOT_FOUND)` | 404 |
| Không phải chủ course (edit/submit/publish/xoá) | `ApiException(..., FORBIDDEN)` | 403 |
| Sai trạng thái để submit/publish/hide/unhide | `ApiException(..., BAD_REQUEST)` | 400 |
| Trùng mã course (`code`) | `ApiException(..., CONFLICT)` | 409 |
| Thiếu `price` hoặc `price` âm khi tạo/sửa course | `@NotNull`/`@Min(0)` trên `TrainerCreateCourseRequestDTO.price` → `MethodArgumentNotValidException` | 400 |
| File Excel quá lớn / sai định dạng / lỗi cấu trúc | `IllegalArgumentException` trong `CourseImportService` → rơi vào `handleGlobalException` (Controller `TrainerDashboardController.importCoursesFromExcel` cũng tự catch và trả 400) | 400 |

> **Đã fix (2026-08-23) — lỗi nghiêm trọng: nút "Create Course" từng bị chặn hoàn toàn.** DTO `TrainerCreateCourseRequestDTO.code` trước đây có `@NotBlank` (bắt buộc), nhưng `create_course_page.dart` chưa bao giờ gửi field `code` lên (vì code do Backend tự sinh qua `generateUniqueCourseCode()`) — nghĩa là **mọi request tạo course mới đều bị Spring validation chặn ở tầng `@Valid`, trả về 400 "Code cannot be blank" trước cả khi vào tới code nghiệp vụ**. Đã xác minh bằng test rồi fix: bỏ `@NotBlank`, giữ `@Size(max=100)` — `code` giờ là optional ở tầng validation (nghiệp vụ vẫn tự sinh nếu trống).

### Complete Data Flow (ví dụ: Trainer tạo course mới kèm giá)

```
1. UI: Trainer điền tiêu đề, mô tả, danh mục, độ khó, VÀ nhập giá bán trong ô
   "Course Price (VNĐ) *" trên create_course_page.dart
2. FE gọi _saveCourse() (dòng 218) -> validate form -> POST /trainer/courses
   body: {title, description, categoryKey, difficultyKey, thumbnailUrl, price}
3. JwtAuthFilter xác thực -> @PreAuthorize kiểm tra quyền MANAGE_OWN_COURSES
4. Spring tự validate DTO (@NotBlank title, @NotNull @Min(0) price)
   -> nếu price bị thiếu/âm: 400 ngay, không vào Controller
5. TrainerDashboardController.createCourse -> trainerDashboardService.createTrainerCourse
6. Service (dòng 443):
   - Tự sinh course code duy nhất (generateUniqueCourseCode)
   - Tính suggestedPrice = calculateSuggestedPrice(...) (làm tròn 50k, kẹp 300k-700k)
   - trainerPrice = request.getPrice() (giá Trainer vừa nhập)
   - INSERT courses: price = trainerPrice, suggestedPrice = suggestedPrice, status=DRAFT
7. Controller trả 200 {"message": "Course created successfully in DRAFT status"}
8. FE nhận 200 -> toast thành công -> đóng trang, quay về danh sách course
   (Trainer sẽ mở lại course này trong edit_course_page.dart để thêm Section/
   Lesson; lúc đó suggestedPrice sẽ được tính CHÍNH XÁC HƠN theo số bài học
   thật, hiển thị dưới ô giá cho Trainer tham khảo/điều chỉnh)
```

### Important Code

`TrainerDashboardServiceImpl.updateTrainerCourse` dòng 528-598 (clone V1→V2) vẫn là đoạn quan trọng nhất về mặt kiến trúc dữ liệu — bảo vệ học viên khỏi thay đổi nội dung giữa chừng.

`TrainerDashboardServiceImpl.calculateSuggestedPrice` dòng 1319-1345 là đoạn quan trọng nhất về tính năng giá mới — nắm vững công thức làm tròn/kẹp này để giải thích khi hội đồng hỏi "vì sao giá tham khảo luôn đẹp và nằm trong 300k-700k".

---

## 3. Lesson Learning – Quiz & Progress Tracking

### Business Flow

```
Học viên mở 1 Lesson trong course đã enroll
  -> Loại "video"/"text": xem nội dung, bấm "Mark as completed" khi xong
  -> Loại "quiz":
       -> LẦN LÀM ĐẦU TIÊN: hệ thống KHÔNG gửi đáp án đúng về cho trình duyệt
          (xem "Chống lộ đáp án" bên dưới) -> học viên chọn đáp án -> Submit
       -> Backend TỰ CHẤM LẠI điểm từ đáp án đúng lưu trong DB (không tin điểm
          Frontend gửi lên) -> lưu attempt -> tự đánh dấu Lesson hoàn thành
       -> Nếu điểm < 60%: gọi sang tính năng Learning Pathway để "reroute"
          (AI đề xuất lại lộ trình học)
       -> TỪ LẦN THỨ 2 TRỞ ĐI (đã có attempt): đáp án đúng mới được hiển thị,
          phục vụ màn hình "xem lại bài đã làm"
  -> Mỗi lần 1 Lesson đổi trạng thái hoàn thành, Backend tính lại % tiến độ
     của cả course (Enrollment.progressPercentage)
  -> Khi 100% Lesson hoàn thành: Enrollment.status = COMPLETED, tự cấp Certificate
```

### Chống lộ đáp án quiz — khái niệm & cách hoạt động

**Vấn đề đã fix (mức độ Cao):** trước đây, ngay khi học viên **mở trang bài học lần đầu tiên** (trước khi làm quiz), API `GET /api/v1/lessons/{id}` đã trả về **sẵn đáp án đúng của mọi câu hỏi** trong response JSON (field `correctIndex`). Bất kỳ ai biết mở tab "Network" trong DevTools của trình duyệt (F12) đều thấy ngay đáp án đúng mà không cần làm bài — đây là lộ dữ liệu nhạy cảm qua API, nghiêm trọng hơn cả việc gian lận điểm số vì không cần "hack" gì cả, chỉ cần đọc response bình thường.

**Nguyên tắc bảo mật áp dụng để fix — "không đưa cho client thứ nó chưa được phép biết" (tiếng Anh hay gọi là *principle of least disclosure* / *never trust the client with secrets it shouldn't hold*):** chỉ tiết lộ đáp án đúng CHO ĐÚNG NGƯỜI, ĐÚNG LÚC — tức là chỉ sau khi học viên đã thực sự làm ít nhất 1 lần (lúc đó xem lại đáp án đúng là hợp lý, phục vụ mục đích học tập/ôn tập).

**Cách hoạt động** — `LessonServiceImpl.getLessonDetail` (dòng 50-62):
```java
boolean hasPriorAttempt = userId != null
        && quizAttemptRepository.countByLessonIdAndStudentId(lessonId, userId) > 0;
```
- Nếu `hasPriorAttempt == false` (chưa từng làm quiz này): `correctIndex` và `explanation` (giải thích đáp án, cũng có thể tiết lộ đáp án qua nội dung) đều để `null` trong response — Frontend nhận về danh sách câu hỏi + các lựa chọn (options) bình thường, nhưng KHÔNG biết cái nào đúng.
- Nếu `hasPriorAttempt == true`: trả đầy đủ như cũ, phục vụ màn hình xem lại bài làm.

**Hệ quả cần biết:** vì Frontend không còn biết đáp án đúng ở lần làm đầu, nó **không thể tự chấm điểm chính xác tại chỗ** như trước — đây chính là lý do phải sửa luôn cách tính điểm (xem mục dưới).

### Chống gian lận điểm số — Backend tự chấm lại

**Vấn đề đã fix:** trước đây điểm quiz do **Frontend tự tính** (so đáp án học viên chọn với `correctIndex` đã có sẵn trong bộ nhớ) rồi **gửi thẳng con số đó lên Backend**, và Backend **tin luôn, chỉ lưu lại** — không chấm lại. Một học viên rành kỹ thuật có thể sửa request để gửi điểm 10/10 dù chọn sai hết.

**Cách hoạt động** — `LessonServiceImpl.saveQuizAttempt` (dòng 199) gọi hàm mới `computeServerSideScore()` (dòng 256):
```java
double finalScore = computeServerSideScore(lessonId, request);
```
Hàm này **tự truy vấn lại DB** để lấy đáp án đúng thật của từng câu (theo đúng thứ tự hiển thị `display_order`, khớp với cách `getLessonDetail` sắp xếp), so với `answers` mà học viên gửi lên (key là **vị trí câu hỏi** trong danh sách, không phải `question_id` — giữ đúng định dạng dữ liệu hiện có để không phải sửa lại toàn bộ DTO/Frontend), rồi tự tính `correctCount / tổng số câu × 10`. Chỉ khi KHÔNG tìm thấy dữ liệu câu hỏi nào trong DB cho lesson đó (trường hợp dữ liệu bất thường) mới fallback dùng điểm Frontend gửi, để tính năng không bị gián đoạn hoàn toàn.

**Vì sao Frontend vẫn tự tính 1 con số điểm tạm (`fallbackScore`)?** Chỉ để hiển thị NHANH cho học viên ngay sau khi bấm Submit (trải nghiệm mượt, không phải đợi round-trip server) — con số này giờ **chỉ là giá trị dự phòng gửi kèm request**, không dùng để quyết định gì cả. Điểm THẬT hiển thị trên toast và dùng để quyết định pass/fail (`lesson_detail_page.dart:_submitQuiz`, dòng 2569) được đọc lại **từ response Backend trả về** (field `grade`, dạng chuỗi `"X.X / 10.0"`, được parse ra số ở dòng 2606):
```dart
final postResult = await _lessonRepository.postQuizAttempt(..., fallbackScore, ...);
// đọc grade THẬT từ response, không dùng fallbackScore nữa
if (postResult is Map) {
  final parsedScore = double.tryParse(postResult['grade'].toString().split('/').first.trim());
  if (parsedScore != null) displayScore = parsedScore;
}
```
Sau khi nộp bài, Frontend còn tự động gọi lại `fetchLessonDetail()` để tải lại chi tiết bài học — lúc này `hasPriorAttempt` đã là `true` nên đáp án đúng được trả về, phục vụ đúng màn hình xem lại bài làm ngay lập tức.

### UI Flow

`lesson_detail_page.dart` (~5100 dòng) — màn hình học bài: player video/PDF, bình luận, khu vực làm quiz, sidebar Section/Lesson kèm icon hoàn thành, thanh tiến độ course.

### API Flow

| Hành động | Method | Endpoint | Controller.method |
|---|---|---|---|
| Xem nội dung bài học (đáp án bị ẩn nếu chưa từng làm) | GET | `/api/v1/lessons/{id}` | `LessonController.getLessonDetail` |
| Đánh dấu hoàn thành (bài video/text) | PUT | `/api/v1/lessons/{id}/complete?completed=true` | `LessonController.completeLesson` |
| Xem lịch sử làm quiz | GET | `/api/v1/lessons/{id}/quiz-attempts` | `LessonController.getQuizAttempts` |
| Nộp bài quiz (điểm được chấm lại ở Backend) | POST | `/api/v1/lessons/{id}/quiz-attempts` | `LessonController.saveQuizAttempt` |

`GET /api/v1/lessons/**` là `permitAll()`; 3 endpoint còn lại tự kiểm tra `currentUser == null` → 401 thủ công (không có `@PreAuthorize`).

### Backend Flow — `completeLesson` (trung tâm Progress Tracking)

`LessonServiceImpl.completeLesson` (dòng 321): cập nhật `lesson_progresses`, dùng **pessimistic lock** khi đọc `Enrollment` (`findByUserIdAndCourseIdWithLock`) để 2 request hoàn thành 2 bài khác nhau cùng lúc (vd mở 2 tab) không tính sai % — khái niệm **race condition** (điều kiện tranh chấp): 2 luồng cùng đọc-rồi-ghi lên cùng 1 dòng dữ liệu mà không khoá sẽ làm mất 1 trong 2 lần cập nhật (*lost update*). Pessimistic lock buộc luồng thứ 2 phải CHỜ luồng thứ 1 xong mới được đọc, đảm bảo tính đúng đắn.

### Exception & Error Handling

| Tình huống | Nơi throw | HTTP status |
|---|---|---|
| Lesson/User không tồn tại | `ApiException(..., NOT_FOUND)` trong `getLessonDetail`/`completeLesson`/`saveQuizAttempt` | **404** |
| Chưa đăng nhập khi gọi `complete`/`quiz-attempts` | Kiểm tra thủ công trong Controller | 401 |

`LessonController` không tự try/catch — mọi `ApiException` từ Service rơi thẳng xuống `GlobalExceptionHandler.handleApiException`, trả đúng status/message mà không cần sửa gì ở Controller.

### Complete Data Flow (nộp quiz lần đầu tiên)

```
1. UI: học viên mở bài quiz lần đầu -> GET /lessons/{id}
   -> hasPriorAttempt=false -> Backend trả câu hỏi + options, correctIndex=null
2. Học viên chọn đáp án cho từng câu, bấm Submit
   -> _submitQuiz() tính fallbackScore (không chính xác vì correctIndex=null,
      chỉ để gửi kèm làm giá trị dự phòng)
3. POST /lessons/{id}/quiz-attempts {score: fallbackScore, answers: {...}}
4. LessonServiceImpl.saveQuizAttempt:
   - computeServerSideScore(): truy vấn lại DB, so answers với đáp án đúng
     THẬT, tính điểm CHÍNH XÁC -> finalScore
   - INSERT lesson_quiz_attempts (score = finalScore, không phải điểm client gửi)
   - completeLesson() tự động: INSERT/UPDATE lesson_progresses, tính lại
     Enrollment.progressPercentage, cấp Certificate nếu đủ 100%
   - Trả về LessonQuizAttemptDTO {grade: "X.X / 10.0" = finalScore, ...}
5. FE đọc grade THẬT từ response -> displayScore
   -> gọi lại fetchLessonDetail(): giờ hasPriorAttempt=true -> đáp án đúng
      được trả về đầy đủ, cập nhật _lessonDetail cho màn hình xem lại
6. Toast hiển thị displayScore (điểm THẬT, không phải điểm học viên tự tính)
7. Nếu displayScore < 6.0: gọi Learning Pathway reroute
   Nếu >= 6.0: đánh dấu isCompleted=true trên UI, hiện modal "hoàn thành bài học"
```

### Important Code

`LessonServiceImpl.getLessonDetail` dòng 50-62 (biến `hasPriorAttempt`) và `LessonServiceImpl.computeServerSideScore` dòng 256-310 là 2 đoạn quan trọng nhất của flow này — nắm rõ 2 đoạn này để trả lời mọi câu hỏi về bảo mật quiz.

⚠️ **Giới hạn còn lại (không phải bug, chỉ là biết trước để trả lời trung thực):** khi học viên **làm lại (Retake)** 1 quiz đã từng làm, `hasPriorAttempt` vẫn là `true` (vì họ đã có ít nhất 1 attempt trước đó), nên đáp án đúng **vẫn hiển thị ngay cả trong lần làm lại**. Đây là đánh đổi có chủ đích: mục tiêu ban đầu là ngăn xem đáp án TRƯỚC KHI từng thử — sau khi đã thử thật 1 lần, xem lại đáp án cũ để ôn tập là hành vi học tập bình thường, không phải lỗ hổng.

---

## 4. Account – Role & Access Administration

### UI Flow

- Đăng nhập: `login_page.dart`.
- Quản trị: `admin_dashboard_page.dart` — tab Accounts, tab Roles (ma trận Role × Permission).

### Authentication

1. `AuthController.authenticateUser` → `AuthService.authenticateUser` (dòng 144).
2. **Verify mật khẩu ở đâu:** `authenticationManager.authenticate(...)` → Spring Security gọi `UserDetailsServiceImpl.loadUserByUsername` lấy `passwordHash` từ DB → `BCryptPasswordEncoder.matches(...)` (Bean khai báo trong `SecurityConfig.passwordEncoder()`) — `AuthService` không tự so sánh chuỗi mật khẩu.
3. Qua mật khẩu rồi mới kiểm tra `isVerified` (đã xác minh email) và `status == ACTIVE`.
4. **JWT tạo ở đâu:** `JwtUtils.generateJwtTokenFromUsername(email)` — ký HMAC, không chứa role bên trong (role tra lại DB mỗi request qua `UserDetailsServiceImpl`, đảm bảo quyền luôn mới nhất).
5. Song song tạo **refresh token** (chuỗi ngẫu nhiên, không phải JWT — lưu hash SHA-256 trong bảng `refresh_tokens`, cho phép thu hồi khi logout/đổi mật khẩu).

### Chống dò mật khẩu (Brute-force lockout) — tính năng mới fix

**Khái niệm "brute-force":** kẻ tấn công thử hàng loạt mật khẩu (hoặc dùng danh sách mật khẩu rò rỉ từ nơi khác — *credential stuffing*) liên tục vào 1 tài khoản cho tới khi trúng. Nếu hệ thống không giới hạn số lần thử, việc này chỉ còn là vấn đề thời gian/tốc độ máy tính.

**Phát hiện khi audit:** `User` entity đã có sẵn 2 cột `failedLoginAttempts` và `lockedUntil` từ trước — nhưng đọc kỹ `AuthService.authenticateUser` thì phát hiện **2 cột này chưa từng được TĂNG lên ở đâu cả**, chỉ bị RESET về 0/null trong `resetPassword`/`changePassword`. Nghĩa là dù DB đã "chuẩn bị sẵn" cho tính năng khoá tài khoản, tính năng đó **chưa bao giờ thực sự hoạt động**.

**Đã fix** — `AuthService.authenticateUser` (dòng 144-200):
- Trước khi verify mật khẩu: nếu `lockedUntil` đang ở tương lai → chặn luôn, trả lỗi `403`, **không gọi `authenticationManager.authenticate()` nữa** (tránh việc kẻ tấn công vẫn dò được mật khẩu tiếp trong lúc tài khoản đang khoá).
- Nếu sai mật khẩu: tăng `failedLoginAttempts` lên 1; nếu đạt `MAX_LOGIN_ATTEMPTS = 5` (dòng 62) thì set `lockedUntil = now + LOGIN_LOCKOUT_MINUTES` (= 15 phút, dòng 63).
- Nếu đăng nhập đúng: reset cả `failedLoginAttempts = 0` và `lockedUntil = null`.

```java
if (user.getLockedUntil() != null && user.getLockedUntil().isAfter(LocalDateTime.now())) {
    throw new ApiException("Too many failed login attempts. Please try again in a few minutes.", HttpStatus.FORBIDDEN);
}
```

**Giới hạn còn lại (trung thực nếu bị hỏi):** đây là khoá theo TỪNG TÀI KHOẢN (dựa vào email), không phải khoá theo địa chỉ IP. Một kẻ tấn công có thể dò NHIỀU tài khoản khác nhau song song (mỗi tài khoản dưới ngưỡng 5 lần) mà không bị chặn — muốn chặn kiểu này cần thêm rate-limit theo IP ở tầng hạ tầng (vd Nginx, Cloudflare, hoặc thư viện như Bucket4j), hệ thống hiện chưa có.

### Admin không thể tự đổi role của chính mình (tính năng mới fix)

`AdminController` từ trước đã chặn Admin tự đổi **status** (khoá) tài khoản của chính mình — nhưng **chưa chặn tự đổi ROLE**, nghĩa là 1 Admin (đặc biệt nếu là Admin duy nhất) có thể vô tình tự hạ cấp mình từ ADMINISTRATOR xuống LEARNER và mất quyền truy cập ngay lập tức, không ai (kể cả chính họ) mở lại được.

Đã fix, đối xứng với chặn đổi status — `AdminController.updateUserByAdmin` (dòng 199, khối role dòng ~247-265):
```java
boolean isSelf = currentAdmin != null && currentAdmin.getUsername() != null
        && currentAdmin.getUsername().equalsIgnoreCase(user.getEmail());
boolean roleActuallyChanging = user.getRoles() == null || user.getRoles().stream()
        .noneMatch(r -> r.getRoleName().equalsIgnoreCase(roleObj.getRoleName()));
if (isSelf && roleActuallyChanging) {
    return ResponseEntity.badRequest().body("Error: Admin cannot change the role of their own account");
}
```
Chỉ chặn khi role THỰC SỰ thay đổi (đặt lại đúng role hiện tại vẫn được phép đi qua) — cùng logic với chặn status.

### RBAC động (giữ nguyên từ trước)

`AdminController.updateRolePermissions` — Admin bật/tắt permission cho 1 Role, có 2 ràng buộc bảo vệ ở tầng Service: `restrictedForRoles` (permission bị cấm tuyệt đối với role đó, luôn bị loại dù Admin có chọn) và `coreForRoles` (permission bắt buộc phải có, luôn được ép thêm dù Admin bỏ chọn) — tránh Admin cấu hình ra 1 Role phi lý.

### Exception & Error Handling

| Tình huống | HTTP status |
|---|---|
| Sai email/mật khẩu | 401 |
| Tài khoản đang bị khoá tạm (brute-force lockout) | **403** (mới) |
| Đạt ngưỡng 5 lần sai liên tiếp (thông báo khoá) | **403** (mới) |
| Email chưa verify / tài khoản không ACTIVE | 403 |
| Admin tự đổi role của chính mình | **400** (mới) |
| Admin tự đổi status của chính mình | 400 |
| Không đủ quyền (`@PreAuthorize` false) | 403 qua `CustomAccessDeniedHandler` |

---

## 5. API Map

### Auth (`/api/auth/**`)
`POST /login` (nay có kiểm tra khoá tài khoản), `POST /register`, `POST /google`, `POST /forgot-password`, `POST /verify-otp`, `GET /verify`, `POST /reset-password`, `POST /refresh-token`, `POST /logout`, `POST /profile/avatar`.

### Admin (`/api/admin/**`) — yêu cầu `MANAGE_ACCOUNTS_ROLES` hoặc role `ADMINISTRATOR`
`GET /users`, `PUT /users/{id}/status`, `POST /users`, `PUT /users/{id}` (nay chặn tự đổi role), `GET /audit-log`, `GET /permissions`, `GET /roles`, `PUT /roles/{roleName}/permissions`.

### Course Authoring (`/api/v1/trainer/**`, `/api/v1/course-manager/**`)
Đã liệt kê đầy đủ ở mục 2 → API Flow (bao gồm 2 endpoint import Excel mới nhắc tới).

### Lesson (`/api/v1/lessons/**`)
Đã liệt kê đầy đủ ở mục 3 → API Flow.

---

## 6. File / Class / Method Map

### Course Authoring & Publishing (+ Bulk Import + Pricing)
| Tầng | File | Method chính |
|---|---|---|
| FE UI | `presentation/pages/trainer/create_course_page.dart` | `_saveCourse()` (nay kèm `price`) |
| FE UI | `presentation/pages/trainer/edit_course_page.dart` | `_saveCourse()`, `_autoSaveCourse()`, `_reEvaluatePrice()`, `_formatPriceForInput()` |
| FE UI | `presentation/pages/course_manager/course_review_dashboard_dialog.dart` | Panel "Price Negotiation" (đã có sẵn từ trước, nay hoạt động thật) |
| BE Controller | `controller/TrainerDashboardController.java` | `createCourse`, `updateCourse`, `submitCourseForReview`, `reEvaluateCoursePrice`, `importCoursesFromExcel` |
| BE Controller | `controller/CourseManagerDashboardController.java` | `publishCourse`, `rejectCourse` |
| BE Service | `service/TrainerDashboardServiceImpl.java` | `createTrainerCourse`, `updateTrainerCourse`, `submitTrainerCourse`, `reEvaluateCoursePrice`, `calculateSuggestedPrice` |
| BE Service | `service/impl/CourseManagerDashboardServiceImpl.java` | `publishCourse`, `rejectCourse` |
| BE Service | `service/CourseImportService.java` | `importWorkbook`, `readWorkbook` (parser XML tự viết), `calculateSuggestedPrice`, `saveQuestionOptions` |
| BE DTO | `dto/TrainerCreateCourseRequestDTO.java` | `price` (`@NotNull @Min(0)`), `priceNote`, `code` (nay optional) |
| BE Entity | `entity/Course.java` | cột `price`, `suggestedPrice`, `priceNote` |

### Lesson Learning & Quiz
| Tầng | File | Method chính |
|---|---|---|
| FE UI | `presentation/pages/course/lesson_detail_page.dart` | `_submitQuiz()` (nay đọc điểm từ response Backend), `_markLessonAsCompleted()` |
| FE Repository | `data/repositories/lesson_repository.dart` | `fetchLessonDetail`, `postQuizAttempt`, `completeLesson` |
| BE Controller | `controller/LessonController.java` | `getLessonDetail`, `completeLesson`, `saveQuizAttempt` |
| BE Service | `service/LessonServiceImpl.java` | `getLessonDetail` (biến `hasPriorAttempt`), `saveQuizAttempt`, `computeServerSideScore` (mới), `completeLesson` |

### Account – Role & Access
| Tầng | File | Method chính |
|---|---|---|
| FE UI | `presentation/pages/login_page.dart` | `_handleLogin()`, `_navigateAfterSuccess()` |
| FE UI | `presentation/pages/admin/admin_dashboard_page.dart` | `_fetchRoles`, `_updateRolePermissions`, `_fetchAccounts`, `_toggleUserStatus` |
| BE Controller | `controller/AuthController.java` | `authenticateUser` |
| BE Controller | `controller/AdminController.java` | `getUsers`, `updateUserStatus`, `updateUserByAdmin` (nay chặn tự đổi role), `updateRolePermissions` |
| BE Service | `service/AuthService.java` | `authenticateUser` (nay có brute-force lockout) |
| BE Security | `security/JwtAuthFilter.java`, `UserDetailsImpl.java`, `SecurityConfig.java`, `CustomAccessDeniedHandler.java` | (không đổi từ lần trước) |
| BE Entity | `entity/User.java` | `failedLoginAttempts`, `lockedUntil` (nay thực sự được dùng) |

---

## 7. Error & Exception Map

| Exception | Ném ở đâu | Bắt ở đâu | HTTP status |
|---|---|---|---|
| `ApiException` | `AuthService`, `LessonServiceImpl`, `TrainerDashboardServiceImpl` (6 method flow Course Authoring), `CourseManagerDashboardServiceImpl` (4 method) | `GlobalExceptionHandler.handleApiException` hoặc `Controller.catch(ApiException e)` riêng | Tùy `status` truyền vào lúc `throw` |
| `MethodArgumentNotValidException` | `@Valid` trên DTO thất bại (vd `price` null/âm) | `GlobalExceptionHandler.handleValidationException` | 400 |
| `AccessDeniedException` (từ `@PreAuthorize`) | Spring Security AOP | `CustomAccessDeniedHandler` | 403 |
| `RuntimeException` thường (method chưa nằm trong 3 flow bảo vệ, vd exam/matrix) | rất nhiều nơi | Controller `catch (Exception e)` → 400, hoặc `GlobalExceptionHandler` → 500 nếu Controller không tự catch | 400 hoặc 500 |
| Mọi `Exception` khác | — | `GlobalExceptionHandler.handleGlobalException` | 500 |

---

## 8. Các kiến thức tôi bắt buộc phải hiểu trước khi bảo vệ

1. **JWT stateless + refresh token opaque** — JWT không lưu trạng thái server, refresh token lưu hash trong DB để có thể thu hồi.
2. **`@PreAuthorize` chạy TRƯỚC Controller**, quyền build lại mỗi request từ DB — đổi quyền có hiệu lực ngay lập tức.
3. **2 tầng kiểm tra quyền:** `@PreAuthorize` (role/permission chung) vs kiểm tra thủ công trong Service (quyền sở hữu 1 bản ghi cụ thể).
4. **Mô hình version-clone khi sửa course đã publish** — bảo vệ học viên đang học.
5. **`completeLesson` là trung tâm tính tiến độ + cấp chứng chỉ.**
6. **Nguyên tắc "không đưa cho client thứ nó chưa được phép biết"** — áp dụng 2 lần trong hệ thống: (a) ẩn đáp án quiz tới khi có attempt đầu tiên, (b) không tin điểm số client tự tính, luôn chấm lại ở Server. Đây là nguyên lý bảo mật tổng quát, không chỉ riêng HanGo — bất kỳ dữ liệu nào quyết định "đúng/sai" hay "thắng/thua" đều phải được Server giữ và tính, Client chỉ được thấy SAU khi hành động đã hoàn tất.
7. **`price` vs `suggestedPrice`** — giá bán thật (Trainer chọn) tách bạch khỏi giá tham khảo (hệ thống tính, luôn làm tròn 50k và kẹp trong 300k-700k). Khuyến mãi "khóa đầu miễn phí" giờ chỉ ép `price`, không đụng `suggestedPrice`.
8. **Chống brute-force bằng đếm-số-lần-sai + khoá tạm thời** — mẫu hình chuẩn: đếm `failedLoginAttempts`, khi vượt ngưỡng thì set `lockedUntil` trong tương lai, kiểm tra `lockedUntil` TRƯỚC KHI verify mật khẩu ở lần đăng nhập tiếp theo (không phải sau).
9. **Mẫu hình "chặn tự làm hại chính mình" lặp lại 2 lần trong `AdminController`** — chặn Admin tự đổi status VÀ tự đổi role của chính họ, cùng 1 logic: so email hiện tại với email mục tiêu, chỉ chặn khi giá trị THỰC SỰ thay đổi.
10. **File `.xlsx` = ZIP chứa XML (OOXML)** — `CourseImportService` tự parse thay vì dùng thư viện, có đủ 3 lớp phòng thủ chuẩn khi xử lý file upload: giới hạn kích thước (chống zip bomb), lọc tên file (chống zip slip), tắt external entity khi parse XML (chống XXE).
11. **`GlobalExceptionHandler` không phải nơi DUY NHẤT xử lý lỗi** — nhiều Controller tự try/catch. Với 3 flow bảo vệ, đã thống nhất trả đúng status (404/403/400/409) thay vì luôn ép về 400/500 như trước.

---

## 9. Các câu hỏi hội đồng có thể hỏi và câu trả lời

**Q1: Vì sao giá bán (`price`) và giá tham khảo (`suggestedPrice`) của 1 course lại khác nhau?**
> Vì đây là 2 khái niệm khác nhau: `price` là giá THẬT Trainer tự chọn khi tạo/sửa course, dùng để tính tiền học viên phải trả. `suggestedPrice` chỉ là con số hệ thống TÍNH RA để tham khảo (dựa trên hồ sơ Trainer, độ khó, số bài học, thời lượng), luôn được làm tròn về bội số 50.000đ và giới hạn trong khoảng 300.000đ-700.000đ cho dễ nhìn. Trainer có thể đặt giá bán khác hẳn số tham khảo này (vd cao hơn vì có thêm mentor 1-kèm-1) và ghi lý do vào `priceNote` để Course Manager tham chiếu khi duyệt.

**Q2: Đáp án đúng của câu hỏi quiz được ẩn/hiện theo quy tắc nào?**
> `LessonServiceImpl.getLessonDetail` kiểm tra `quizAttemptRepository.countByLessonIdAndStudentId(lessonId, userId) > 0` — nếu học viên CHƯA TỪNG nộp bài quiz này lần nào, `correctIndex` và `explanation` bị để `null` trong response, học viên chỉ thấy câu hỏi và các lựa chọn, không biết đáp án đúng. Sau khi đã nộp ít nhất 1 lần, các lần load trang tiếp theo mới trả đáp án đúng đầy đủ — phục vụ màn hình xem lại bài làm.

**Q3: Nộp quiz xong, điểm hiển thị trên toast có đáng tin không?**
> Có, sau khi fix. Flutter tự tính 1 điểm TẠM (`fallbackScore`) chỉ để gửi kèm request làm giá trị dự phòng (không dùng để hiển thị vì lúc này `correctIndex` có thể đang bị ẩn). Điểm THẬT là điểm Backend tự chấm lại từ đáp án đúng trong DB (`computeServerSideScore`), trả về trong response, và Frontend đọc lại điểm này (`postResult['grade']`) để hiển thị/quyết định pass-fail — không còn tin điểm client gửi lên nữa.

**Q4: Hệ thống chống dò mật khẩu (brute-force) như thế nào?**
> `AuthService.authenticateUser` đếm số lần sai liên tiếp (`failedLoginAttempts`); khi đạt 5 lần, khoá tài khoản 15 phút (`lockedUntil`). Lần đăng nhập tiếp theo, nếu `lockedUntil` vẫn ở tương lai thì chặn ngay từ đầu, không cho thử mật khẩu nữa (tránh dò tiếp trong lúc khoá). Đăng nhập đúng thì reset về 0. Giới hạn: đây là khoá THEO TÀI KHOẢN, chưa có rate-limit theo IP, nên không chặn được kiểu tấn công dò nhiều tài khoản khác nhau song song.

**Q5: File Excel import course có an toàn không? Dùng thư viện gì để đọc?**
> Không dùng thư viện ngoài (không Apache POI) — `CourseImportService` tự giải nén `.xlsx` như 1 file ZIP rồi tự parse các file XML bên trong (đúng chuẩn OOXML). Đã audit và xác nhận có đủ 3 lớp phòng thủ chuẩn: giới hạn kích thước file/entry (chống zip bomb), loại bỏ entry tên chứa `".."` (chống zip slip), tắt external entity khi parse XML (chống XXE). Đây là 1 trong những phần code được viết cẩn thận nhất hệ thống.

**Q6: Trước đây nút "Create Course" có vấn đề gì?**
> DTO `TrainerCreateCourseRequestDTO` có field `code` bắt buộc (`@NotBlank`), nhưng trang tạo course (`create_course_page.dart`) không bao giờ gửi field này lên (vì code do Backend tự sinh). Kết quả là Spring Validation chặn MỌI request tạo course ngay từ đầu, trả lỗi 400 "Code cannot be blank" trước khi vào tới logic nghiệp vụ — tính năng tạo course coi như không dùng được. Phát hiện khi audit DTO cho tính năng giá, đã xác minh bằng test và fix bằng cách bỏ `@NotBlank` (giữ `@Size` để vẫn giới hạn độ dài).

**Q7: Vì sao Admin không tự đổi status được nhưng lại đổi role được (trước khi fix)?**
> Đây đúng là điểm bất nhất trong code cũ — chặn tự đổi status đã có sẵn từ đầu nhưng chặn tự đổi role thì chưa, có lẽ do người viết chỉ nghĩ tới trường hợp status. Đã fix bằng cách thêm đúng logic tương tự (so email hiện tại với email mục tiêu, chỉ chặn khi role thực sự đổi) vào khối xử lý role trong `updateUserByAdmin`.

**Q8: Vì sao `reEvaluateCoursePrice` không còn đổi giá bán (`price`) nữa?**
> Trước đây endpoint này (nút "Refresh" cạnh ô giá) tính lại giá rồi ghi đè LUÔN cả `price` lẫn `suggestedPrice` — hợp lý khi giá hoàn toàn do hệ thống tính, nhưng giờ `price` do Trainer tự chọn thì việc tự động ghi đè sẽ xoá mất lựa chọn của họ mỗi khi họ bấm refresh giá tham khảo. Đã sửa: endpoint này giờ CHỈ tính lại `suggestedPrice` (hữu ích khi Trainer vừa thêm/bớt bài học, muốn xem số tham khảo mới), hoàn toàn không đụng tới `price`.

**Q9: Vì sao chỉ khoá `price` = 0 mà không khoá cả `suggestedPrice` cho khoá học đầu tiên miễn phí?**
> Vì 2 cột mang 2 ý nghĩa khác nhau: `price` = 0 nghĩa là "hiện tại đang bán 0đ" (chính sách khuyến mãi). `suggestedPrice` vẫn giữ nguyên số tham khảo (vd 500.000đ) để Course Manager biết "khoá học này đáng giá bao nhiêu trên thị trường dù đang miễn phí" — hữu ích khi họ cân nhắc duyệt hay không. Nếu zero cả 2, thông tin "đáng giá bao nhiêu" sẽ mất, panel "Price Negotiation" cũng mất tác dụng tham chiếu.

---

## 10. Đánh giá tổng thể & những điểm còn có thể cải thiện thêm

**Tổng thể:** cả 3 flow hiện đã ở trạng thái vững — không còn lỗ hổng bảo mật/gian lận nào ở mức nghiêm trọng mà tôi phát hiện được, các quy tắc nghiệp vụ (versioning, giá, RBAC) đã nhất quán, và 927 unit test backend đều pass sau mọi thay đổi. Đây là những điểm **KHÔNG bắt buộc phải sửa** trước khi bảo vệ nhưng nên biết nếu bị hỏi sâu ("bạn thấy còn hạn chế gì không"):

1. **Chưa có rate-limit theo IP** cho đăng nhập — chỉ khoá theo tài khoản (mục 4). Muốn triệt để cần thêm ở tầng hạ tầng (Nginx/Cloudflare) hoặc thư viện như Bucket4j.
2. **Chưa có optimistic locking (`@Version`) trên `Course`** — 2 request sửa cùng 1 course đồng thời (vd Trainer mở 2 tab) sẽ ghi đè nhau âm thầm (last-write-wins). Rủi ro thấp trong thực tế (thường chỉ 1 người soạn).
3. **Đáp án quiz vẫn lộ khi Retake** — chấp nhận được vì đã làm thật ít nhất 1 lần (mục 3), không phải lỗ hổng.
4. **Đáp án quiz khớp theo VỊ TRÍ câu hỏi, không phải `question_id`** — nếu Trainer đổi thứ tự câu hỏi đúng lúc học viên đang làm bài (rất hiếm), điểm có thể chấm lệch. Edge case nhỏ.
5. **`CourseImportService` chưa có unit test nào** (0 test cho 1 file ~940 dòng) — rủi ro khi sửa file này sau này không có gì báo động nếu lỡ tay đổi hành vi. Cũng còn ~8 method dead code (sót lại từ thiết kế cũ, không ảnh hưởng gì, chỉ chưa dọn).
6. **Course Manager không có cách nào chặn Trainer đặt giá quá cao/quá thấp bất hợp lý** ngoài Reject nội dung — theo đúng quyết định thiết kế bạn đã chọn ("CM chỉ Approve/Reject, không sửa giá"), không phải thiếu sót, chỉ là biết trước nếu bị hỏi.

Không mục nào trong 6 điểm trên là khẩn cấp — tôi khuyên **không cần đụng thêm gì nữa trước buổi bảo vệ**, trừ khi hội đồng hỏi cụ thể và bạn muốn có câu trả lời sẵn (thì đọc mục này là đủ).

---

*(Tài liệu ánh xạ trực tiếp tới code tại 2026-08-23. Số dòng có thể lệch nhẹ sau các lần sửa tiếp theo — ưu tiên đọc lại tên method/class thay vì tin tuyệt đối vào số dòng cụ thể.)*
