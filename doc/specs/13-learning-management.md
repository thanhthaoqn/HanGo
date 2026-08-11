# Feature Specification: FE-13 — Learning Management

> Ref: [HanGo_Documentation.md](../HanGo_Documentation.md) §7.13 (LRN). Renumbered from `10-learning-management.md` 2026-08-10.

> ⚠️ **2 điểm cần biết trước khi test/thiết kế thêm tính năng:** (1) học **tuần tự theo Lesson** vẫn là thiết kế nghiệp vụ dự định, nhưng **chưa có chặn ở server** — gọi thẳng API Lesson bất kỳ (kể cả chưa mở khoá theo UI) vẫn trả nội dung, hiện chỉ chặn ở Frontend. (2) enroll/unenroll/xem Lesson **không có role-gate** — bất kỳ user đã đăng nhập nào (kể cả Trainer/Admin) đều enroll/xem được, không riêng Learner.

## 1. Business Context
Learner theo dõi tiến độ học từng Course đã enroll. Lesson "hoàn thành" khi Learner bấm Mark as Completed hoặc nộp bất kỳ Quiz attempt nào (không cần đạt điểm tối thiểu). Course mua/enroll rồi truy cập trọn đời. Rating chỉ mở sau khi hoàn thành 100% Course, sửa lại được sau đó (upsert).

## 2. Acceptance Criteria

**Frontend (Flutter):**
- [ ] `my_learning_page.dart` — danh sách Course "In Progress"/"Completed" + lịch sử Exam attempt (search/filter/sort/paginate).
- [ ] `lesson_detail_page.dart` — nội dung Lesson, nút Mark as Completed, quiz nhúng, comment thread, `LessonAiChatbox`.
- [ ] Tự chuyển sang Lesson tiếp theo khi hoàn thành; Lesson N+1 **hiển thị** khoá cho tới khi Lesson N hoàn thành (ràng buộc UI).
- [ ] "Continue Learning" — quay lại đúng vị trí học dở.
- [ ] `course_completion_page.dart` — màn ăn mừng hoàn thành + form review (sao + nhận xét) nhúng sẵn.
- [ ] `review_tab.dart` — xem review/rating của Course.

**Backend (Spring Boot):**
- [ ] `POST /api/v1/courses/{id}/enroll`, `DELETE .../enroll` (unenroll = xoá cứng, không soft-delete/audit).
- [ ] `GET /api/v1/lessons/{id}` — cho xem cả khi chưa đăng nhập (`isCompleted` mặc định `false`).
- [ ] `PUT /api/v1/lessons/{id}/complete?completed=` — cập nhật `LessonProgress`, tính lại % (pessimistic lock chống đua tiến trình), chuyển `Enrollment.status=COMPLETED` khi đạt 100%.
- [ ] `POST /api/v1/lessons/{id}/quiz-attempts` — nộp attempt tự động gọi `completeLesson` kèm theo, bất kể điểm.
- [ ] `POST /api/v1/courses/{id}/reviews` (gate `RATE_AND_COMMENT`) — yêu cầu `Enrollment.status=COMPLETED`.
- [ ] `Course.averageRating`/`totalRatings` tính lại + ghi đè (write-through cache) mỗi lần review add/sửa/xoá.

## 3. Technical Constraints
- **Sequential Learning chưa enforce ở server** — xem cảnh báo đầu file; nếu cần chặn thật, phải thêm check ở `LessonController`/`LessonServiceImpl`, hiện chưa có.
- **Không có `ProgressService` riêng** — logic tiến độ nằm trong `CourseServiceImpl`/`LessonServiceImpl`.
- **Learning History không có endpoint riêng** — phục vụ qua `GET /courses?filterType=ENROLLED|IN_PROGRESS|COMPLETED`.

## 4. Edge Cases
- **Trainer sửa cấu trúc Course đã Published (thêm/xoá Section/Lesson):** version mới không ảnh hưởng Learner đang học bản cũ (§9.3 tài liệu chính) — % tiến độ tính theo tổng Lesson của **version đang enroll**, không phải version mới nhất.
- **Rating ≤3 sao:** bắn notification `LOW_RATING` cho **cả Course Manager lẫn Administrator** (đã hiệu chỉnh — không chỉ riêng Course Manager như thiết kế trước).
- **Average rating chuyển từ >4.0 xuống ≤4.0:** bắn `LOW_AVERAGE_RATING` **đúng 1 lần** lúc vượt ngưỡng, không lặp lại ở các rating thấp tiếp theo.
- **Gọi thẳng API Lesson chưa "mở khoá" theo UI:** hiện vẫn trả về nội dung — cần biết trước khi coi đây là hành vi có chặn.

## 5. Non-functional Requirements
- **Consistency:** tính % hoàn thành dùng lock ghi (pessimistic) trên `Enrollment`, tránh race condition khi hoàn thành nhiều Lesson gần như đồng thời.
