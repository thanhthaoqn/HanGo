# TODO2 - HanGo AI Interactive Learning Pathway

> **Feature ID:** FT-15 — AI Interactive Learning Pathway (Lộ trình học tập thích ứng thông minh)
>
> Tính năng cho phép AI Agent phân tích kết quả bài thi, nhận diện "Lỗ hổng kiến thức", và tự động sinh Roadmap dạng Node Tree cá nhân hóa. Người học tương tác trực quan với sơ đồ và trò chuyện với AI Mentor.

- (1) When starting a task, change the checkbox status to `- [ ] (In Progress)`.
- (2) When a task is completed, change it to `- [x] Done`.
- (3) **ABSOLUTELY DO NOT arbitrarily delete any tasks** from this file without Human approval.
- (4) If attempting a task 3 times still results in failure (Stuck), keep the current status and log the error in the `Escalated to Human` section at the end of the file.

---

## 🚀 [FT-15] AI Interactive Learning Pathway

### 🎨 Phase 1: Frontend UI & Mock Data _(Assigned to: Frontend Agent)_

- [x] Thêm "Learning Pathway" vào navbar desktop (`shared_header.dart`) — sau Exams, Courses, Flashcard.
- [x] Thêm "Learning Pathway" vào mobile drawer (`learner_home_page.dart`).
- [x] Tạo placeholder `LearningPathwayPage` với UI Coming Soon.
- [x] Xây dựng layout 2 cột chính: Cột trái 65% (Interactive Node Tree) + Cột phải 35% (AI Mentor Side Panel).
- [x] Xây dựng **Interactive Node Tree** component:
  - [x] Vẽ chuỗi Nodes xếp dọc/zig-zag (tương tự Duolingo) bằng Custom Painter hoặc `fl_chart`.
  - [x] Implement 3 trạng thái Node: **Locked** (xám, icon ổ khóa), **In Progress** (viền Neon glow nhấp nháy, hiển thị % tiến độ), **Completed** (xanh green, checkmark).
  - [x] Mỗi Node hiển thị: Tên bài học gợi ý + Tag chuyên đề (ví dụ: `#Grammar`, `#Vocabulary`).
  - [x] Khi click Node → kích hoạt Sidebar AI giải thích + nút "Bắt đầu học ngay" (điều hướng sang bài học).
- [x] Xây dựng **AI Mentor Side Panel** component:
  - [x] Avatar AI Mentor (dạng Hologram/Robot giáo dục thân thiện) + trạng thái "AI Mentor đang trực tuyến".
  - [x] Khung Chat hiển thị lời thoại cá nhân hóa (tin nhắn chào mừng kèm phân tích tổng quan).
  - [x] Khung nhập liệu (Input Chat) cho phép học viên gõ câu hỏi tự do liên quan đến lộ trình.
  - [x] Hỗ trợ Markdown rendering trong tin nhắn chat.
- [x] Tạo **Mock Pathway Repository** trả về fake roadmap JSON chuẩn format:
  ```json
  {
    "roadmap_id": "RM_USER_99",
    "mentor_summary": "Lời giải thích tổng quan từ AI...",
    "nodes": [
      { "step": 1, "course_id": "C_GR_01", "status": "In_Progress", "reason_why": "..." },
      { "step": 2, "course_id": "C_VOB_02", "status": "Locked", "reason_why": "..." }
    ]
  }
  ```

### ⚙️ Phase 2: Backend Execution & API Design _(Assigned to: Backend Agent)_

- [x] Thiết kế Database Schema:
  - [x] Bảng `learning_pathways` (id, user_id, exam_attempt_id, mentor_summary, status, created_at, updated_at).
  - [x] Bảng `pathway_nodes` (id, pathway_id, step_order, course_id FK, status, reason_why, progress_percent).
- [x] Tạo JPA Entities: `LearningPathway`, `PathwayNode`.
- [x] Tạo DTOs: `PathwayGenerateRequestDTO`, `PathwayResponseDTO`, `PathwayNodeDTO`.
- [x] Tạo Repositories: `LearningPathwayRepository`, `PathwayNodeRepository`.
- [x] Xây dựng `LearningPathwayService`:
  - [x] Hàm `generatePathway(userId, examAttemptId)` — lấy Matrix Exam Result, gọi AI API.
  - [x] System Prompt chặt chẽ: **CHỈ được chọn `course_id` từ danh sách SystemCourses (Published)**. Tuyệt đối không tự bịa khóa học mới.
  - [x] Sắp xếp ưu tiên: Dễ → Khó, Ngữ pháp nền tảng trước → Đọc hiểu nâng cao sau.
  - [x] Output: Structured JSON (JSON Mode) theo format chuẩn.
  - [x] Hàm `reroutePathway(pathwayId, quizResult)` — Dynamic Re-routing khi quiz score quá kém.
- [x] Tạo API Endpoints:
  - [x] `POST /api/v1/pathways/generate` — Sinh lộ trình mới từ kết quả thi.
  - [x] `GET /api/v1/pathways/{id}` — Lấy lộ trình hiện tại của user.
  - [x] `GET /api/v1/pathways/me` — Lấy lộ trình mới nhất của user đang đăng nhập.
  - [ ] `PUT /api/v1/pathways/{id}/reroute` — Tính toán lại lộ trình (Dynamic Re-routing) - Pending.
- [ ] Implement AI Mentor Chat endpoint cho lộ trình:
  - [ ] `POST /api/v1/pathways/{id}/chat` — Gửi câu hỏi cho AI Mentor về lộ trình.
  - [ ] Context embedding: truyền roadmap data + exam result vào prompt.
- [x] Cấu hình `@PreAuthorize` — chỉ LEARNER mới được gọi API pathway.

### 🔌 Phase 3: Integration _(Assigned to: Frontend Agent)_

- [ ] Thay Mock Pathway Repository bằng real `dio` API calls kết nối Backend.
- [ ] Kết nối AI Mentor Chat với backend AI endpoint (streaming SSE/chunks).
- [ ] Implement click-to-navigate: từ Node → `CourseDetailPage` / `LessonPage` tương ứng.
- [ ] Cập nhật trạng thái Node real-time sau khi user hoàn thành bài học.
- [ ] Trigger Dynamic Re-routing UI khi nhận kết quả quiz kém.

### 🚨 Phase 4: Quality Assurance _(Assigned to: QA Agent)_

- [ ] **Anti-Hallucination Test:** Xác minh AI không tự bịa `course_id` ngoài danh sách SystemCourses.
- [ ] **Dynamic Re-routing Test:** Khi điểm quiz < ngưỡng → lộ trình được tính toán lại chính xác.
- [ ] **Widget Test Node Tree:** Kiểm tra animation transitions (Locked → In Progress → Completed) đạt 60fps.
- [ ] **Edge Case — Cold Start:** User chưa có exam attempt nào → hiển thị thông báo hướng dẫn làm bài thi trước.
- [ ] **Edge Case — Empty Courses:** Không có khóa học Published nào phù hợp → AI trả về thông báo phù hợp, không crash.
- [ ] **Security Test:** LEARNER role chỉ xem được pathway của chính mình, không truy cập pathway user khác.
- [ ] **Concurrent Test:** 2 request `generate` cùng lúc cho cùng 1 user → không tạo duplicate pathway.

---

## 📋 THAM KHẢO: ĐẶC TẢ CHI TIẾT GỐC

### Tổng quan luồng nghiệp vụ (Workflow)
1. Học viên hoàn thành một Bài thi thử (Exam). Hệ thống trả về cấu trúc dữ liệu lỗi sai chi tiết (Matrix Exam Result).
2. AI Agent phân tích dữ liệu này, nhận diện chính xác "Lỗ hổng kiến thức" dựa trên: SkillType (Kỹ năng), GroupType (Chuyên đề ngữ pháp/từ vựng cụ thể), và Difficulty Level (Mức độ khó).
3. AI Agent sử dụng cơ chế RAG hoặc Function Calling để truy xuất danh sách các Khóa học/Bài học hiện có trên hệ thống (Trạng thái: Published) để sắp xếp thành một Roadmap dạng sơ đồ nút (Node Tree).
4. Người học tương tác trực quan với sơ đồ Roadmap: bấm vào từng nút để học, trò chuyện với AI Mentor ở khung Chat bên cạnh để nghe giải thích lý do chặng này xuất hiện.
5. Khi người học làm bài kiểm tra tiến độ (Quiz) của một chặng mà kết quả quá kém, AI sẽ tự động tính toán lại và cập nhật lộ trình (Dynamic Re-routing).

### Thiết kế giao diện (UI/UX Specifications)
- **Layout:** 2 cột — Cột trái 65% (Sơ đồ Node Tree) + Cột phải 35% (AI Mentor Side Panel).
- **Cột trái — Interactive Node Tree:** Chuỗi Nodes xếp dọc/zig-zag (Duolingo-style). 3 trạng thái: Locked (xám + ổ khóa), In Progress (Neon glow + %), Completed (xanh green + checkmark).
- **Cột phải — AI Mentor Side Panel:** Avatar AI Mentor + trạng thái online. Khung chat cá nhân hóa + Input chat tự do.

### AI Logic & Backend
- Hàm sinh Roadmap bằng Prompt Engineering + Structured Outputs (JSON Mode).
- System Prompt bắt buộc: Chỉ chọn `course_id` từ SystemCourses. Sắp xếp Dễ → Khó.
- Kiến trúc dữ liệu đầu vào: lấy từ database hệ thống (Matrix Exam Result).

---

## 🛑 ESCALATED TO HUMAN

_(AI Agents should log tasks stuck after 3 attempts here, formatted as: [FeatureID] - Task Name - Error Description - File Link)_

- [ ] (No issues yet)