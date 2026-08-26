# HanGo Code Review — Defense Preparation

> Tài liệu ôn tập bảo vệ: trace 3 flow AI **end-to-end trên code thật** của repo.
> Mọi đường dẫn / class / method / số dòng dưới đây đều lấy trực tiếp từ source hiện tại (đã audit ngày 2026-08-25).
> Số dòng có thể lệch ±2 dòng nếu code được sửa sau ngày này.

---

## 1. Architecture tổng quan

### 1.1 Kiến trúc 2 tầng

```
┌─────────────────────────────────┐        HTTP + JSON         ┌──────────────────────────────────┐
│  hango-frontend (Flutter Web)   │ ─────────────────────────► │  hango-backend (Spring Boot)     │
│  Port 3000                      │  Authorization: Bearer JWT │  Java 21 + MySQL                 │
│                                 │ ◄───────────────────────── │                                  │
│  UI (pages/widgets)             │                            │  Controller (@RestController)    │
│   ↓ Provider (AppState/State)   │                            │   ↓ @PreAuthorize (RBAC)         │
│  Repository / Service class     │                            │  Service (business logic)        │
│   ↓ package:http                │                            │   ↓ Repository (Spring Data JPA) │
│  SharedPreferences (JWT cache)  │                            │  MySQL (Hibernate ddl-auto)      │
└─────────────────────────────────┘                            │   ↓ HTTPS                        │
                                                               │  Google Gemini API               │
                                                               │  (gemini-3.1-flash-lite +        │
                                                               │   text-embedding-004)            │
                                                               └──────────────────────────────────┘
```

### 1.2 Request đi qua những lớp nào (mọi API)

1. **CORS** — `security/SecurityConfig.java` `corsConfigurationSource()` cho phép origin `http://localhost:3000`, `https://hangog92.online`.
2. **JwtAuthFilter** (`security/JwtAuthFilter.java`) — đọc header `Authorization: Bearer <token>`, verify chữ ký JWT, nạp `UserDetailsImpl` vào 
`SecurityContextHolder`.
3. **FilterChain authorization** (`SecurityConfig.filterChain`) — quy tắc URL-level (`permitAll` / `authenticated`).
4. **Controller** — nhận request, parse DTO, `@Valid` validate.
5. **@PreAuthorize method security** — kiểm tra permission (`hasAuthority('...')`). Bật nhờ `@EnableMethodSecurity` trong SecurityConfig.
6. **Service** — business logic, gọi Gemini, ghi DB.
7. **Repository** — Spring Data JPA → MySQL.
8. **Response** — JSON về FE; lỗi ném `ApiException` → `exception/GlobalExceptionHandler.java` (`@RestControllerAdvice`) chuyển thành JSON 
`ApiErrorDTO`.

### 1.3 Ai "nói chuyện" với Gemini?

MỌI lời gọi LLM đi qua đúng 1 cổng: `service/GeminiClientService.java`.
- Model chat: `hango.gemini.chat-model=gemini-3.1-flash-lite`
- Model embedding: `text-embedding-004`
- Config trong `application.properties` (dòng 34–38), API key từ biến môi trường `HANGO_GEMINI_API_KEY` (không hardcode).
- WebClient khởi tạo 1 lần ở `init()` (`@PostConstruct`, dòng 100–122) với base URL `https://generativelanguage.googleapis.com`, tự gắn header 
`x-goog-api-key` cho từng request.
- Hàm quan trọng nhất: `generateChatResponse(systemPrompt, chatHistory)` (dòng 184).

---

## 2. Luồng 1 — AI Assistant Chatbox (trong Lesson)

### Business Flow

Learner đang học một Lesson muốn hỏi AI về nội dung bài đó. AI **chỉ được trả lời trong phạm vi bài học** — hỏi lạc đề bị từ chối khéo. Đây 
là UC-31 / FT-08, có **3 lớp guardrail**:

| Lớp | Ở đâu | Cơ chế | Chi phí |
|---|---|---|---|
| **L2 — Context check** | `AIAssistantService.sendMessage` | Conversation bắt buộc gắn 1 Lesson tồn tại trong DB | 0 |
| **L3 — Embedding similarity** | `ScopeGuardrailService.checkScope` | Cosine similarity giữa câu hỏi và nội dung bài học; thấp hơn ngưỡng 
→ chặn TRƯỚC khi gọi LLM | 2 lần gọi embedding |
| **L1 — Prompt engineering** | `AIPromptBuilder.buildSystemPrompt` | System prompt ép vai trò "trợ lý của bài học này", yêu cầu từ chối khéo 
khi lạc đề | nằm trong lần gọi chat duy nhất |

### UI Flow

1. Learner mở `presentation/pages/course/lesson_detail_page.dart` → widget `LessonAiChatbox` (`presentation/widgets/lesson_ai_chatbox.dart`, 
class `_LessonAiChatboxState`) hiển thị drawer chatbox.
2. `initState()` (dòng ~47): gọi `context.read<AppState>().checkAiStatus()` → hiện trạng thái online/offline của AI; đồng thời `_loadFromCache()` 
nạp lịch sử chat từ cache máy (SharedPreferences key `ai_chat_lesson_{lessonId}`, tối đa 200 tin nhắn).
3. Learner gõ câu hỏi → bấm gửi → `_send()` (dòng ~162).
4. UI hiển thị ngay tin nhắn USER (**optimistic UI**), chờ response, rồi thêm bubble ASSISTANT kèm 3 câu hỏi gợi ý (nếu có).

### Frontend Flow

**Bước 1 — `_send()` trong `lesson_ai_chatbox.dart` (~dòng 162):**
- Validate: text rỗng hoặc đang gửi → return.
- `setState`: thêm `AiMessage(role:'USER', content:text)` vào `_messages`, set `_sending=true`.
- Gọi `context.read<AppState>().sendAiMessage(lessonId, conversationId, message)`.

**Bước 2 — `services/app_state.dart` `sendAiMessage()` (dòng 192):**
- `_buildAiUrl('/ai-assistant/messages')` ghép thành `{base}/v1/ai-assistant/messages`.
- `http.post(...)` với headers: `Content-Type: application/json` + `Authorization: Bearer ${_session!.token}` (token lấy từ session đã login).
- Body JSON: `{'lessonId': lessonId, 'conversationId': ... (nếu có), 'message': message}`. Timeout 30s.
- Status 200 → parse JSON thành `AiChatResponse{conversationId, reply, wasOutOfScope, suggestedQuestions}`.
- **Lỗi:** nhánh else đọc `body['message']` để báo lỗi; catch ngoài cùng trả về một response giả chứa `"Error: ..."`. ⚠️ Lưu ý quirk: lỗi mạng/timeout 
cũng được "ngụy trang" thành reply của AI hiển thị trong bubble — điểm yếu UX đáng chú ý.

**Bước 3 — quay lại `_send()`:**
- Thành công: `_conversationId = response.conversationId` (để các lần gửi sau tiếp tục cùng hội thoại), thêm bubble ASSISTANT, `_saveToCache()`.
- Thất bại (Exception): set `_error = e.toString()`, **gỡ lại** bubble USER vừa thêm (rollback optimistic UI) — xem khối catch ở ~dòng 195–200.

### API Flow

```
POST /api/v1/ai-assistant/messages
Headers: Authorization: Bearer <JWT>, Content-Type: application/json
Body:    { "lessonId": 12, "conversationId": 34?, "message": "..." }
← 200:   { "conversationId": 34, "reply": "...", "wasOutOfScope": false,
           "suggestedQuestions": ["...", "...", "..."] }
← 400/401/403/404/502/503: ApiErrorDTO { timestamp, status, error, message, path }
```

GET `/api/v1/ai-assistant/conversations` — lịch sử hội thoại (server-side).
GET `/api/v1/ai-assistant/status` — health check Gemini (public).

### Backend Flow

**Controller — `controller/AIAssistantController.java`:**
- `sendMessage()` (dòng 39–44): `@PostMapping("/messages")` + `@PreAuthorize("hasAuthority('AI_LEARNING_ASSISTANT')")` + `@Valid @RequestBody 
SendMessageRequest`.
- `getSafeUserId()` (dòng 63–124): trích userId từ `SecurityContextHolder`, thử lần lượt: principal là `User` entity → `Long` → `String` số 
→ email (query DB `userRepository.findByEmail`) → `UserDetailsImpl.getId()` → `SecurityUtil.getCurrentUserId()`. Mục đích: tránh ClassCastException 
vì project từng đổi kiểu principal.
- Validation đầu vào (`dto/SendMessageRequest.java`): `lessonId` `@NotNull`, `message` `@NotBlank @Size(max=500)` → vi phạm sẽ bị chặn trước khi 
vào service (400).

**Service — `service/AIAssistantService.java` `sendMessage()` (dòng 54):**

Thứ tự chạy chính xác:

1. `learnerId == null` → `throw ApiException(401)` (dòng 56–59).
2. **L2:** `lessonRepository.findById(request.getLessonId())` → không thấy → `ApiException("Không tìm thấy bài học này", 404)` (dòng 63–65).
3. `getOrCreateConversation()` (dòng 261):
   - Có `conversationId > 0` → `conversationRepository.findByIdAndLearnerIdWithMessages(conversationId, learnerId)` — query JOIN FETCH messages, 
và **lọc theo learnerId nên không đọc trộm hội thoại người khác**; fallback tạo mới.
   - Không có ID → `createNewConversation()`: tìm `User` theo id (404 nếu mất), build `AIConversation{learner, lesson, messages=[]}`, `save()`.
4. Build `AIMessage(USER)` chưa save — lưu message user **trước** để kể cả bị chặn vẫn còn lịch sử (dòng 70–74).
5. `lessonService.getLessonDetail(lessonId, learnerId)` → lấy `practiceQuestions` (đề luyện tập của bài) để nạp vào scope + prompt (dòng 79–84).
6. **L3:** `scopeGuardrailService.checkScope(lesson, message, practiceQuestions)` (dòng 88–92).
7. Nếu `outOfScope == true`:
   - `replyText = promptBuilder.buildOutOfScopeFallback(lesson)` (dòng 96) — câu từ chối cố định *"Câu hỏi này có vẻ nằm ngoài nội dung bài ..."*. 
**KHÔNG tốn lượt gọi LLM.**
8. Nếu in scope:
   - Dựng `geminiHistory`: map toàn bộ tin nhắn cũ (`wasOutOfScope=true` thì bỏ qua để không nhiễu), role `USER→"user"`, `ASSISTANT→"model"` 
(dòng 101–125); thêm câu hỏi hiện tại vào cuối (dòng 129–135).
   - **L1:** `promptBuilder.buildSystemPrompt(lesson, practiceQuestions)` (dòng 139) — template trong DB config `AI_ASSISTANT_SYSTEM_PROMPT` hoặc 
mặc định trong code; thay `{lesson_title}`, `{lesson_content}`, `{transcript_block}` (phụ đề video nếu có), `{practice_block}`.
   - `geminiClientService.generateChatResponse(systemPrompt, geminiHistory)` (dòng 143).
9. Sinh `suggestedQuestions`: **lần gọi Gemini thứ 2** với prompt yêu cầu trả JSON `{"suggestedQuestions":[...]}`, parse bằng regex tìm `[...]` 
rồi match chuỗi trong `"..."`, giới hạn 3 câu (dòng 150–231). Toàn bộ khối này bọc try/catch — fail thì bỏ qua, không ảnh hưởng reply chính.
10. Save cả 2 message vào conversation, `conversationRepository.save(conversation)` (dòng 246–248) — cascade lưu luôn messages.
11. Return `SendMessageResponse{conversationId, reply, wasOutOfScope, suggestedQuestions}`.

**Guardrail L3 chi tiết — `service/ScopeGuardrailService.java` `checkScope()` (dòng 39):**
- Câu < 8 ký tự ("hi", "ok") → cho qua (`inScope=true, score=1.0`) — tránh chặn lời chào xã giao.
- Ghép scope text = `lesson.contentText` + passage/question/options/explanation của từng practice question (dòng 49–69).
- `generateEmbedding(scopeText)` + `generateEmbedding(message)` → 2 vector.
- `VectorUtil.cosineSimilarity(scopeVector, messageVector)` ≥ `aiAssistantProperties.getScopeSimilarityThreshold()` → in scope.
- ⚠️ **Quan trọng:** prefix config là `hango.ai-assistant` (`config/AIAssistantProperties.java` dòng 9) nhưng `application.properties` hiện **không 
khai báo** `scope-similarity-threshold` → giá trị default `0.0` → thực tế guardrail gần như luôn cho qua (similarity ≥ 0). Chặn thực tế đang dựa vào 
L1 prompt. Đây là câu hỏi hay bị hỏi!
- Embedding API lỗi (404/429) → catch → trả `inScope=true` để không làm sập chat (dòng 82–86).
- Cache: embedding bài học tính 1 lần lưu cột `lessons.content_embedding` qua `LessonEmbeddingService.getOrComputeEmbedding()` — mỗi lần chat chỉ 
tốn 1 lần embed câu hỏi.

**Gemini gateway — `service/GeminiClientService.java` `generateChatResponse()` (dòng 184):**
- Build `GeminiGenerateRequest{systemInstruction, contents, generationConfig{temperature 0.4, maxOutputTokens 8192}}`.
- `webClient.post().uri("v1beta/models/{model}:generateContent")` → `.retryWhen(Retry.backoff(2, 2s)` chỉ áp dụng cho HTTP 429 TooManyRequests) 
→ `.timeout(60s)` → `.block()` (đồng bộ).
- Response rỗng → `recordUsage(CHAT,false,...)` + `ApiException("AI returned an invalid response", 502 BAD_GATEWAY)`.
- Exception bất kỳ → log + `recordUsage` + `ApiException("Không thể kết nối đến Trợ lý AI...", 503 SERVICE_UNAVAILABLE)`.
- Mỗi lần gọi đều ghi bảng `ai_usage_logs` (`recordUsage`, dòng 71–93): callType, success, durationMs, errorMessage(cắt 255 ký tự), userId (từ SecurityUtil).

### Database Flow

| Bảng | Thao tác | Khi nào |
|---|---|---|
| `ai_conversations` | INSERT | Tin nhắn đầu tiên của lesson (tạo conversation mới: learner_id, lesson_id, started_at) |
| `ai_messages` | INSERT x2 (cascade từ conversation.save) | Cuối mỗi lượt chat: 1 row role=USER (có was_out_of_scope), 1 row role=ASSISTANT |
| `lessons` | SELECT (+ content_embedding cache) | L2 check lesson + lấy nội dung |
| `ai_usage_logs` | INSERT | Sau MỖI lần gọi Gemini (chat/embedding/vision/transcript) |

Entity liên quan: `entity/AIConversation.java` (`@Table(name="ai_conversations")`, `@OneToMany messages` cascade ALL, `startedAt` set bằng `@PrePersist`), 
`entity/AIMessage.java` (role enum USER/ASSISTANT, `wasOutOfScope`).

### Exception & Error Handling

| Lỗi | Ném ở đâu | Bắt ở đâu | HTTP |
|---|---|---|---|
| Thiếu/sai body (`@Valid` fail: lessonId null, message >500 ký tự) | Spring MethodArgumentNotValidException | `GlobalExceptionHandler.handleValidationException` 
(dòng 33) | **400** + tên field |
| Body JSON hỏng | HttpMessageNotReadableException | `GlobalExceptionHandler.handleUnreadableBody` (dòng 51) | 400 |
| learnerId null (token lạ) | `AIAssistantService.sendMessage` dòng 56 | `GlobalExceptionHandler.handleApiException` | **401** |
| Lesson không tồn tại | `AIAssistantService.sendMessage` dòng 63 | handleApiException | **404** |
| Không đủ quyền `AI_LEARNING_ASSISTANT` | Spring Security (method interceptor) | `GlobalExceptionHandler.handleAccessDeniedException` (dòng 101) hoặc 
`CustomAccessDeniedHandler` | **403** |
| Gemini rỗng | `GeminiClientService` dòng 215 | handleApiException | **502** |
| Gemini timeout/lỗi mạng | `GeminiClientService` dòng 222–228 | handleApiException | **503** |
| Lỗi bất ngờ khác | bất kỳ | `handleGlobalException` (dòng 113) | **500** message chung, không lộ stack trace |

FE xử lý: `app_state.sendAiMessage` đọc `message` từ body lỗi → ném Exception → chatbox rollback bubble USER và hiện `_error`. Suggested questions sinh lỗi 
→ bị nuốt (log warn) và trả list rỗng.

### Authentication & Authorization

- URL level: `/api/v1/ai-assistant/**` = permitAll, riêng `/messages` và `/conversations` = `authenticated()` (SecurityConfig dòng 73–75). ⚠️ Vì Spring Security 
chọn rule **đầu tiên khớp**, `/messages` thực ra khớp pattern `/**` trước → URL-level coi như permitAll; việc chặn thật diễn ra ở `@PreAuthorize` method 
level + check `learnerId==null` trong service.
- Permission `AI_LEARNING_ASSISTANT` đến từ đâu: `User → roles → role_permissions → permissions.code`. Được load thành GrantedAuthority trong 
`UserDetailsImpl.build()` (dòng 35–62) mỗi lần JwtAuthFilter xác thực request.

### Complete Data Flow

```
User gõ câu hỏi
→ LessonAiChatbox._send()                    [lesson_ai_chatbox.dart:162]
→ AppState.sendAiMessage()                   [app_state.dart:192]  POST /api/v1/ai-assistant/messages
→ JwtAuthFilter verify JWT                   [JwtAuthFilter.java:30]
→ AIAssistantController.sendMessage          [AIAssistantController.java:40]  @PreAuthorize AI_LEARNING_ASSISTANT
→ AIAssistantService.sendMessage             [AIAssistantService.java:54]
   ├─ lessonRepository.findById              → SELECT lessons
   ├─ getOrCreateConversation                → SELECT/INSERT ai_conversations
   ├─ scopeGuardrailService.checkScope       → 2x POST Gemini :embedContent (scope cached trong lessons.content_embedding)
   ├─ [in-scope] promptBuilder.buildSystemPrompt
   ├─ geminiClientService.generateChatResponse → POST Gemini :generateContent (retry 429, timeout 60s)
   ├─ [call 2] generateSuggestedQuestions    → POST Gemini :generateContent (JSON 3 câu)
   └─ conversationRepository.save            → INSERT ai_messages x2 + INSERT ai_usage_logs
← SendMessageResponse JSON 200
→ FE: thêm bubble ASSISTANT + 3 suggestion + _saveToCache()
```

Nếu lỗi: mọi Exception từ service/controller → `GlobalExceptionHandler` → JSON ApiErrorDTO → FE đọc `message` → rollback UI + hiển thị lỗi.

### Important Code

```java
// AIAssistantService.java:88 — Guardrail L3, quyết định có tốn tiền gọi LLM hay không
ScopeGuardrailService.ScopeCheckResult scopeCheck =
        scopeGuardrailService.checkScope(lesson, request.getMessage(), practiceQuestions);
String replyText;
boolean outOfScope = !scopeCheck.inScope();
if (outOfScope) {
    // Bi chan o lop 3 -> KHONG goi Gemini, dung cau tra loi tu choi co san
    replyText = promptBuilder.buildOutOfScopeFallback(lesson);
}
```

---

## 3. Luồng 2 — Exam → Phân tích điểm yếu → Recommend khóa học → Tạo Learning Pathway

### Business Flow

Sau khi làm Exam (thi thử THPT), hệ thống phân tích **câu SAI** để suy ra kỹ năng yếu, dùng AI gợi ý 3 khóa học phù hợp, rồi tạo **Learning Pathway** 
(lộ trình cá nhân hóa nhiều bước) dựa trên **10 bài thi gần nhất** — phân biệt "lỗi vừa mắc" (latest) và "lỗi kinh niên" (chronic).

Gồm 4 chặng:
1. Nộp bài thi → lưu `exam_attempts.answers_json` (nguồn dữ liệu của toàn bộ phân tích sau này).
2. Trang kết quả: client tự tính skill yếu nhất + gọi AI recommend 3 khóa.
3. User đặt mục tiêu (target score + số tuần) → bấm Create Pathway.
4. Backend gọi Gemini sinh lộ trình JSON → validate courseId → lưu DB → trả pathway.

### UI Flow

**Chặng 1 — làm thi & nộp (`presentation/pages/exam/take_exam_page.dart`):**
- `_loadQuestions()` (dòng 49): GET `/api/v1/exams/{id}/questions` khi mở trang.
- User bấm Submit → dialog confirm → `_confirmSubmit()` (dòng 278) → `_clearCache()`, cancel timer → `_saveAttemptToHistory()` (dòng 422).
- Xong → `Navigator.pushReplacement` sang `ExamResultPage(exam, score, correctCount, examQuestions, userAnswers, attempt)` (dòng 250–275).

**Chặng 2 — trang kết quả (`presentation/pages/exam/exam_result_page.dart`):**
- `initState()` (dòng 57) chạy song song 4 việc: `_analyzeSkills()`, `_loadRecommendations()` (rule-based), `_loadAttempts()`, `_loadAiRecommendations()` (AI).
- UI hiện: điểm, biểu đồ accuracy theo skill, **bong bóng AI weaknessSummary + 3 khóa AI recommend** (nếu AI ok), nếu không thì 3 khóa rule-based.

**Chặng 3 — đặt mục tiêu:**
- Bấm nút **"Update Master Pathway"** (dòng ~831) → mở `PathwayGoalDialog` (`presentation/widgets/learner/pathway_goal_dialog.dart`) truyền `weakestSkill` + 
examAttemptId.
- Dialog fetch điểm trung bình, user chọn target score + số tuần → confirm "Yes, Create" → `_createPathway()`.

**Chặng 4:** tạo xong → `Navigator.pushReplacement` sang `LearningPathwayPage` (pathway_goal_dialog.dart dòng 277–280).

### Frontend Flow

**Chặng 1 — `_saveAttemptToHistory()` (take_exam_page.dart:422):**
- Đổi map đáp án `userAnswers[index] → {"1": selectedOption, ...}` (key tăng lên 1 để khớp đánh số câu).
- `ExamRepository.submitExamAttempt(widget.exam.id, 0.0, answersForSubmit)` — **score gửi lên là 0**, backend tự chấm lại.
- Lỗi submit → catch, return null → ExamResultPage nhận attempt fallback tự dựng local (không có id → AI recommend sẽ bị skip!).

**Chặng 2 — `ExamResultPage`:**
- `_analyzeSkills()` (dòng 83): đếm total/correct per skill từ `widget.attempt['correctness']` (map "1"→true/false do backend trả trong attemptDTO); accuracy 
thấp nhất → `_weakestSkill`. **Phân tích này chạy trên CLIENT, không gọi API.**
- `_loadAiRecommendations()` (dòng 128):
  - Lấy `latestAttemptId` từ `attempt['id']`/`['attemptId']`; null → bỏ qua AI, giữ rule-based.
  - `ExamAIRecommendationRepository.recommendCoursesAI(examAttemptId, weakestSkill)`.
  - Parse `weaknessSummary` + `recommendedCourses[]` vào state.
  - Catch mọi exception → debugPrint + clear state (UI tự lùi về rule-based, **không hiện lỗi cho user**).
- `_loadRecommendations()` (dòng 176): rule-based fallback — filter course theo keyword grammar/vocabulary/reading trong title/category, không khớp thì lấy 
top rating.

**Chặng 3 — `PathwayGoalDialog._createPathway()` (pathway_goal_dialog.dart ~dòng 262):**
- `goalName = "Target Score: $_selectedScore"`; `targetDate = hôm nay + weeks*7` (format yyyy-MM-dd); **hoursPerWeek hardcode = 5** (dialog chưa có ô nhập).
- `PathwayRepository.generatePathway(examAttemptId, goalName, targetDate, hoursPerWeek)`.
- Lỗi → `_errorMessage = "Failed to create pathway. Please try again."` (dialog giữ nguyên cho thử lại).

### API Flow

```
# Chặng 1
POST /api/v1/exams/{id}/submit
Body: { "score": 0.0, "answers": { "1": 2, "2": 0, ... } }     # questionNumber -> selectedOptionIndex
← 200 ExamAttemptResponseDTO { id, attemptNumber, score, correctness{"1":true}, answers, ... }

# Chặng 2
POST /api/v1/exams/ai/recommend-courses
Body: { "examAttemptId": 99, "weakestSkill": "Reading Comprehension" }
← 200 { "examAttemptId": 99, "weaknessSummary": "...",
        "recommendedCourses": [ {courseId, title, category, difficulty, reasonWhy, thumbnailUrl} ] }

# Chặng 3+4
POST /api/v1/pathways/generate
Body: { "examAttemptId": 99, "goalName": "Target Score: 8",
        "targetDate": "2026-10-03", "hoursPerWeek": 5 }
← 200 LearningPathwayResponseDTO { pathway_id, roadmap_id, mentor_summary,
        nodes[ {step, courseId, courseTitle, status, reasonWhy, tags[], progressPercent} ],
        total_steps, completed_steps, weak_skills, latest_weak_skills, suggested_actions, ... }
```

⚠️ Chú ý format JSON response pathway dùng **snake_case** (`pathway_id`, `mentor_summary`) do `@JsonProperty` trong DTO — FE model phải map đúng các key này.

### Backend Flow

#### 4a. Lưu attempt — `controller/ExamController.java` + `service/ExamService.java`

- `ExamController.submitExam()` (dòng 76–87): `@PreAuthorize("hasAuthority('ATTEMPT_QUIZ_AND_EXAM') or hasAuthority('MANAGE_ACCOUNTS_ROLES') or 
hasRole('ADMINISTRATOR')")`. `getCurrentUserId()` từ SecurityContext → null thì trả **401** thẳng.
- `ExamService.saveExamAttempt()` (dòng 135):
  1. Load `Exam`, load `User` (RuntimeException nếu thiếu → 500).
  2. `nextAttemptNumber = countByExamIdAndStudentId + 1`.
  3. `enrichAnswers(rawAnswers, examQuestions)` (dòng 178): sort theo số câu, với mỗi câu tạo record:
     `{questionId, userAnswer, isCorrect (so options[selected].isCorrect), correctAnswer, skill (question.skillParam.paramValue), topic}` — **skill/topic 
được đóng dấu vào từng câu trả lời tại đây**.
  4. `answersJson = objectMapper.writeValueAsString(enrichedAnswers)` — TEXT column.
  5. **Backend tự chấm:** `score = 10 * correctCount / tổng câu`, scale 2 (HALF_UP). FE gửi 0.0 chỉ là placeholder.
  6. INSERT `exam_attempts{exam_id, student_id, score, answers_json, started_at (=now-duration), submitted_at=now}`.
  7. `mapToAttemptDTO` trả kèm map `correctness` mà FE dùng vẽ kết quả.

#### 4b. AI recommend — `controller/ExamCourseRecommendationController.java` + `service/ExamCourseRecommendationAIService.java`

- Controller (dòng 35–48): `@PostMapping("/exams/ai/recommend-courses")` — **KHÔNG có @PreAuthorize**, chỉ check thủ công `userId == null → 401` (dòng 40–42). 
Comment trong code thú nhận "(MVP) Không validate ownership". ⚠️ Nghĩa là user A authenticated có thể truyền examAttemptId của user B → đọc được 
weaknessSummary sinh từ bài thi của B (IDOR mức thông tin).
- `ExamCourseRecommendationAIService.recommendCoursesAI()` (dòng 43):
  1. `examAttemptId == null` → ApiException **400**; `findById` → **404**.
  2. `examResultAnalyzerService.analyzeLatestExamAttempt(attempt)` — phân tích CHỈ bài vừa nộp.
  3. Load courses chưa soft-delete (`deletedAt == null`).
  4. `skillCategoryMappingService.getCategoryForSkill(weakestSkill)` → categoryHint buộc AI ưu tiên category tương ứng.
  5. System prompt: vai "Duolingo-style study buddy", liệt kê `[AVAILABLE_COURSES]` (ID/title/category/difficulty), `TOOL INPUT` gồm score_avg_hint + 
knowledge_gaps_json + explicit_weakest_skill; **ep trả JSON schema** `{weaknessSummary, recommendedCourses[{courseId,reasonWhy}]×3}`; luật "chỉ được chọn 
courseId tồn tại, không bịa".
  6. `generateChatResponse` → strip ```json fences → `objectMapper.readValue(Map)`.
  7. Map ngược `courseId` về Course thật để lấy title/category/difficulty/thumbnail; courseId lạ → field rỗng (không crash).
  8. **Catch-all:** mọi exception → log warn + trả response RỖNG (`weaknessSummary:""`, `recommendedCourses:[]`) — FE tự lùi rule-based. Đây là graceful 
degradation chủ đích.

#### 4c. Phân tích điểm yếu — `service/ExamResultAnalyzerService.java`

Hàm trung tâm `analyzeLearnerAttempts(learnerId, attempts)` (dòng 67) — dùng cho pathway (10 attempts):

1. Với từng attempt: `extractKnowledgeGapsPlaceholder(attempt.getAnswersJson())` (dòng 253):
   - Parse answersJson thành `List<UserAnswerDTO>` (có sẵn `skill`, `topic`, `isCorrect` do 4a đóng dấu).
   - Lọc `isCorrect == false` → `weak_skills` (set skill sai), `critical_topics` (top 5 topic sai nhiều nhất), `incorrect_count`, `weak_categories` 
(map skill→category).
   - Parse fail → fallback trả nguyên raw answersJson (không đứt flow).
2. Merge theo **tần suất**: `weakSkillCount.merge(skill, 1, Integer::sum)` — skill sai ở nhiều attempt xếp trước (dòng 79–106).
3. Tổng hợp: `weak_skills` (top 10), `weak_categories`, `latest_*` (riêng attempt mới nhất), `critical_topics`, `attempts_used`, `score_avg/min/max` 
→ serialize thành `knowledge_gaps_json`.
4. Output `ExamResultAnalysisDTO{examAttemptId, score, rawAnswersJson, knowledgeGapsJson, hints}`.

`analyzeLatestExamAttempt()` (dòng 43) — bản đơn giản cho 4b: chỉ bọc answersJson + score.

#### 4d. Tạo pathway — `controller/LearningPathwayController.java` + `service/LearningPathwayService.java`

- `generatePathway()` controller (dòng 38–53): `@PreAuthorize("hasAuthority('ENROLL_AND_LEARN_COURSES')")` + `@Valid PathwayGenerateRequestDTO` 
(`examAttemptId` `@NotNull`; goalName/targetDate/hoursPerWeek/preferredStudyDays/onlyFree optional).
- `LearningPathwayService.generatePathway(studentId, dto)` (dòng 56) — hàm dài nhất, thứ tự:
  1. `userRepository.findByIdForUpdate(studentId)` — **pessimistic lock** chống double-submit.
  2. Load attempt; `attempt.student.id != studentId` → **403** (ownership check — khác controller recommend!).
  3. Courses: lọc `status == PUBLISHED`; nếu rỗng thì fallback dùng tất cả course chưa xóa (flag `usingExistingCoursesFallback`); `onlyFree` lọc 
price ≤ 0; rỗng hoàn toàn → `createEmptyPathway` (pathway ACTIVE 0 node + summary giải thích).
  4. `findTop10ByStudent_IdOrderBySubmittedAtDesc` → `analyzeLearnerAttempts` → extract `weakCategories` + `latestWeakCategories` → dựng 2 dòng 
HINT (LATEST xử lý TRƯỚC, HISTORICAL củng cố SAU).
  5. System prompt (dòng 123–165): luật chỉ chọn course_id có thật, foundations trước, ưu tiên weak_skills, mentor_summary phải so sánh latest_score 
vs score_avg, JSON format mẫu với tag `#New Vulnerability` / `#Chronic Weakness`. Kèm `[AVAILABLE_COURSES]` + TOOL INPUT (examAttemptId, latest_score, 
knowledge_gaps_json) + goalText.
  6. `userContent` = answersJson của attempt hiện tại.
  7. Gọi Gemini → strip fences → `readValue(LearningPathwayResponseDTO.class)`. Fail → `buildFallbackPathwayDto()` (dòng 727): sort course khớp 
weakCategories lên trước, lấy tối đa 4 node, node 1 IN_PROGRESS còn lại LOCKED.
  8. `archiveActivePathway(studentId)` (dòng 718): pathway ACTIVE cũ → `ARCHIVED`, **set examAttempt=null** (tránh vi phạm @OneToOne khi pathway 
mới tái dùng cùng attempt).
  9. Build `LearningPathway{student, examAttempt, mentorSummary, status=ACTIVE, goalName, targetDate, hoursPerWeek, scheduleStatus=ON_TRACK nếu 
có targetDate}`.
  10. Loop `responseDto.nodes`: **chỉ chấp nhận courseId tồn tại trong availableCourses** (courseId AI bịa bị bỏ im lặng); `normalizeNodeStatus` — 
node đầu IN_PROGRESS, còn lại LOCKED; tags join "," hoặc mặc định `#category`.
  11. Nodes rỗng → `addFallbackNodes` (4 course đầu).
  12. Có targetDate + hoursPerWeek > 0 → `applyTimeboxing(...)`.
  13. `learningPathwayRepository.save(newPathway)` → cascade INSERT nodes.
  14. `toResponseDto(savedPathway, studentId)` (dòng 524):
      - Với từng node: tính **real progress** từ `lesson_progress` (`calculateCourseProgressPercent` = completed/total lessons × 100), auto-sync 
status (progress ≥100 → COMPLETED dù AI nói gì; progress >0 mà LOCKED → IN_PROGRESS).
      - Extract `weakSkills` từ 10 attempts (phục vụ Skill Analysis Panel FE).
      - `suggestedActions` theo ngữ cảnh: luôn FAST_TRACK cho node đang học; TAKE_QUIZ nếu 0<progress<50; TAKE_NEW_EXAM khi hoàn thành hết; 
ADJUST_SCHEDULE nếu BEHIND/AT_RISK; luôn WHAT_WILL_I_LEARN.
      - `roadmapId = "RM_USER_" + studentId + "_" + pathwayId`.

### Database Flow

| Bảng | Thao tác | Nội dung |
|---|---|---|
| `exam_attempts` | INSERT (chặng 1) | exam_id, student_id, score (backend chấm), answers_json TEXT |
| `learning_pathways` | UPDATE (chặng 4) | pathway cũ ACTIVE → status=ARCHIVED, exam_attempt_id=NULL |
| `learning_pathways` | INSERT (chặng 4) | student_id, exam_attempt_id, mentor_summary TEXT, status=ACTIVE, goal_name, target_date, hours_per_week, 
schedule_status |
| `pathway_nodes` | INSERT xN (cascade) | pathway_id, step_order, course_id, status, reason_why TEXT, tags, progress_percent=0 (+ schedule fields
 nếu timeboxing) |

Entities: `entity/LearningPathway.java` (@Table learning_pathways, `@ManyToOne student`, `@OneToOne examAttempt`, `@OneToMany(nodes, cascade ALL, 
orphanRemoval)`, `addNode()` set 2 chiều), `entity/PathwayNode.java` (status default "LOCKED", nodeType/rerouteReason/isOptional/skippedAt cho agentic, 
startDate/deadline/estimatedHours/scheduleStatus cho timeboxing, masteryScore/isMastered/nextReviewDate/reviewIntervalDays cho mastery).

### Exception & Error Handling

| Lỗi | Ném ở | HTTP | FE phản ứng |
|---|---|---|---|
| Submit thiếu token/quyền | @PreAuthorize ExamController.submitExam | 403 | take_exam_page catch → attempt=null → result page vẫn mở nhưng không 
có id AI |
| PathwayGenerate examAttemptId=null | @Valid | 400 | dialog hiện "Failed to create pathway" |
| Attempt không thuộc user | LearningPathwayService dòng 64 | 403 | như trên |
| Attempt/course/user không tồn tại | orElseThrow ApiException | 404 | như trên |
| Gemini fail khi recommend | catch-all ExamCourseRecommendationAIService dòng 165 | **200 với data rỗng** | UI lùi rule-based, KHÔNG lỗi |
| Gemini fail khi generate pathway | catch LearningPathwayService dòng 182 | **200 với fallback deterministic** | UI vẫn hiện pathway (không biết 
là fallback) |
| Course list rỗng | createEmptyPathway | 200, pathway 0 node | UI hiện summary giải thích |

Điểm mấu chốt cần nói với hội đồng: **2 chỗ gọi AI trong flow này đều có fallback "mềm"** — hệ thống không bao giờ 500 chỉ vì Gemini chết.

### Authentication & Authorization (so sánh 3 endpoint)

| Endpoint | URL-level | Method-level | Ownership check |
|---|---|---|---|
| POST /exams/{id}/submit | authenticated (anyRequest) | ATTEMPT_QUIZ_AND_EXAM / MANAGE_ACCOUNTS_ROLES / ADMINISTRATOR | attempt gắn currentUser |
| POST /exams/ai/recommend-courses | authenticated | ❌ không có | ❌ không (comment MVP thừa nhận) |
| POST /pathways/generate | authenticated | ENROLL_AND_LEARN_COURSES | ✅ 403 nếu attempt không phải của mình |

### Complete Data Flow

```
[Submit]
TakeExamPage._saveAttemptToHistory        [take_exam_page.dart:422]
→ ExamRepository.submitExamAttempt        [exam_repository.dart:88]  POST /exams/{id}/submit
→ ExamController.submitExam               [ExamController.java:78]
→ ExamService.saveExamAttempt             [ExamService.java:135]
   enrichAnswers (isCorrect/skill/topic) → INSERT exam_attempts
← ExamAttemptResponseDTO (id, score, correctness)
→ Navigator.pushReplacement(ExamResultPage)

[Recommend]
ExamResultPage._analyzeSkills (client)    → weakestSkill
ExamResultPage._loadAiRecommendations     [exam_result_page.dart:128]
→ ExamAIRecommendationRepository          [exam_ai_recommendation_repository.dart:11]  POST /exams/ai/recommend-courses
→ ExamCourseRecommendationAIService.recommendCoursesAI  [ExamCourseRecommendationAIService.java:43]
   analyzeLatestExamAttempt → prompt(courseList+gaps) → Gemini → parse JSON → map course thật
← weaknessSummary + recommendedCourses[3]

[Create Pathway]
PathwayGoalDialog._createPathway          [pathway_goal_dialog.dart:262]
→ PathwayRepository.generatePathway       [pathway_repository.dart:37]  POST /pathways/generate
→ LearningPathwayController.generatePathway  [LearningPathwayController.java:40] @PreAuthorize ENROLL_AND_LEARN_COURSES
→ LearningPathwayService.generatePathway  [LearningPathwayService.java:56]
   lock user → check ownership 403 → published courses → analyzeLearnerAttempts(top10)
   → prompt → Gemini → parse/fallback → archiveActivePathway → insert pathway+nodes → applyTimeboxing
← LearningPathwayResponseDTO
→ pushReplacement(LearningPathwayPage)
```

### Important Code

```java
// ExamService.java:229-235 — mỗi câu SAI được đóng dấu skill/topic => nền tảng của toàn bộ phân tích điểm yếu
String skill = question != null && question.getSkillParam() != null
        ? question.getSkillParam().getParamValue() : "GENERAL";
record.put("isCorrect", isCorrect);
record.put("skill", normalizeSkill(skill));
record.put("topic", normalizeSkill(skill));

// LearningPathwayService.java:107-117 — "phan tich kep": loi vua mac vs loi kinh nien
List<String> weakCategories = extractWeakCategories(examAnalysis.getKnowledgeGapsJson());
List<String> latestWeakCategories = extractLatestWeakCategories(examAnalysis.getKnowledgeGapsJson());
// HINT (LATEST EXAM): ... These should be addressed FIRST in the pathway.
// HINT (HISTORICAL): ... reinforced AFTER addressing the latest failures.
```

---

## 4. Luồng 3 — Bên trong Learning Pathway

Pathway sau khi tạo là một **hệ sống**: node mở khóa dần, có mentor chat, tự chèn khóa remedial khi học kém (detour), cho skip khi giỏi 
(fast-track), chia lịch học theo giờ/tuần (time-boxing), và spaced-repetition on tap lại kiến thức (mastery).

### UI Flow

Trang chính: `presentation/pages/learner/learning_pathway_page.dart` — `LearningPathwayPage`.

- `initState` → `_loadPathway()` (dòng 36): GET `/api/v1/pathways/me`. 404 → empty-state *"No active pathway yet. Finish an exam..."*; thành 
công → `_preparePathwayForDisplay()` (dòng 106): **client-side display trick** — node LOCKED đầu tiên sau chuỗi COMPLETED được vẽ thành 
IN_PROGRESS (unlock cảm quan), không đổi DB.
- Layout gồm: `PathwaySummaryHeader` (goal/date/hours/schedule status), `InteractiveNodeTree` (danh sách node card: step badge, status pill, 
skill tag, progress bar, schedule chip), `SkillAnalysisPanel` (bottom sheet weak skills), `DailyPlanCard`, `AIMentorSidePanel` (panel chat phải).
- Tương tác chính:
  - Tap node → `_handleNodeTap` chọn node (highlight + context cho mentor panel).
  - Tap course trong node → mở `CourseDetailPage` học tiếp.
  - Nút Fast-track trên node đang học → `_handleFastTrack(node)` (dòng 192).
  - Hoàn thành node → panel hiện bubble *"unlocked next"*.
  - Edit goal (icon header) → `_showEditGoalDialog` → `EditGoalDialog` → PUT schedule.

### Frontend Flow

**Load pathway — `data/repositories/pathway_repository.dart`:**
- `getMyPathway()` (dòng 10): lấy `auth_token` từ SharedPreferences → GET `$baseUrl/pathways/me` với `Authorization: Bearer` → !=200 throw 
Exception kèm statusCode+body → parse `LearningPathway.fromJson`.

**Fast-track — `_handleFastTrack` (learning_pathway_page.dart:192):**
1. AlertDialog confirm "You are about to skip this course...".
2. `_repository.sendMentorAction(pathwayId, actionType:'FAST_TRACK')` (repository dòng 263) → POST `/pathways/{id}/mentor-action` body 
`{actionType, payload?}`.
3. Nhận pathway mới → setState cập nhật UI + SnackBar xanh; lỗi → SnackBar đỏ.

**Mastery — `_submitMastery(nodeId, score)` (dòng 137):**
- `submitNodeMastery(pathwayId, nodeId, score)` → POST `/pathways/{id}/nodes/{nodeId}/mastery` body `{score}` → cập nhật pathway → SnackBar.

**Edit schedule — EditGoalDialog:**
- `schedulePathway(goalName, targetDate, hoursPerWeek)` → PUT `/pathways/{id}/schedule` → nhận pathway mới có startDate/deadline per node.

**Mentor chat — `widgets/learning_pathway/ai_mentor_side_panel.dart`:**
- `_loadHistory()` (dòng ~53): GET `/pathways/{id}/chat/history` nạp tin nhắn cũ.
- `_sendChatMessage(message)` (dòng 207): thêm bubble user ngay (optimistic) → `sendChatMessage(pathwayId, message, conversationId, 
selectedNodeCourseId)` → POST `/pathways/{id}/chat` body `{message, conversation_id?, selected_node_course_id?}` → thêm bubble mentor 
+ cập nhật `_dynamicSuggestedQuestions` từ `response['suggested_questions']`.
- Lỗi → bubble *"Lỗi kết nối. Vui lòng thử lại sau."* (catch dòng 246–253).
- `_clearChatHistory()` (dòng 94): DELETE `/pathways/{id}/chat/history`.

**Agentic reroute (Feature A):**
- Repository có `suggestReroute/acceptReroute/declineReroute` (pathway_repository.dart dòng 78–88) → POST `/reroute/suggestions|accept|decline`; 
response có thể mang `pending_reroute_suggestion` để UI hỏi user accept/decline.

### API Flow

```
GET    /api/v1/pathways/me                                   → pathway ACTIVE của user
PUT    /api/v1/pathways/{id}/schedule                        → áp timeboxing mới
POST   /api/v1/pathways/{id}/nodes/{nodeId}/mastery {score}  → spaced repetition
POST   /api/v1/pathways/{id}/mentor-action {actionType}      → FAST_TRACK / ADJUST_SCHEDULE /
                                                                TAKE_QUIZ / WHAT_WILL_I_LEARN
GET    /api/v1/pathways/{id}/progress-snapshot               → snapshot % + failStreak + latestScore
POST   /api/v1/pathways/{id}/reroute/suggestions             → policy đánh giá, gắn pending_reroute_suggestion
POST   /api/v1/pathways/{id}/reroute/accept                  → áp mutation (skip/detour)
POST   /api/v1/pathways/{id}/reroute/decline                 → trả pathway hiện tại, không đổi
POST   /api/v1/pathways/{id}/chat                            → mentor chat
GET    /api/v1/pathways/{id}/chat/history                    → flatten toàn bộ tin nhắn
DELETE /api/v1/pathways/{id}/chat/history                    → xoá conversations
(PUT   /api/v1/pathways/{id}/reroute                          → bản reroute đơn giản theo điểm, ít dùng)
```

Tất cả đều `@PreAuthorize("hasAuthority('ENROLL_AND_LEARN_COURSES')")` + `@AuthenticationPrincipal UserDetailsImpl userDetails` → 
`userDetails.getId()` làm learnerId.

### Authentication

Giống chung hệ thống (mục 5.4): JwtAuthFilter verify Bearer token → UserDetailsImpl vào context → controller lấy `userDetails.getId()`.

### Authorization

Ngoài @PreAuthorize permission, **mọi thao tác pathway đều có ownership check trong service**: `pathway.getStudent().getId().equals(userDetails.getId())` 
— không khớp → `ApiException("Access denied", 403)`. Ví dụ `getPathwayById` (LearningPathwayService dòng 285), `rerouteAccept` trong controller 
(dòng 172–174), `chat` (PathwayMentorChatService dòng 50). ⇒ User A không thể đọc/sửa/chat trên pathway của user B kể cả khi đủ quyền LEARNER.

### Backend Flow

#### 4a. Time-boxing — `applySchedule` + `applyTimeboxing`

- `applySchedule` (LearningPathwayService dòng 451): ownership check → set goalName/targetDate/hoursPerWeek/scheduleStatus=ON_TRACK → 
`applyTimeboxing` → save.
- `applyTimeboxing` (dòng 482):
  1. Ước lượng giờ mỗi node = `lessonRepository.countByCourseId × 2` (node COMPLETED = 0).
  2. `PathwayTimeboxingScheduler.scheduleForward(hôm nay, hoursPerWeek, preferredStudyDays, estimatedHours, n)` 
(PathwayTimeboxingScheduler.java dòng 238) — **thuần toán, không DB**:
     - Ngày làm mặc định T2–T7 (Sun=7 loại nếu không chọn); sort Mon..Sun.
     - `baseHoursPerDay = max(1, hoursPerWeek / workingDaysPerWeek)`, phần dư +1 giờ rải vào ngày đầu tuần.
     - Dựng calendar các working day từ startDate tiến tới khi đủ tổng giờ (cap an toàn 5000 vòng).
     - Chia từng block working-days liền kề cho từng node theo thứ tự → `startDate`= ngày đầu block, `deadline`=`23:59` ngày cuối block.
  3. Gán `node.startDate/deadline/estimatedHours`; `scheduleStatus = BEHIND` nếu deadline vượt targetDate hoặc đã quá quá khứ, ngược lại 
ON_TRACK (dòng 497–521). Node COMPLETED giữ nguyên lịch cũ.

#### 4b. Mentor action — `processMentorAction` (LearningPathwayService dòng 301)

Switch theo `actionType`:
- `FAST_TRACK` (dòng 311): tìm node IN_PROGRESS → `nodeType=FAST_TRACK_SKIPPED, isOptional=true, skippedAt=now, status=COMPLETED, 
rerouteReason="Skipped by learner via Fast Track action"` → unlock node stepOrder+1 nếu LOCKED → mentorSummary ✅.
- `ADJUST_SCHEDULE` (dòng 337): đọc payload.hoursPerWeek → set → `applyTimeboarding lại` → ON_TRACK; thiếu targetDate/hours → AT_RISK + cảnh báo.
- `TAKE_QUIZ` (dòng 357): `generateMiniQuiz(currentNode)` (dòng 407) — **lần gọi Gemini nữa**: prompt tạo 3 MCQ về course đang học, format markdown;
 lỗi → câu thông báo.
- `WHAT_WILL_I_LEARN` (dòng 363): overview thuần code (không AI): goal, tiến độ x/y, từng bước kèm emoji trạng thái.

#### 4c. Agentic reroute — Snapshot → Policy → Mutation

1. **Snapshot** — `PathwayProgressSnapshotService.getProgressSnapshot` (dòng 28): ownership (IllegalArgumentException nếu sai); 
per node: progressPercent từ lesson_progress; **failStreak** = số lần thi LessonQuiz liên tiếp (mới nhất trước) có score < 60; latestScore của 
attempt mới nhất; hasWeakSkillOverlap=false (chưa implement — comment trong code).
2. **Policy** — `PathwayReroutePolicyService.evaluate` (dòng 29):
   - Ưu tiên **DETOUR_REQUIRED**: node IN_PROGRESS && failStreak ≥ 2.
   - Sau đó **FAST_TRACK_ELIGIBLE**: node trước COMPLETED với latestScore == 100.0 && node kế LOCKED/IN_PROGRESS && hasWeakSkillOverlap == false.
   - Còn lại NO_CHANGE.
3. **Suggestions endpoint** (controller dòng 130–152): chạy snapshot+policy; action ≠ NO_CHANGE → gắn `pendingRerouteSuggestion{nodeType: 
FAST_TRACK_SKIPPED|DETOUR_REMEDIAL, rerouteReason, canSkip, blockedReason}` vào response (không sửa DB).
4. **Accept** (controller dòng 164–188): ownership check → re-evaluate policy →
   - FAST_TRACK → `PathwayMutationService.applyFastTrackSkip` (dòng 29): mark node COMPLETED/skipped, unlock kế tiếp, save node, **ghi 
audit `pathway_events`** (beforeJson/afterJson/eventType/reason).
   - DETOUR → `applyDetourInsertion` (dòng 60): đẩy stepOrder các node sau +1 & LOCKED, chèn node mới `DETOUR_REMEDIAL, IN_PROGRESS, 
parentNodeId=node thất bại`; ⚠️ course remedial hiện dùng placeholder `pathway.getNodes().get(0).getCourse()` (comment trong code thừa 
nhận cần tool suggestRemedialCourseOrLesson thật).
5. **Decline** (dòng 190–197): chỉ trả pathway hiện tại.

#### 4d. Mastery & Spaced Repetition — `submitNodeMastery` (LearningPathwayService dòng 652)

- ownership + tìm node trong pathway (404 nếu sai nodeId).
- Set `masteryScore = request.score`.
- **score ≥ 80** → `isMastered=true`; khoảng cách ô tăng dần `1→3→7→14→30` ngày (nhánh if/else dòng 664–673); `nextReviewDate = now + 
interval`; mentorSummary chúc mừng.
- **score < 80** → isMastered=false + nhắc cần 80 điểm.
- Không gọi repository.save(node) tường minh nhưng entity nằm trong persistence context của `@Transactional` → Hibernate dirty-checking 
tự flush khi transaction commit. (Câu hỏi hay: "sao không thấy save?" — dirty checking.)

#### 4e. Mentor chat — `PathwayMentorChatService.chat` (dòng 42)

1. Checks: learnerId null → 401; pathway 404; ownership → 403.
2. `getOrCreateConversation` (dòng 206): theo conversationId, không thì lấy conversation mới nhất của pathway, không có thì tạo mới — bảng 
`pathway_conversations`/`pathway_messages` (entity `PathwayConversation`, `PathwayMessage`).
3. `buildPathwaySystemPrompt` (dòng 226): vai **AI Mentor định hướng lộ trình — CẤM giải học thuật**, hướng user sang AI Assistant trong 
Lesson; nhúng: goal/targetDate/hoursPerWeek/scheduleStatus, danh sách node kèm **progress % tính live từ lesson_progress**, knowledge_gaps_json 
từ 10 attempts, thông tin course của node đang chọn (selectedNodeCourseId).
4. `buildGeminiHistory` (dòng 304): chỉ 10 message gần nhất (`MAX_HISTORY_MESSAGES`), bỏ msg out-of-scope.
5. Out-of-scope **pre-check bằng keyword** (`isClearlyOutOfScope`, dòng 119): có signal học tập (hoc/exam/grammar...) → cho qua; không 
signal + chứa từ khoá lạc đề (bitcoin/crypto/thoi tiet...) → chặn, trả fallback (không gọi Gemini). Khác với chatbox: đây là heuristic từ 
khoá, không phải embedding.
6. Gọi Gemini bọc try/catch → lỗi kỹ thuật → câu fallback *"Xin lỗi, tôi đang gặp sự cố kỹ thuật..."* (HTTP vẫn 200).
7. Post-check: reply chứa "ngoài phạm vi"/"out of scope" → mark outOfScope.
8. Save 2 message; `generateSuggestedQuestions` (dòng 344) — lần gọi Gemini thứ 2, prompt cấm gợi ý câu hỏi lý thuyết; regex parse ≤3 câu; 
fail → list rỗng.
9. Trả `PathwayChatResponseDTO{conversation_id, role:"ASSISTANT", reply, was_out_of_scope, suggested_questions}`.

### Database Flow

| Bảng | Thao tác | Khi nào |
|---|---|---|
| `learning_pathways` | UPDATE | schedule (goal/targetDate/hours/scheduleStatus), mentor-action (mentorSummary), mastery (mentorSummary) |
| `pathway_nodes` | UPDATE | fast-track/detour/mastery/timeboxing (status, node_type, skipped_at, start_date, deadline, mastery_score...) |
| `pathway_nodes` | INSERT | detour insertion (node remedial) |
| `pathway_events` | INSERT | mỗi mutation reroute (audit trail beforeJson/afterJson) |
| `pathway_conversations` / `pathway_messages` | SELECT/INSERT/DELETE | mentor chat |
| `lesson_progress`, `lessons`, `lesson_quiz_attempts` | SELECT only | tính progress %, failStreak |
| `exam_attempts` | SELECT only | knowledge gaps cho prompt |

### Exception & Error Handling

| Lỗi | Ném ở | HTTP | FE |
|---|---|---|---|
| Pathway không tồn tại | orElseThrow ApiException NOT_FOUND (service các hàm) | 404 | getMyPathway: 404 → empty-state |
| Không phải chủ pathway | ApiException FORBIDDEN (mọi service) | 403 | SnackBar đỏ / Exception text |
| Node không thuộc pathway | submitNodeMastery dòng 656 | 404 | SnackBar đỏ |
| Snapshot service dùng IllegalArgumentException (không phải ApiException) | PathwayProgressSnapshotService dòng 30/33 | 500 qua handler 
tổng | — (endpoint ít dùng trên UI) |
| Gemini chết lúc chat | catch trong chat() dòng 80–85 | **200 + câu fallback** | bubble mentor bình thường |
| Gemini chết lúc TAKE_QUIZ | catch trong generateMiniQuiz | 200 + câu fallback | bubble mentor |
| Chat history rỗng/xoá | deleteAll | 200/204 | UI clear |

### Complete Data Flow (ví dụ Fast-track)

```
User bấm Fast-track trên node card
→ InteractiveNodeTree callback → LearningPathwayPage._handleFastTrack   [:192]
→ AlertDialog confirm
→ PathwayRepository.sendMentorAction(actionType:'FAST_TRACK')          [pathway_repository.dart:263]
   POST /api/v1/pathways/{id}/mentor-action {actionType}
→ JwtAuthFilter → @PreAuthorize ENROLL_AND_LEARN_COURSES
→ LearningPathwayController.mentorAction                               [LearningPathwayController.java:201]
→ LearningPathwayService.processMentorAction                           [:301]
   ownership 403? → findCurrentInProgressNode → set COMPLETED/FAST_TRACK_SKIPPED
   → unlock node stepOrder+1 → mentorSummary → save
← LearningPathwayResponseDTO 200
→ setState cập nhật tree + SnackBar "Course fast-tracked successfully!"
DB: pathway_nodes UPDATE (node cũ + node kế), learning_pathways UPDATE mentor_summary
```

### Important Code

```java
// PathwayReroutePolicyService.java:36 — quy tắc DETOUR: thi trượt 2 lần lien tiep => phai chen khoa hoc lai
if ("IN_PROGRESS".equalsIgnoreCase(node.getStatus())
        && node.getFailStreak() != null && node.getFailStreak() >= 2) {
    return new PolicyDecision(PolicyAction.DETOUR_REQUIRED, node, "Learner has failed...");
}

// LearningPathwayService.java:664-674 — spaced repetition 1->3->7->14->30 ngay
if (node.getReviewIntervalDays() == null) {
    node.setReviewIntervalDays(1);
} else {
    int current = node.getReviewIntervalDays();
    if (current == 1) node.setReviewIntervalDays(3);
    else if (current == 3) node.setReviewIntervalDays(7);
    else if (current == 7) node.setReviewIntervalDays(14);
    else if (current == 14) node.setReviewIntervalDays(30);
}
node.setNextReviewDate(java.time.LocalDateTime.now().plusDays(node.getReviewIntervalDays()));
```

---

## 5. API Map (tổng hợp 3 flow + auth)

| # | Method & Path | Quyền | Controller.method | Ghi chú |
|---|---|---|---|---|
| 1 | POST `/api/auth/login` | public | AuthController.authenticateUser | trả JWT + refresh token + roles |
| 2 | GET `/api/v1/ai-assistant/status` | public | AIAssistantController.getStatus | health Gemini, cache `geminiStatus` |
| 3 | POST `/api/v1/ai-assistant/messages` | auth + `AI_LEARNING_ASSISTANT` | AIAssistantController.sendMessage | Flow 1 |
| 4 | GET `/api/v1/ai-assistant/conversations` | auth + `AI_LEARNING_ASSISTANT` | AIAssistantController.getConversations | Flow 1 |
| 5 | GET `/api/v1/exams/{id}/questions` | `ATTEMPT_QUIZ_AND_EXAM`/trainer/CM/admin | ExamController.getExamQuestions | Flow 2 mở đề |
| 6 | POST `/api/v1/exams/{id}/submit` | `ATTEMPT_QUIZ_AND_EXAM`/... | ExamController.submitExam → ExamService.saveExamAttempt | Flow 2 |
| 7 | GET `/api/v1/exams/{id}/attempts` | `ATTEMPT_QUIZ_AND_EXAM`/... | ExamController.getExamAttempts | lịch sử theo exam |
| 8 | GET `/api/v1/exams/my-attempts` | như trên | ExamController.getMyExamAttempts | |
| 9 | GET `/api/v1/exams/users/me/analytics/skills` | như trên | ExamController.getMySkillAnalytics | accuracy per skill (top 10 attempt) |
| 10 | POST `/api/v1/exams/ai/recommend-courses` | chỉ cần đăng nhập ⚠️ | ExamCourseRecommendationController.recommendCoursesAI | Flow 2, không @PreAuthorize |
| 11 | POST `/api/v1/pathways/generate` | `ENROLL_AND_LEARN_COURSES` | LearningPathwayController.generatePathway | Flow 2 |
| 12 | GET `/api/v1/pathways/me` | `ENROLL_AND_LEARN_COURSES` | getMyPathway | pathway ACTIVE duy nhất |
| 13 | GET `/api/v1/pathways/{id}` | `ENROLL_AND_LEARN_COURSES` | getPathwayById | + ownership |
| 14 | PUT `/api/v1/pathways/{id}/reroute` | như trên | reroutePathway | reroute theo điểm gần nhất (<60 reset) |
| 15 | PUT `/api/v1/pathways/{id}/schedule` | như trên | applySchedule | timeboxing |
| 16 | POST `/api/v1/pathways/{id}/nodes/{nodeId}/mastery` | như trên | submitMastery | spaced repetition |
| 17 | POST `/api/v1/pathways/{id}/mentor-action` | như trên | mentorAction | FAST_TRACK/ADJUST_SCHEDULE/TAKE_QUIZ/WHAT_WILL_I_LEARN |
| 18 | GET `/api/v1/pathways/{id}/progress-snapshot` | như trên | progressSnapshot | FE-11 agentic |
| 19 | POST `/api/v1/pathways/{id}/reroute/suggestions` | như trên | rerouteSuggestions | policy evaluate |
| 20 | POST `/api/v1/pathways/{id}/reroute/accept` | như trên | rerouteAccept | mutate pathway |
| 21 | POST `/api/v1/pathways/{id}/reroute/decline` | như trên | rerouteDecline | no-op trả hiện tại |
| 22 | POST `/api/v1/pathways/{id}/chat` | như trên | chat | mentor chat |
| 23 | GET/DELETE `/api/v1/pathways/{id}/chat/history` | như trên | getChatHistory / clearChatHistory | |

## 6. File / Class / Method Map

### Backend (gom theo flow)

| File | Class | Method quan trọng (dòng) | Vai trò |
|---|---|---|---|
| `controller/AIAssistantController.java` | AIAssistantController | sendMessage (40), getConversations (49), getStatus (55), getSafeUserId (63) | Entry Flow 1 |
| `service/AIAssistantService.java` | AIAssistantService | sendMessage (54), getOrCreateConversation (261), createNewConversation (287) | Điều phối guardrail + Gemini + persist |
| `service/ScopeGuardrailService.java` | ScopeGuardrailService | checkScope (39) | Guardrail L3 cosine similarity |
| `service/AIPromptBuilder.java` | AIPromptBuilder | buildSystemPrompt (58), buildOutOfScopeFallback (142) | Guardrail L1 |
| `service/GeminiClientService.java` | GeminiClientService | init (101), checkAvailability (130), generateChatResponse (184), generateEmbedding (235) | Cổng duy nhất tới Gemini |
| `config/GeminiProperties.java` + `application.properties:34-38` | GeminiProperties | — | model/apiKey/timeout |
| `config/AIAssistantProperties.java` | AIAssistantProperties | scopeSimilarityThreshold | ngưỡng guardrail (default 0.0!) |
| `service/LessonEmbeddingService.java` | LessonEmbeddingService | getOrComputeEmbedding (30) | cache embedding bài học |
| `util/VectorUtil.java` | VectorUtil | cosineSimilarity / fromJson / toJson | toán vector |
| `controller/ExamController.java` | ExamController | getExamQuestions (49), submitExam (78), getMyExamAttempts (56) | Entry Flow 2 |
| `service/ExamService.java` | ExamService | saveExamAttempt (135), enrichAnswers (178), toAnswerRecord (190), mapToAttemptDTO (256) | chấm + đóng dấu skill vào answers_json |
| `controller/ExamCourseRecommendationController.java` | ExamCourseRecommendationController | recommendCoursesAI (36) | entry recommend |
| `service/ExamCourseRecommendationAIService.java` | ExamCourseRecommendationAIService | recommendCoursesAI (43) | prompt + parse + fallback rỗng |
| `service/ExamResultAnalyzerService.java` | ExamResultAnalyzerService | analyzeLatestExamAttempt (43), analyzeLearnerAttempts (67), extractKnowledgeGapsPlaceholder (254), getSkillAnalytics (320) | "tool" phân tích điểm yếu |
| `service/SkillCategoryMappingService.java` | SkillCategoryMappingService | getCategoryForSkill | map skill ↔ category |
| `controller/LearningPathwayController.java` | LearningPathwayController | generatePathway (40), getPathwayById (58), getMyPathway (68), reroutePathway (77), applySchedule (88), submitMastery (99), progressSnapshot (124), rerouteSuggestions (132), rerouteAccept (166), mentorAction (201), chat (214) | Entry Flow 2+3 |
| `service/LearningPathwayService.java` | LearningPathwayService | generatePathway (56), reroutePathway (246), processMentorAction (301), applySchedule (451), applyTimeboxing (482), toResponseDto (524), submitNodeMastery (652), archiveActivePathway (718), buildFallbackPathwayDto (727) | não của pathway |
| `service/PathwayProgressSnapshotService.java` | PathwayProgressSnapshotService | getProgressSnapshot (28) | snapshot % + failStreak |
| `service/PathwayReroutePolicyService.java` | PathwayReroutePolicyService | evaluate (29) | DETOUR/FAST_TRACK policy |
| `service/PathwayMutationService.java` | PathwayMutationService | applyFastTrackSkip (29), applyDetourInsertion (61), logEvent (97) | mutate + audit pathway_events |
| `service/PathwayTimeboxingScheduler.java` | PathwayTimeboxingScheduler | scheduleForward (238), buildForwardsCalendar (310) | lịch học deterministic |
| `service/PathwayMentorChatService.java` | PathwayMentorChatService | chat (42), buildPathwaySystemPrompt (226), buildGeminiHistory (304), isClearlyOutOfScope (119), generateSuggestedQuestions (344) | mentor chat |
| `entity/LearningPathway.java`, `PathwayNode.java`, `ExamAttempt.java`, `AIConversation.java`, `AIMessage.java`, `PathwayConversation.java`, `PathwayMessage.java`, `PathwayEvent.java`, `AiUsageLog.java` | — | — | ORM tables |
| `repository/AIConversationRepository.java` | — | findByIdAndLearnerIdWithMessages (15) | JOIN FETCH + lọc learner |
| `security/JwtAuthFilter.java` | JwtAuthFilter | doFilterInternal (30), parseJwt (51) | verify JWT mỗi request |
| `util/JwtUtils.java` | JwtUtils | generateJwtTokenFromUsername (45), validateJwtToken (63), hashToken (94) | sign HS256 + refresh token hash |
| `security/SecurityConfig.java` | SecurityConfig | filterChain (55), corsConfigurationSource (100) | URL rules + CORS |
| `security/UserDetailsImpl.java` | UserDetailsImpl | build (35) | nạp roles + permissions thành authorities |
| `security/CustomAccessDeniedHandler.java` | CustomAccessDeniedHandler | handle (19) | 403 JSON ở filter chain |
| `exception/GlobalExceptionHandler.java` | GlobalExceptionHandler | handleApiException (22), handleValidationException (34), handleAccessDeniedException (102), handleGlobalException (114) | @RestControllerAdvice |
| `service/AuthService.java` | AuthService | authenticateUser (134), issueRefreshToken (117), registerUser (189) | login/register |
| `config/AppConfig.java` | AppConfig | @EnableConfigurationProperties (13) | bật Jwt/Gemini/AIAssistant props |

### Frontend (gom theo flow)

| File | Class/Widget | Method (dòng) | Vai trò |
|---|---|---|---|
| `lib/presentation/pages/course/lesson_detail_page.dart` | LessonDetailPage | — | host LessonAiChatbox |
| `lib/presentation/widgets/lesson_ai_chatbox.dart` | LessonAiChatbox | initState (47), _send (162), _loadFromCache (82), _saveToCache (114), _clearHistory (145) | UI Flow 1 |
| `lib/services/app_state.dart` | AppState | checkAiStatus (141), sendAiMessage (192), _buildAiUrl (120) | provider gọi API Flow 1 |
| `lib/domain/model/ai_models.dart` | AiChatResponse, AiMessage | fromJson | model Flow 1 |
| `lib/presentation/pages/exam/take_exam_page.dart` | TakeExamPage | _confirmSubmit (278), _saveAttemptToHistory (422) | nộp bài Flow 2 |
| `lib/data/repositories/exam_repository.dart` | ExamRepository | submitExamAttempt (88), fetchExamAttempts (36) | HTTP Flow 2 |
| `lib/presentation/pages/exam/exam_result_page.dart` | ExamResultPage | initState (57), _analyzeSkills (83), _loadAiRecommendations (128), _loadRecommendations (176) | kết quả + recommend |
| `lib/data/repositories/exam_ai_recommendation_repository.dart` | ExamAIRecommendationRepository | recommendCoursesAI (11) | HTTP recommend |
| `lib/presentation/widgets/learner/pathway_goal_dialog.dart` | PathwayGoalDialog | _createPathway (~262) | đặt mục tiêu → generate |
| `lib/presentation/pages/learner/learning_pathway_page.dart` | LearningPathwayPage | _loadPathway (36), _preparePathwayForDisplay (106), _submitMastery (137), _handleFastTrack (192) | UI Flow 3 |
| `lib/data/repositories/pathway_repository.dart` | PathwayRepository | getMyPathway (10), generatePathway (37), suggestReroute (78), submitNodeMastery (94), schedulePathway (225), sendMentorAction (263), sendChatMessage (297) | HTTP Flow 3 |
| `lib/presentation/widgets/learning_pathway/ai_mentor_side_panel.dart` | AIMentorSidePanel | _loadHistory (53), _clearChatHistory (94), _sendChatMessage (207) | mentor chat UI |
| `lib/presentation/widgets/learning_pathway/interactive_node_tree.dart` | InteractiveNodeTree | — | cây node |
| `lib/domain/entities/learning_pathway.dart` | LearningPathway, PathwayNode | fromJson/copyWith | model Flow 3 |
| `lib/data/services/auth_service.dart` | AuthService | login (70), _tokenKey='auth_token' (20) | lưu JWT device |
| `lib/services/hango_api.dart` | HangoApi | _send (56), sendMessage (233) | client chung + chuẩn hoá lỗi ApiFailure |

## 7. Error & Exception Map

### Backend

| Nguồn lỗi | Exception | Handler | Status | Message FE nhận được |
|---|---|---|---|---|
| Business logic chủ động | `ApiException(msg, status)` | GlobalExceptionHandler.handleApiException | tuỳ (400/401/403/404/502/503) | đúng msg |
| @Valid fail | MethodArgumentNotValidException | handleValidationException | 400 | `field: message` đầu tiên |
| JSON body hỏng | HttpMessageNotReadableException | handleUnreadableBody | 400 | "Malformed request body." |
| Thiếu param | MissingServletRequestParameterException | handleMissingParam | 400 | param name |
| Sai kiểu param | MethodArgumentTypeMismatchException | handleTypeMismatch | 400 | param name |
| User không tồn tại (auth flow) | UsernameNotFoundException | handleUsernameNotFound | 404 | msg |
| Thiếu quyền | AccessDeniedException | handleAccessDeniedException (method) / CustomAccessDeniedHandler (filter) | 403 | "Access denied. You do not have permission..." |
| Chưa đăng nhập gọi API protected | Anonymous → AccessDenied/EntryPoint | như trên (thực tế trả 403) | 403* | như trên |
| Lỗi chưa lường trước (NPE, DB down...) | Exception | handleGlobalException | 500 | "An internal system error occurred. Please try again later." (stack chỉ in server log) |

\* Điểm cần nhớ: project cấu hình STATELESS + custom handler nên anonymous thường nhận 403 thay vì 401 chuẩn.

### Các điểm "nuốt lỗi" có chủ đích (graceful degradation) — hay bị hỏi!

1. `ExamCourseRecommendationAIService` catch-all → trả data rỗng (FE lùi rule-based).
2. `LearningPathwayService.generatePathway` AI fail → fallback deterministic.
3. `ScopeGuardrailService.checkScope` embedding fail → coi như in-scope.
4. `PathwayMentorChatService.chat` Gemini fail → câu fallback, HTTP 200.
5. `generateMiniQuiz` fail → câu fallback.
6. `suggestedQuestions` parse fail → list rỗng.
7. `recordUsage` fail → log warn, không ảnh hưởng request chính.
8. FE `app_state.sendAiMessage` catch-all → trả reply giả "Error: ...".

## 8. Các kiến thức tôi bắt buộc phải hiểu trước khi bảo vệ

1. **Vòng đời 1 request có JWT** (mục 1.2): ai đọc header, ai verify chữ ký, authorities đến từ đâu, @PreAuthorize chạy lúc nào. 
Phải vẽ được từ trí nhớ.
2. **3 lớp guardrail của chatbox** + nhận xét: threshold guardrail hiện **không được cấu hình trong repo** (default 0.0) → L3 gần 
như luôn pass; chặn thực tế nhờ L1 system prompt. Biết nói: "đây là điểm tôi phát hiện khi review và đề xuất set threshold hợp lý (vd 0.3)".
3. **answers_json là trái tim của Flow 2**: nó được ghi có skill/topic/isCorrect ngay lúc nộp bài (ExamService.enrichAnswers), mọi 
phân tích sau (recommend, pathway, skill analytics, mentor prompt) đều ĐỌC LẠI cột này — không có bảng riêng cho weakness analysis.
4. **"Phân tích kép"** latest vs chronic weak categories và cách 2 HINT được nhét vào prompt pathway.
5. **Prompt engineering là "API" với AI**: AVAILABLE_COURSES giới hạn courseId, JSON schema ép format, strip ```json fences, validate 
courseId khi lưu. AI không được tin tưởng tuyệt đối — luôn có validation + fallback phía sau.
6. **Fallback strategy**: recommend rỗng → rule-based FE; pathway AI fail → deterministic 4 node; mentor chat fail → câu lịch sự. Hệ 
thống không chết khi Gemini chết.
7. **State machine pathway**: LearningPathway.status ACTIVE↔ARCHIVED (1 ACTIVE/user, archive trước khi tạo mới, clear exam_attempt_id 
vì @OneToOne); PathwayNode.status LOCKED → IN_PROGRESS → COMPLETED (+nodeType FAST_TRACK_SKIPPED/DETOUR_REMEDIAL).
8. **Time-boxing là thuật toán deterministic** (không AI): giờ/node = lessons×2, chia block ngày làm liền kề, BEHIND nếu deadline vượt 
targetDate.
9. **Spaced repetition mastery**: ≥80 điểm mastered, interval 1→3→7→14→30 ngày.
10. **Ownership check 2 tầng**: @PreAuthorize (permission chức năng) + so sánh `pathway.student.id == userDetails.id` (dữ liệu của mình)
— và chỗ recommend-courses đang THIẾU cả hai tầng sau.
11. **Transaction & dirty checking**: @Transactional trên service; submitNodeMastery không gọi save nhưng vẫn persist (managed entity). findByIdForUpdate
 = pessimistic lock.
12. **Secrets**: Gemini API key & JWT secret đọc từ biến môi trường (application.properties `${HANGO_GEMINI_API_KEY}`, `${HANGO_JWT_SECRET:...}`); 
refresh token lưu SHA-256 hash, không lưu plaintext.

### Lỗi / rủi ro quan trọng đã phát hiện khi review (nói trước được sẽ ghi điểm)

| # | Vấn đề | Vị trí | Mức độ |
|---|---|---|---|
| 1 | Merge conflict marker còn sót trong comment javadoc | `GeminiClientService.java` dòng 279 `<<<<<<< Updated upstream` | Hygiene (compile bình thường vì nằm trong comment) |
| 2 | `recommend-courses` không có @PreAuthorize + không check ownership attempt | `ExamCourseRecommendationController.java:35-48` | Bảo mật nhẹ (IDOR thông tin) |
| 3 | Threshold guardrail embedding không được cấu hình → default 0.0 | `application.properties` (thiếu) + `AIAssistantProperties` | Chức năng: L3 vô hình |
| 4 | Detour chèn course placeholder (node đầu tiên) chứ không phải course remedial thật | `LearningPathwayController.rerouteAccept:184` | Chức năng (comment code thừa nhận) |
| 5 | `hasWeakSkillOverlap` luôn false | `PathwayProgressSnapshotService:69` | Chức năng: FAST_TRACK policy thiếu 1 điều kiện thật |
| 6 | FE nuốt mọi lỗi AI chat thành reply giả "Error: ..." | `app_state.dart:241-250` | UX/debug |
| 7 | hoursPerWeek hardcode 5 trong PathwayGoalDialog | `pathway_goal_dialog.dart:272` | UX |
| 8 | URL-rule order khiến `/ai-assistant/messages` thực chất permitAll ở filter chain (an toàn nhờ @PreAuthorize) | `SecurityConfig.java:73-75` | Hiểu sâu security |
| 9 | Duplicate builder call `.completedLessons(...)` 2 lần liền | `LearningPathwayService.toResponseDto` | Harmless |

## 9. Các câu hỏi hội đồng có thể hỏi và câu trả lời

**Q1. Sao không dùng thư viện LangChain/lang4j mà tự build prompt?**
A: Mình dùng 1 gateway duy nhất `GeminiClientService` (WebClient + retry 429 + timeout + usage log). Logic nghiệp vụ (guardrail, prompt, fallback) 
là đặc thù HanGo nên tự kiểm soát giúp audit dễ hơn; tích hợp REST thuần cũng giảm dependency.

**Q2. Làm sao đảm bảo AI không "bịa" courseId?**
A: 3 lớp: (1) prompt liệt kê AVAILABLE_COURSES + luật cấm bịa; (2) khi lưu node chỉ chấp nhận courseId tồn tại trong availableCourses — node bịa bị 
bỏ qua âm thầm (LearningPathwayService dòng 202-209); (3) nếu sau validation không còn node nào → addFallbackNodes từ course thật.

**Q3. Gemini trả JSON hỏng thì sao?**
A: Strip markdown fence rồi Jackson parse; fail → catch → pathway dùng fallback deterministic (ưu tiên course khớp weak category, tối đa 4 node); 
recommend trả list rỗng để FE dùng rule-based. Người dùng không thấy lỗi 500.

**Q4. Guardrail chatbox hoạt động thế nào? Chi phí?**
A: 3 lớp. L2 bắt buộc conversation gắn lesson; L3 cosine similarity giữa embedding câu hỏi và (nội dung + đề luyện tập) — chặn trước khi gọi LLM 
nên tiết kiệm chi phí; L1 system prompt từ chối khéo. Embedding bài học cache trong `lessons.content_embedding`, mỗi chat chỉ embed câu hỏi. Điểm 
cần tự nhận: threshold hiện chưa set trong properties (default 0) nên L3 thực tế chưa hiệu quả — mình đề xuất cấu hình lại.

**Q5. JWT lưu ở đâu, sao không dùng session/cookie?**
A: FE lưu SharedPreferences key `auth_token`, gửi header `Authorization: Bearer`. Backend STATELESS (SessionCreationPolicy.STATELESS) — không lưu 
trạng thái, scale ngang dễ. Refresh token opaque random, lưu SHA-256 hash ở DB `refresh_tokens`, revocable khi logout.

**Q6. Student gọi API admin thì bị chặn ở đâu?**
A: Token vẫn hợp lệ → JwtAuthFilter set authentication bình thường → đến controller gặp `@PreAuthorize("hasAuthority('MANAGE_ACCOUNTS_ROLES')...")` 
→ authority của student không chứa permission đó → AccessDeniedException → `GlobalExceptionHandler.handleAccessDeniedException` trả 403 JSON (hoặc 
CustomAccessDeniedHandler nếu chặn ở filter chain).

**Q7. Password verify ở đâu?**
A: `AuthService.authenticateUser` gọi `authenticationManager.authenticate(...)`; DaoAuthenticationProvider (SecurityConfig dòng 38) load user bằng 
`UserDetailsServiceImpl` rồi so `BCryptPasswordEncoder.matches(raw, passwordHash)`. Sai → AuthenticationException → mình ném ApiException 401 "Invalid 
email or password." (không tiết lộ email tồn tại).

**Q8. Vì sao pathway dùng snake_case JSON mà phần khác camelCase?**
A: DTO pathway đánh dấu `@JsonProperty("pathway_id")` theo contract FE-11/agentic ban đầu. FE map bằng fromJson tương ứng. Đây là điểm không nhất 
quán cần chuẩn hoá sau.

**Q9. Time-boxing tính deadline thế nào?**
A: Deterministic: giờ/node = số lesson × 2 (node done = 0); ngày học mặc định T2–T7; năng suất/ngày = hoursPerWeek/số ngày (phân dư rải đầu tuần); 
chia block ngày liền kề theo thứ tự node; deadline node = cuối block 23:59; BEHIND nếu deadline vượt targetDate hoặc trong quá khứ. Thuần toán, test 
được, không tốn tiền AI.

**Q10. Reroute "agentic" khác reroute thường thế nào?**
A: Reroute thường (PUT /reroute): rule đơn giản theo điểm gần nhất (<60 → reset lộ trình về node 1). Agentic (Feature A): snapshot tiến độ + 
failStreak → policy DECIDE (DETOUR nếu trượt quiz ≥2 lần liên tiếp; FAST_TRACK nếu node trước 100 điểm và node kế không trùng skill yếu) → gợi ý 
`pending_reroute_suggestion` → user ACCEPT mới mutate (fast-track skip / detour insert) + ghi audit pathway_events. Có decline.

**Q11. Spaced repetition hoạt động ra sao?**
A: Node có mastery_score; thi đạt ≥80 → isMastered + nextReviewDate = now + interval; interval tăng 1→3→7→14→30 ngày mỗi lần đạt tiếp. Dưới 80 
→ chưa mastered, nhắc học lại. Persist qua dirty checking trong @Transactional.

**Q12. Nếu 2 tab cùng bấm generate pathway?**
A: `userRepository.findByIdForUpdate` khoá dòng user (pessimistic lock) → request sau chờ; vào thì archiveActivePathway chuyển pathway cũ 
ARCHIVED nên luôn chỉ 1 ACTIVE; @OneToOne với exam_attempt được giải phóng bằng set null trước khi tái dùng.

**Q13. Điểm thi do ai chấm? Client có gian lận được không?**
A: FE gửi raw đáp án (score=0 placeholder); `ExamService.saveExamAttempt` đối chiếu `options[selected].isCorrect` trong DB và tự tính score = 
10×correct/total. Client không được phép tự khai điểm.

**Q14. AI mentor pathway và AI assistant lesson khác nhau thế nào?**
A: Assistant = gia sư môn học, scope 1 lesson, guardrail embedding, được giải ngữ pháp/từ vựng. Mentor = hướng dẫn viên lộ trình, scope pathway 
(tiến độ/lịch/động lực), out-of-scope check bằng keyword, CẤM giải học thuật — chủ động đẩy user về Assistant trong Lesson. Hai bảng hội thoại 
riêng (ai_conversations vs pathway_conversations).

**Q15. Nếu Gemini API hết quota (429)?**
A: WebClient retry backoff 2 lần chỉ cho 429; vẫn fail thì rơi vào các nhánh fallback ở Q3/Q4; mọi lần gọi đều ghi `ai_usage_logs` 
(success/duration/error) để giám sát. Admin còn xem được health qua `/ai-assistant/status` (cache `geminiStatus`) và đổi model/key runtime 
qua `SystemConfigService` (config AI trong DB override properties).

**Q16. Điểm yếu lớn nhất của phần AI này?**
A (trả lời thẳng, kèm giải pháp): (1) recommend-courses chưa check ownership → cần thêm so sánh attempt.student.id; (2) threshold guardrail 
chưa cấu hình; (3) detour dùng course placeholder; (4) phụ thuộc Gemini single-provider — cần cache/queue khi scale. Việc mình liệt kê được 
chứng tỏ đã review kỹ.

---

*Tài liệu tạo bởi quá trình audit repo thực tế — phục vụ ôn bảo vệ. Số dòng tham chiếu commit hiện tại của nhánh làm việc.*
