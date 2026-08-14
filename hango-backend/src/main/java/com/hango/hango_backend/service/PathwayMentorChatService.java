package com.hango.hango_backend.service;

import com.hango.hango_backend.dto.*;
import com.hango.hango_backend.entity.*;
import com.hango.hango_backend.exception.ApiException;
import com.hango.hango_backend.repository.*;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.ArrayList;
import java.util.List;
import java.util.stream.Collectors;

/**
 * Pathway Mentor Chat Service — enables free-form AI conversation
 * within the context of a learner's learning pathway.
 *
 * Unlike AIAssistantService (lesson-scoped), this service is pathway-scoped:
 * the AI knows about the learner's roadmap, progress, weak skills, and schedule.
 */
@Service
@RequiredArgsConstructor
@Slf4j
public class PathwayMentorChatService {

    private final PathwayConversationRepository conversationRepository;
    private final LearningPathwayRepository pathwayRepository;
    private final UserRepository userRepository;
    private final GeminiClientService geminiClientService;
    private final ExamResultAnalyzerService examResultAnalyzerService;
    private final ExamAttemptRepository examAttemptRepository;
    private final LessonRepository lessonRepository;
    private final LessonProgressRepository lessonProgressRepository;
    private final CourseRepository courseRepository;
    private final PathwayProgressSnapshotService progressSnapshotService;
    private final PathwayReroutePolicyService reroutePolicyService;
    private final PathwayMutationService mutationService;

    private static final int MAX_HISTORY_MESSAGES = 10;

    @Transactional
    public PathwayChatResponseDTO chat(Long pathwayId, Long learnerId, PathwayChatRequestDTO request) {
        if (learnerId == null) {
            throw new ApiException("User not authenticated", HttpStatus.UNAUTHORIZED);
        }

        LearningPathway pathway = pathwayRepository.findById(pathwayId)
                .orElseThrow(() -> new ApiException("Pathway not found", HttpStatus.NOT_FOUND));

        if (!pathway.getStudent().getId().equals(learnerId)) {
            throw new ApiException("Access denied", HttpStatus.FORBIDDEN);
        }

        User learner = userRepository.findById(learnerId)
                .orElseThrow(() -> new ApiException("User not found", HttpStatus.NOT_FOUND));

        // Get or create conversation
        PathwayConversation conversation = getOrCreateConversation(request.getConversationId(), learnerId, pathway, learner);

        // Build pathway-aware system prompt
        String systemPrompt;
        try {
            systemPrompt = buildPathwaySystemPrompt(pathway, learnerId, request.getSelectedNodeCourseId());
        } catch (Exception e) {
            log.warn("Failed to build full system prompt, using minimal: {}", e.getMessage());
            systemPrompt = "Bạn là AI Mentor của HanGo — hỗ trợ người học về lộ trình học tiếng Anh. Trả lời ngắn gọn, thân thiện.";
        }

        // Build chat history from existing messages (limited to last N)
        List<GeminiGenerateRequest.Content> geminiHistory = buildGeminiHistory(conversation, request.getMessage());

        // Save user message
        PathwayMessage userMessage = PathwayMessage.builder()
                .conversation(conversation)
                .role(PathwayMessage.MessageRole.USER)
                .content(request.getMessage())
                .wasOutOfScope(false)
                .build();

        // Define tools
        List<GeminiGenerateRequest.Tool> tools = List.of(
            GeminiGenerateRequest.Tool.builder()
                .functionDeclarations(List.of(
                    GeminiGenerateRequest.FunctionDeclaration.builder()
                        .name("triggerReroute")
                        .description("Evaluates and triggers a reroute (adjustment) of the learner's pathway. Call this if the learner requests to change the pathway (e.g. they say it's too hard, too easy, or ask for a reassessment).")
                        .parameters(GeminiGenerateRequest.Schema.builder()
                            .type("OBJECT")
                            .properties(java.util.Collections.emptyMap())
                            .build())
                        .build()
                ))
                .build()
        );

        // Call Gemini
        String replyText = "";
        boolean outOfScope = isClearlyOutOfScope(request.getMessage());
        if (outOfScope) {
            replyText = buildOutOfScopeFallback(pathway);
        } else {
            try {
                GeminiGenerateResponse response = geminiClientService.generateChatResponseWithTools(systemPrompt, geminiHistory, tools);
                GeminiGenerateResponse.FunctionCall responseFunctionCall = response.extractFunctionCall();
                
                if (responseFunctionCall != null && "triggerReroute".equals(responseFunctionCall.getName())) {
                    // Map FunctionCall type
                    GeminiGenerateRequest.FunctionCall reqFunctionCall = GeminiGenerateRequest.FunctionCall.builder()
                            .name(responseFunctionCall.getName())
                            .args(responseFunctionCall.getArgs())
                            .build();

                    // AI decided to trigger a reroute
                    ProgressSnapshotDTO snapshot = progressSnapshotService.getProgressSnapshot(pathwayId, learnerId);
                    PathwayReroutePolicyService.PolicyDecision decision = reroutePolicyService.evaluate(snapshot); 
                    
                    String functionResultText;
                    if (decision.action == PathwayReroutePolicyService.PolicyAction.FAST_TRACK_ELIGIBLE) {
                        mutationService.applyFastTrackSkip(pathway, decision.targetNode.getNodeId(), decision.reason);
                        functionResultText = "Reroute applied: Fast Track (Skipped a course). Reason: " + decision.reason;
                    } else if (decision.action == PathwayReroutePolicyService.PolicyAction.DETOUR_REQUIRED) {
                        mutationService.applyDetourInsertion(pathway, decision.targetNode.getNodeId(), pathway.getNodes().get(0).getCourse(), decision.reason);
                        functionResultText = "Reroute applied: Detour (Added a remedial course). Reason: " + decision.reason;
                    } else {
                        functionResultText = "No reroute applied: The current progress does not meet the strict rules for a detour or skip. Tell the user to keep studying their current lesson.";
                    }

                    // Append function call and response to history
                    geminiHistory.add(GeminiGenerateRequest.Content.builder()
                            .role("model")
                            .parts(List.of(GeminiGenerateRequest.Part.builder().functionCall(reqFunctionCall).build()))
                            .build());
                    
                    geminiHistory.add(GeminiGenerateRequest.Content.builder()
                            .role("function") // FIXED: Gemini API requires role="function" for functionResponse
                            .parts(List.of(GeminiGenerateRequest.Part.builder()
                                    .functionResponse(GeminiGenerateRequest.FunctionResponse.builder()
                                            .name("triggerReroute")
                                            .response(java.util.Map.of("result", functionResultText))
                                            .build())
                                    .build()))
                            .build());
                    
                    // Call again
                    GeminiGenerateResponse finalResponse = geminiClientService.generateChatResponseWithTools(systemPrompt, geminiHistory, tools);
                    replyText = finalResponse.extractText();
                    if (replyText == null) replyText = "Tôi đã điều chỉnh lại lộ trình cho bạn.";
                } else {
                    replyText = response.extractText();
                    if (replyText == null) replyText = "Xin lỗi, tôi không hiểu ý bạn.";
                }
            } catch (Exception e) {
                log.warn("Pathway mentor chat failed, returning fallback: {}", e.getMessage());
                replyText = "Xin lỗi, tôi đang gặp sự cố kỹ thuật. Vui lòng thử lại sau giây lát.";
            }
        }

        // Simple out-of-scope detection from AI response
        if (replyText != null && (replyText.toLowerCase().contains("ngoài phạm vi") || replyText.toLowerCase().contains("out of scope"))) {
            outOfScope = true;
        }
        userMessage.setWasOutOfScope(outOfScope);

        // Save assistant message
        PathwayMessage assistantMessage = PathwayMessage.builder()
                .conversation(conversation)
                .role(PathwayMessage.MessageRole.ASSISTANT)
                .content(replyText)
                .wasOutOfScope(false)
                .build();

        conversation.getMessages().add(userMessage);
        conversation.getMessages().add(assistantMessage);
        conversationRepository.save(conversation);

        // Generate suggested follow-up questions
        List<String> suggestedQuestions = outOfScope ? List.of() : generateSuggestedQuestions(replyText, pathway);

        return PathwayChatResponseDTO.builder()
                .conversationId(conversation.getId())
                .role("ASSISTANT")
                .reply(replyText)
                .wasOutOfScope(outOfScope)
                .suggestedQuestions(suggestedQuestions)
                .build();
    }

    private boolean isClearlyOutOfScope(String message) {
        if (message == null || message.isBlank()) {
            return false;
        }

        String text = message.toLowerCase();
        boolean hasLearningSignal = containsAny(text,
                "hoc", "bai", "thi", "exam", "quiz", "course", "lesson", "grammar", "reading",
                "vocabulary", "listening", "english", "tieng anh", "lo trinh", "pathway",
                "study", "learn", "schedule", "on thi");
        if (hasLearningSignal) {
            return false;
        }

        return containsAny(text,
                "bitcoin", "crypto", "stock", "chung khoan", "weather", "thoi tiet",
                "nau an", "recipe", "football", "bong da", "movie", "game", "dating",
                "medical diagnosis", "legal advice", "tax advice");
    }

    private boolean containsAny(String text, String... needles) {
        for (String needle : needles) {
            if (text.contains(needle)) {
                return true;
            }
        }
        return false;
    }

    private String buildOutOfScopeFallback(LearningPathway pathway) {
        String currentCourse = "lo trinh hoc tieng Anh";
        if (pathway.getNodes() != null) {
            for (PathwayNode node : pathway.getNodes()) {
                if ("IN_PROGRESS".equalsIgnoreCase(node.getStatus()) && node.getCourse() != null) {
                    currentCourse = node.getCourse().getTitle();
                    break;
                }
            }
        }

        return "Minh chi ho tro cac cau hoi lien quan den lo trinh hoc, on thi THPT va tieng Anh trong HanGo. "
                + "Voi lo trinh hien tai, ban co the hoi ve buoc dang hoc: " + currentCourse
                + ", hoac hoi cach dieu chinh lich hoc cho phu hop hon.";
    }

    @Transactional(readOnly = true)
    public List<PathwayChatResponseDTO> getChatHistory(Long pathwayId, Long learnerId) {
        LearningPathway pathway = pathwayRepository.findById(pathwayId)
                .orElseThrow(() -> new ApiException("Pathway not found", HttpStatus.NOT_FOUND));

        if (!pathway.getStudent().getId().equals(learnerId)) {
            throw new ApiException("Access denied", HttpStatus.FORBIDDEN);
        }

        List<PathwayConversation> conversations = conversationRepository
                .findByLearnerIdAndPathwayIdOrderByStartedAtDesc(learnerId, pathwayId);

        List<PathwayChatResponseDTO> history = new ArrayList<>();
        for (PathwayConversation conv : conversations) {
            for (PathwayMessage msg : conv.getMessages()) {
                history.add(PathwayChatResponseDTO.builder()
                        .conversationId(conv.getId())
                        .role(msg.getRole().name())
                        .reply(msg.getContent())
                        .wasOutOfScope(Boolean.TRUE.equals(msg.getWasOutOfScope()))
                        .build());
            }
        }
        return history;
    }

    @Transactional
    public void clearChatHistory(Long pathwayId, Long learnerId) {
        LearningPathway pathway = pathwayRepository.findById(pathwayId)
                .orElseThrow(() -> new ApiException("Pathway not found", HttpStatus.NOT_FOUND));

        if (!pathway.getStudent().getId().equals(learnerId)) {
            throw new ApiException("Access denied", HttpStatus.FORBIDDEN);
        }

        List<PathwayConversation> conversations = conversationRepository
                .findByLearnerIdAndPathwayIdOrderByStartedAtDesc(learnerId, pathwayId);
        
        conversationRepository.deleteAll(conversations);
    }

    private PathwayConversation getOrCreateConversation(Long conversationId, Long learnerId, LearningPathway pathway, User learner) {
        if (conversationId != null && conversationId > 0) {
            return conversationRepository.findByIdAndLearnerIdWithMessages(conversationId, learnerId)
                    .orElseGet(() -> createNewConversation(learner, pathway));
        }

        // Try to find the most recent conversation for this pathway
        return conversationRepository.findFirstByLearnerIdAndPathwayIdOrderByStartedAtDesc(learnerId, pathway.getId())
                .orElseGet(() -> createNewConversation(learner, pathway));
    }

    private PathwayConversation createNewConversation(User learner, LearningPathway pathway) {
        PathwayConversation conversation = PathwayConversation.builder()
                .learner(learner)
                .pathway(pathway)
                .messages(new ArrayList<>())
                .build();
        return conversationRepository.save(conversation);
    }

    private String buildPathwaySystemPrompt(LearningPathway pathway, Long learnerId, Long selectedNodeCourseId) {
        StringBuilder sb = new StringBuilder();

        sb.append("""
                Bạn là AI Mentor của HanGo — nền tảng luyện thi THPT Quốc gia môn Tiếng Anh.
                Vai trò của bạn là một mentor cá nhân, đồng hành cùng người học trên lộ trình học tập AI đã tạo ra.

                NHIỆM VỤ CỐT LÕI:
                1. Đóng vai trò là một NGƯỜI ĐỊNH HƯỚNG LỘ TRÌNH (Pathway Guide). Trả lời các câu hỏi về: lộ trình học, tiến độ, thời gian biểu, lý do tại sao học khóa này, và động lực học tập.
                2. Khuyến khích, động viên người học khi họ gặp khó khăn hoặc chậm tiến độ.
                3. Giải thích TẠI SAO lộ trình được sắp xếp theo thứ tự này và gợi ý bước tiếp theo.
                4. TUYỆT ĐỐI KHÔNG giải đáp các câu hỏi học thuật cụ thể (ví dụ: giải bài tập ngữ pháp, giải thích từ vựng, chữa đề thi).
                5. Khi người học hỏi kiến thức học thuật cụ thể, hãy từ chối khéo léo và hướng dẫn họ vào bên trong từng bài học (Lesson) để hỏi "AI Assistant của khóa học" (trợ lý chuyên môn).

                PHONG CÁCH:
                - Thân thiện, gần gũi, như một anh/chị gia sư hướng nghiệp/mentor
                - Trả lời bằng tiếng Việt hoặc tiếng Anh tùy ngôn ngữ người học dùng
                - Ngắn gọn, tập trung, không lan man
                - Dùng emoji phù hợp (😊, 💪, 📅, 🚀) để tạo động lực
                """);

        // Pathway context
        sb.append("\n=== LỘ TRÌNH HIỆN TẠI ===\n");
        if (pathway.getGoalName() != null) {
            sb.append("Mục tiêu: ").append(pathway.getGoalName()).append("\n");
        }
        if (pathway.getTargetDate() != null) {
            sb.append("Hạn chót: ").append(pathway.getTargetDate()).append("\n");
        }
        if (pathway.getHoursPerWeek() != null) {
            sb.append("Thời gian học mỗi tuần: ").append(pathway.getHoursPerWeek()).append(" giờ\n");
        }
        if (pathway.getScheduleStatus() != null) {
            sb.append("Trạng thái lịch trình: ").append(pathway.getScheduleStatus()).append("\n");
        }

        // Nodes context
        sb.append("\nCác bước trong lộ trình:\n");
        if (pathway.getNodes() != null) {
            for (PathwayNode node : pathway.getNodes()) {
                try {
                    int progress = calculateProgress(learnerId, node.getCourse().getId());
                    sb.append(String.format("  Bước %d: [%s] %s — Tiến độ: %d%% — Lý do: %s\n",
                            node.getStepOrder(),
                            node.getStatus(),
                            node.getCourse().getTitle(),
                            progress,
                            node.getReasonWhy() != null ? node.getReasonWhy() : "N/A"));
                } catch (Exception e) {
                    sb.append(String.format("  Bước %d: [%s] (course data unavailable)\n",
                            node.getStepOrder(), node.getStatus()));
                    log.debug("Could not load course data for node {}: {}", node.getId(), e.getMessage());
                }
            }
        }

        // Weak skills context
        try {
            List<ExamAttempt> recentAttempts = examAttemptRepository.findTop10ByStudent_IdOrderBySubmittedAtDesc(learnerId);
            ExamResultAnalysisDTO analysis = examResultAnalyzerService.analyzeLearnerAttempts(learnerId, recentAttempts);
            if (analysis != null && analysis.getKnowledgeGapsJson() != null) {
                sb.append("\nPhân tích điểm yếu từ bài thi gần nhất:\n");
                sb.append(analysis.getKnowledgeGapsJson()).append("\n");
            }
        } catch (Exception e) {
            log.debug("Could not load weakness analysis for prompt: {}", e.getMessage());
        }

        // Selected node context
        if (selectedNodeCourseId != null) {
            courseRepository.findById(selectedNodeCourseId).ifPresent(course -> {
                sb.append("\n=== KHÓA HỌC ĐANG ĐƯỢC CHỌN ===\n");
                sb.append("Tên: ").append(course.getTitle()).append("\n");
                sb.append("Mô tả: ").append(course.getDescription() != null ? course.getDescription() : "N/A").append("\n");
                try {
                    if (course.getCategory() != null) {
                        sb.append("Kỹ năng: ").append(course.getCategory().getParamValue()).append("\n");
                    }
                } catch (Exception e) {
                    log.debug("Could not load category for course {}: {}", course.getId(), e.getMessage());
                }
            });
        }

        sb.append("=== HẾT CONTEXT ===\n");
        return sb.toString();
    }

    private List<GeminiGenerateRequest.Content> buildGeminiHistory(PathwayConversation conversation, String currentMessage) {
        List<GeminiGenerateRequest.Content> history = new ArrayList<>();

        // Add existing messages (limited to last N to avoid token overflow)
        if (conversation.getMessages() != null) {
            List<PathwayMessage> recentMessages = conversation.getMessages();
            int startIdx = Math.max(0, recentMessages.size() - MAX_HISTORY_MESSAGES);

            for (int i = startIdx; i < recentMessages.size(); i++) {
                PathwayMessage msg = recentMessages.get(i);
                if (Boolean.TRUE.equals(msg.getWasOutOfScope())) continue;

                String role = (msg.getRole() == PathwayMessage.MessageRole.USER) ? "user" : "model";
                history.add(GeminiGenerateRequest.Content.builder()
                        .role(role)
                        .parts(List.of(GeminiGenerateRequest.Part.builder().text(msg.getContent()).build()))
                        .build());
            }
        }

        // Add current user message
        history.add(GeminiGenerateRequest.Content.builder()
                .role("user")
                .parts(List.of(GeminiGenerateRequest.Part.builder().text(currentMessage).build()))
                .build());

        return history;
    }

    private int calculateProgress(Long learnerId, Long courseId) {
        try {
            long totalLessons = lessonRepository.countByCourseId(courseId);
            if (totalLessons == 0) return 0;
            long completed = lessonProgressRepository.countCompletedLessonsByUserIdAndCourseId(learnerId, courseId);
            return (int) Math.min(100, Math.round((double) completed / totalLessons * 100));
        } catch (Exception e) {
            return 0;
        }
    }

    private List<String> generateSuggestedQuestions(String aiReply, LearningPathway pathway) {
        List<String> suggestions = new ArrayList<>();
        try {
            // Find current in-progress node for context
            String currentCourse = "lộ trình";
            if (pathway.getNodes() != null) {
                for (PathwayNode node : pathway.getNodes()) {
                    if ("IN_PROGRESS".equalsIgnoreCase(node.getStatus())) {
                        currentCourse = node.getCourse().getTitle();
                        break;
                    }
                }
            }

            String prompt = """
                    Dựa trên câu trả lời sau của AI Mentor, hãy gợi ý 3 câu hỏi tiếp theo cho người học.
                    Khóa học đang học: %s
                    Câu trả lời vừa đưa: %s
                    
                    RẤT QUAN TRỌNG: AI Mentor là "Người định hướng lộ trình", KHÔNG PHẢI giáo viên bộ môn.
                    - CÁC CÂU HỎI GỢI Ý PHẢI NÓI VỀ: Tiến độ, lộ trình, thời gian biểu, chiến lược học tập, hoặc động lực học.
                    - TUYỆT ĐỐI KHÔNG GỢI Ý CÁC CÂU HỎI VỀ LÝ THUYẾT (ví dụ: ngữ pháp, từ vựng, giải bài tập).

                    YÊU CẦU: Trả về JSON thuần: {"suggestedQuestions":["...","...","..."]}
                    """.formatted(currentCourse, aiReply.length() > 500 ? aiReply.substring(0, 500) : aiReply);

            List<GeminiGenerateRequest.Content> history = List.of(
                    GeminiGenerateRequest.Content.builder()
                            .role("user")
                            .parts(List.of(GeminiGenerateRequest.Part.builder().text(prompt).build()))
                            .build());

            String raw = geminiClientService.generateChatResponse(
                    "Bạn là trợ lý tạo câu hỏi gợi ý. Chỉ trả JSON.", history);

            // Parse JSON
            int startArr = raw.indexOf("[");
            int endArr = raw.lastIndexOf("]");
            if (startArr != -1 && endArr > startArr) {
                String arr = raw.substring(startArr + 1, endArr);
                java.util.regex.Matcher m = java.util.regex.Pattern.compile("\"(.*?)\"").matcher(arr);
                while (m.find() && suggestions.size() < 3) {
                    String q = m.group(1).trim();
                    if (!q.isEmpty()) suggestions.add(q);
                }
            }
        } catch (Exception e) {
            log.debug("Could not generate suggested questions: {}", e.getMessage());
        }

        return suggestions;
    }
}
