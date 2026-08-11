# Feature Specification: FE-11 — AI Recommendation

> Ref: [HanGo_Documentation.md](../HanGo_Documentation.md) §7.11 (REC). Lesson-scoped Q&A chat is a separate module — see [12-ai-assistant.md](12-ai-assistant.md) (FE-12). Renamed/renumbered from `11-recommendation.md` 2026-08-10 to match the current name "AI Recommendation".

> ⚠️ **Cập nhật 2026-08-10:** không tồn tại 1 nhánh "Rule-based Recommendation" độc lập tách khỏi AI như thiết kế trước mô tả — matching Course theo weak-skill hiện đi thẳng qua Gemini (`ExamCourseRecommendationAIService`), có fallback **trả rỗng** (không phải fallback rule-based riêng) khi AI lỗi/parse fail, để Frontend tự xử lý hiển thị.

## 1. Business Context
Sau mỗi Exam Attempt, hệ thống phân tích các câu trả lời sai (nhóm theo `topic`/`skill`) để suy ra **Weakness Analysis** — không phải 1 entity/bảng riêng, mà là field tính toán mỗi lần cần. Từ đó: (1) gợi ý tối đa 3 Course phù hợp qua Gemini, và (2) sinh **AI Learning Pathway** — lộ trình gồm chuỗi `PathwayNode` (mỗi node = 1 Course), có thể cập nhật qua 3 cơ chế khác nhau (reroute tự động / reroute "agentic" / edit goal-schedule).

## 2. Acceptance Criteria

**Frontend (Flutter):**
- [ ] `pathway_goal_dialog.dart` (từ `exam_result_page.dart`, lần đầu) / `PathwaySetupDialog` (trong Pathway page) — đặt mục tiêu (target score, deadline, giờ/tuần).
- [ ] `learning_pathway_page.dart` — hub: `PathwaySummaryHeader` (progress + nút Analysis/Edit Goal), `InteractiveNodeTree` (timeline node Locked/In Progress/Completed), `DailyPlanCard` (3 việc trong ngày: review spaced-repetition / mastery-check / lesson tiếp theo), `AIMentorSidePanel` (chat, có trạng thái "đang reroute").
- [ ] `SkillAnalysisPanel` — bottom sheet phân tích điểm yếu.
- [ ] `EditGoalDialog` — đổi target score/deadline, hiển thị điểm trung bình hiện tại + nhận xét AI.
- [ ] Empty state thân thiện khi chưa có Pathway ("làm 1 Exam để AI dựng lộ trình").

**Backend (Spring Boot, `LearningPathwayController` base `/api/v1/pathways`, mọi endpoint gate `hasAuthority('ENROLL_AND_LEARN_COURSES')`):**
- [ ] `POST /generate`, `GET /{id}`, `GET /me`.
- [ ] `PUT /{id}/reroute` — **tự động**, dựa điểm Attempt gần nhất.
- [ ] `PUT /{id}/schedule` — cập nhật goal/deadline/giờ-tuần + tính lại time-boxing.
- [ ] `POST /{id}/nodes/{nodeId}/mastery` — nộp điểm mastery-check (spaced-repetition).
- [ ] `GET /{id}/progress-snapshot`, `POST /{id}/reroute/suggestions` → `/accept`\|`/decline` — reroute "agentic" (Fast-track/Detour).
- [ ] `POST /{id}/mentor-action` — 4 quick action: `FAST_TRACK`/`ADJUST_SCHEDULE`/`TAKE_QUIZ`/`WHAT_WILL_I_LEARN`.
- [ ] `POST /{id}/chat`, `GET`/`DELETE /{id}/chat/history`.
- [ ] `POST /api/v1/exams/ai/recommend-courses` (`ExamCourseRecommendationController`) — top 3 Course + tóm tắt điểm yếu.

## 3. Technical Constraints
- **`PathwayGoalMergeService` ("multi-goal merge") có code + test đầy đủ nhưng chưa nối vào Controller nào** — không gọi được từ API hiện tại.
- **`hasWeakSkillOverlap` hardcode `false`** trong `PathwayProgressSnapshotService` — điều kiện "không trùng kỹ năng yếu" của Fast-track suggestion hiện luôn thoả, chưa lọc thật.
- **Mastery submit từ UI hiện gửi điểm mock** (`_submitMastery` gửi cứng 90/100 tuỳ nút bấm "Take Mastery"/"Review") — chưa phải bài chấm điểm thật.
- **`recommendCoursesAI` không verify ownership `examAttemptId`** — xem `HanGo_Documentation.md` §22 (IDOR khả dĩ).

## 4. Edge Cases
- **Câu hỏi ngoài phạm vi học tập gửi vào AI Mentor Chat:** có bộ lọc từ khoá + hậu kiểm câu trả lời, tự chuyển hướng sang gợi ý dùng AI Assistant (FE-12) nếu là câu hỏi học thuật.
- **Reroute lặp lại nhiều lần:** chưa xác nhận độc lập có cơ chế "flag để Course Manager review" như thiết kế trước đề xuất — cần kiểm tra lại trước khi coi đây là đã implement.

## 5. Non-functional Requirements
- **Performance:** pathway generation/chat cần hiển thị loading placeholder do phụ thuộc Gemini (độ trễ ngoài tầm kiểm soát).
