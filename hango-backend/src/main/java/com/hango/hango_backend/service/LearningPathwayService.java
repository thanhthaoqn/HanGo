package com.hango.hango_backend.service;

import java.time.LocalDate;
import java.util.ArrayList;
import java.util.Collections;
import java.util.List;
import java.util.Map;
import java.util.HashMap;
import java.util.LinkedHashMap;
import java.util.Arrays;
import java.util.stream.Collectors;
import java.util.Optional;
import java.util.concurrent.atomic.AtomicInteger;

import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.hango.hango_backend.dto.ExamResultAnalysisDTO;
import com.hango.hango_backend.dto.GeminiGenerateRequest;
import com.hango.hango_backend.dto.LearningPathwayResponseDTO;
import com.hango.hango_backend.dto.MasteryQuestionDTO;
import com.hango.hango_backend.dto.MentorActionRequestDTO;
import com.hango.hango_backend.dto.PathwayGenerateRequestDTO;
import com.hango.hango_backend.dto.PathwayNodeDTO;
import com.hango.hango_backend.dto.PathwayScheduleRequestDTO;
import com.hango.hango_backend.entity.Course;
import com.hango.hango_backend.entity.ExamAttempt;
import com.hango.hango_backend.entity.LearningPathway;
import com.hango.hango_backend.entity.Lesson;
import com.hango.hango_backend.entity.PathwayNode;
import com.hango.hango_backend.entity.User;
import com.hango.hango_backend.exception.ApiException;
import com.hango.hango_backend.repository.CourseRepository;
import com.hango.hango_backend.repository.ExamAttemptRepository;
import com.hango.hango_backend.repository.LearningPathwayRepository;
import com.hango.hango_backend.repository.LessonProgressRepository;
import com.hango.hango_backend.repository.LessonRepository;
import com.hango.hango_backend.repository.UserRepository;
import com.hango.hango_backend.service.SkillCategoryMappingService;

import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;

@Service
@Slf4j
@RequiredArgsConstructor
public class LearningPathwayService {

    private static final String LESSON_TYPE_FINAL_QUIZ = "FINAL_QUIZ";
    private static final String ATTEMPT_STATE_MASTERY = "MASTERY";
    private static final int MASTERY_PASS_SCORE = 80;

    private final LearningPathwayRepository learningPathwayRepository;
    private final ExamAttemptRepository examAttemptRepository;
    private final CourseRepository courseRepository;
    private final UserRepository userRepository;
    private final GeminiClientService geminiClientService;
    private final ObjectMapper objectMapper;
    private final ExamResultAnalyzerService examResultAnalyzerService;
    private final LessonProgressRepository lessonProgressRepository;
    private final LessonRepository lessonRepository;
    private final SkillCategoryMappingService skillCategoryMappingService;
    private final com.hango.hango_backend.repository.LessonQuizAttemptRepository quizAttemptRepository;
    private final org.springframework.jdbc.core.JdbcTemplate jdbcTemplate;

    @Transactional
    public LearningPathwayResponseDTO generatePathway(Long studentId, PathwayGenerateRequestDTO requestDTO) {
        Long examAttemptId = requestDTO.getExamAttemptId();
        // Khoa optimistic (findByIdForUpdate) tranh 2 request generate pathway song
        // song
        User student = userRepository.findByIdForUpdate(studentId)
                .orElseThrow(() -> new ApiException("User not found", HttpStatus.NOT_FOUND));

        ExamAttempt examAttempt = examAttemptRepository.findById(examAttemptId)
                .orElseThrow(() -> new ApiException("Exam Attempt not found", HttpStatus.NOT_FOUND));

        // Ownership check: attempt phai thuoc ve chinh student dang login
        if (!examAttempt.getStudent().getId().equals(studentId)) {
            throw new ApiException("Access denied to this exam attempt", HttpStatus.FORBIDDEN);
        }

        List<Course> allCourses = courseRepository.findAll().stream()
                .filter(course -> course.getDeletedAt() == null)
                .toList();
        List<Course> publishedCourses = allCourses.stream()
                .filter(course -> "PUBLISHED".equalsIgnoreCase(course.getStatus()))
                .toList();
        boolean usingExistingCoursesFallback = publishedCourses.isEmpty();
        List<Course> availableCourses = usingExistingCoursesFallback ? allCourses : publishedCourses;

        if (Boolean.TRUE.equals(requestDTO.getOnlyFree())) {
            availableCourses = availableCourses.stream()
                    .filter(course -> course.getPrice() == null
                            || course.getPrice().compareTo(java.math.BigDecimal.ZERO) == 0)
                    .toList();
        }

        if (availableCourses.isEmpty()) {
            return createEmptyPathway(student, examAttempt,
                    "No courses are available yet, so I cannot build a learning pathway. Please try again after a trainer creates a course.");
        }

        StringBuilder courseListBuilder = new StringBuilder();
        for (Course course : availableCourses) {
            courseListBuilder.append(String.format("- ID: %d, Name: %s, Category: %s, Difficulty: %s, Summary: %s%n",
                    course.getId(),
                    course.getTitle(),
                    course.getCategory() != null ? course.getCategory().getParamValue() : "N/A",
                    course.getDifficulty() != null ? course.getDifficulty().getParamValue() : "N/A",
                    course.getDescription()));
        }

        // Rut ra 10 bai thi gan nhat de PHAN TICH KEP: loi vua mac (latest) + loi kinh
        // nien (historical)
        List<ExamAttempt> recentAttempts = examAttemptRepository.findTop10ByStudent_IdOrderBySubmittedAtDesc(studentId);
        ExamResultAnalysisDTO examAnalysis = examResultAnalyzerService.analyzeLearnerAttempts(studentId,
                recentAttempts);
        if (examAnalysis == null) {
            // Fallback Ä‘á»ƒ trÃ¡nh phÃ¡ flow (Ä‘áº·c biá»‡t trong unit tests khi mock chÆ°a set
            // returns).
            examAnalysis = examResultAnalyzerService.analyzeLatestExamAttempt(examAttempt);
        }

        // Phan tich kep: boc tach "loi kinh nien" (weakCategories) va "loi moi mac"
        // (latestWeakCategories)
        List<String> weakCategories = extractWeakCategories(examAnalysis.getKnowledgeGapsJson());
        List<String> latestWeakCategories = extractLatestWeakCategories(examAnalysis.getKnowledgeGapsJson());

        String categoryHint = "";
        if (!latestWeakCategories.isEmpty()) {
            categoryHint += "\nHINT (LATEST EXAM): The learner JUST failed these categories in their most recent exam: "
                    + latestWeakCategories + ". These should be addressed FIRST in the pathway.";
        }
        if (!weakCategories.isEmpty()) {
            categoryHint += "\nHINT (HISTORICAL): The learner has a chronic weakness in these categories across past exams: "
                    + weakCategories + ". These should be reinforced AFTER addressing the latest failures.";
        }

        String goalText = (requestDTO.getGoalName() != null && !requestDTO.getGoalName().isBlank())
                ? "Má»¤C TIÃŠU Cá»¦A NGÆ¯á»œI Há»ŒC: " + requestDTO.getGoalName() + "\n"
                : "";

        String systemPrompt = """

                .
                Báº¡n lÃ  Trá»£ lÃ½ láº­p lá»™ trÃ¬nh há»c táº­p.
                Nhiá»‡m vá»¥: dá»±a trÃªn JSON bÃ i thi má»›i nháº¥t cá»§a learner (answersJson) vÃ  pháº§n phÃ¢n tÃ­ch do tool cung cáº¥p Ä‘á»ƒ Ä‘á» xuáº¥t lá»™ trÃ¬nh cÃ¡ nhÃ¢n hÃ³a.

                %s
                Core rules:
                1. Only choose course_id values from [AVAILABLE_COURSES]. Never invent a course.
                2. Prioritize foundations first, then harder reading or advanced skills.
                3. Æ¯U TIÃŠN chá»n cÃ¡c khÃ³a há»c kháº¯c phá»¥c trá»±c tiáº¿p cÃ¡c "weak_skills" trong pháº§n phÃ¢n tÃ­ch vÃ  hÆ°á»›ng tá»›i Má»¤C TIÃŠU Cá»¦A NGÆ¯á»œI Há»ŒC. ÄÆ°a ra "reason_why" giáº£i thÃ­ch rÃµ táº¡i sao khÃ³a há»c nÃ y láº¡i giÃºp cáº£i thiá»‡n Ä‘iá»ƒm yáº¿u hoáº·c giÃºp Ä‘áº¡t má»¥c tiÃªu Ä‘Ã³. "reason_why" pháº£i giáº£i thÃ­ch cá»¥ thá»ƒ "KhÃ³a nÃ y giáº£i quyáº¿t lá»—i vá»«a máº¯c" hay "KhÃ³a nÃ y cá»§ng cá»‘ Ä‘iá»ƒm yáº¿u kinh niÃªn".
                4. "mentor_summary" PHáº¢I LÃ€ Lá»œI CHÃ€O VÃ€ TÃ“M Táº®T THÃ”NG MINH, Máº¶C Äá»ŠNH Sá»¬ Dá»¤NG TIáº¾NG VIá»†T (cÃ³ thá»ƒ dÃ¹ng tiáº¿ng Anh náº¿u ngÆ°á»i dÃ¹ng há»i báº±ng tiáº¿ng Anh). Báº¡n PHáº¢I so sÃ¡nh Ä‘iá»ƒm sá»‘ bÃ i thi gáº§n nháº¥t (latest_score) vá»›i Ä‘iá»ƒm trung bÃ¬nh lá»‹ch sá»­ (láº¥y tá»« "score_avg" trong knowledge_gaps_json). VÃ­ dá»¥: "Dá»±a trÃªn lá»‹ch sá»­ lÃ m bÃ i, Ä‘iá»ƒm trung bÃ¬nh cá»§a báº¡n Ä‘ang lÃ  [score_avg]/10. Tuy nhiÃªn, trong bÃ i thi vá»«a rá»“i (Ä‘Æ°á»£c [latest_score]/10 Ä‘iá»ƒm), báº¡n Ä‘ang gáº·p khÃ³ khÄƒn á»Ÿ pháº§n [X]. Äá»“ng thá»i, [Y] váº«n lÃ  Ä‘iá»ƒm yáº¿u kinh niÃªn cáº§n kháº¯c phá»¥c...". TUYá»†T Äá»I KHÃ”NG trá»™n láº«n ngÃ´n ngá»¯ (ná»­a Anh ná»­a Viá»‡t) trong má»™t cÃ¢u.
                5. Return valid JSON only, without markdown fences.
                6. PATHWAY PRIORITY ORDER:
                   - First courses should address the learner's LATEST exam weaknesses (most recent failures). Include EXACT tag "#New Vulnerability".
                   - Subsequent courses should reinforce HISTORICAL chronic weaknesses (patterns across exams). Include EXACT tag "#Chronic Weakness".
                   - Add topical tags like "#Grammar" as well. Max 2 tags total.

                [AVAILABLE_COURSES]
                %s

                TOOL INPUT (EXAM ANALYSIS):
                - examAttemptId: %s
                - latest_score: %s
                - knowledge_gaps_json: %s%s

                JSON format:
                {
                  "roadmap_id": "AUTO_GEN",
                  "mentor_summary": "Dá»±a trÃªn lá»‹ch sá»­ lÃ m bÃ i, Ä‘iá»ƒm trung bÃ¬nh cá»§a báº¡n Ä‘ang lÃ  7.6/10. Tuy nhiÃªn, trong bÃ i thi vá»«a rá»“i (Ä‘Æ°á»£c 5.6/10 Ä‘iá»ƒm), báº¡n Ä‘ang gáº·p khÃ³ khÄƒn á»Ÿ pháº§n Reading Comprehension. Äá»“ng thá»i, Grammar váº«n lÃ  Ä‘iá»ƒm yáº¿u kinh niÃªn...",
                  "nodes": [
                    { "step": 1, "course_id": 1, "reason_why": "KhÃ³a há»c nÃ y giáº£i quyáº¿t lá»—i vá»«a máº¯c á»Ÿ pháº§n Äá»c hiá»ƒu...", "status": "IN_PROGRESS", "tags": ["#New Vulnerability", "#Reading"] },
                    { "step": 2, "course_id": 2, "reason_why": "KhÃ³a nÃ y cá»§ng cá»‘ Ä‘iá»ƒm yáº¿u kinh niÃªn vá» Ngá»¯ phÃ¡p...", "status": "LOCKED", "tags": ["#Chronic Weakness", "#Grammar"] }
                  ]
                }
                """
                .formatted(
                        goalText,
                        courseListBuilder,
                        examAnalysis.getExamAttemptId(),
                        examAnalysis.getScore(),
                        examAnalysis.getKnowledgeGapsJson() == null ? "" : examAnalysis.getKnowledgeGapsJson(),
                        categoryHint);

        String userContent = "Latest exam attempt: \n" + examAttempt.getAnswersJson();
        List<GeminiGenerateRequest.Content> chatHistory = List.of(
                GeminiGenerateRequest.Content.builder()
                        .role("user")
                        .parts(List.of(GeminiGenerateRequest.Part.builder().text(userContent).build()))
                        .build());

        // Goi Gemini sinh pathway dang JSON; neu AI loi thi dung fallback deterministic
        LearningPathwayResponseDTO responseDto;
        try {
            String aiResponseText = geminiClientService.generateChatResponse(systemPrompt, chatHistory);
            aiResponseText = aiResponseText.replaceAll("(?s)^```json\\s*", "")
                    .replaceAll("(?s)```\\s*$", "")
                    .trim();
            responseDto = objectMapper.readValue(aiResponseText, LearningPathwayResponseDTO.class);
        } catch (Exception e) {
            // Fallback: khong goi AI nua - uu tien course thuoc category yeu, gioi han 4
            // node
            log.warn("Falling back to deterministic learning pathway because AI generation failed: {}", e.getMessage());
            responseDto = buildFallbackPathwayDto(examAttempt, availableCourses, usingExistingCoursesFallback,
                    weakCategories);
        }

        // Pathway cu (ACTIVE) chuyen sang ARCHIVED de moi user chi co 1 pathway hieu
        // luc
        archiveActivePathway(studentId);

        LearningPathway newPathway = LearningPathway.builder()
                .student(student)
                .examAttempt(examAttempt)
                .mentorSummary(responseDto.getMentorSummary() != null
                        ? responseDto.getMentorSummary()
                        : "TÃ´i Ä‘Ã£ xÃ¢y dá»±ng má»™t lá»™ trÃ¬nh tá»« káº¿t quáº£ bÃ i kiá»ƒm tra cá»§a báº¡n báº±ng cÃ¡ch sá»­ dá»¥ng cÃ¡c khÃ³a há»c hiá»‡n cÃ³ trong HanGo.")
                .status("ACTIVE")
                .goalName(requestDTO.getGoalName())
                .targetDate(requestDTO.getTargetDate())
                .hoursPerWeek(requestDTO.getHoursPerWeek())
                .scheduleStatus(requestDTO.getTargetDate() != null ? "ON_TRACK" : null)
                .build();

        if (responseDto.getNodes() != null) {
            // Chi chap nhan course_id ton tai trong availableCourses - courseId AI bia ra
            // bi bo qua
            for (PathwayNodeDTO nodeDto : responseDto.getNodes()) {
                Course course = availableCourses.stream()
                        .filter(candidate -> candidate.getId().equals(nodeDto.getCourseId()))
                        .findFirst()
                        .orElse(null);

                if (course != null) {
                    PathwayNode node = PathwayNode.builder()
                            .stepOrder(nodeDto.getStep() != null ? nodeDto.getStep() : newPathway.getNodes().size() + 1)
                            .course(course)
                            .status(normalizeNodeStatus(nodeDto.getStatus(), newPathway.getNodes().isEmpty()))
                            .reasonWhy(nodeDto.getReasonWhy() != null
                                    ? nodeDto.getReasonWhy()
                                    : defaultReasonForCourse(course, examAttempt))
                            .tags(nodeDto.getTags() != null && !nodeDto.getTags().isEmpty()
                                    ? String.join(",", nodeDto.getTags())
                                    : (course.getCategory() != null ? "#" + course.getCategory().getParamValue()
                                            : null))
                            .progressPercent(0)
                            .build();
                    newPathway.addNode(node);
                }
            }
        }

        if (newPathway.getNodes().isEmpty()) {
            addFallbackNodes(newPathway, examAttempt, availableCourses);
        }

        // Time-boxing: neu user nhap targetDate + hoursPerWeek thi tinh ngay
        // start/deadline tung node
        if (requestDTO.getTargetDate() != null && requestDTO.getHoursPerWeek() != null
                && requestDTO.getHoursPerWeek() > 0) {
            applyTimeboxing(newPathway, requestDTO.getTargetDate(), requestDTO.getHoursPerWeek(),
                    requestDTO.getPreferredStudyDays());
        }

        LearningPathway savedPathway = learningPathwayRepository.save(newPathway);
        return toResponseDto(savedPathway, studentId);
    }

    @Transactional
    public LearningPathwayResponseDTO reroutePathway(Long pathwayId, Long studentId) {
        LearningPathway pathway = learningPathwayRepository.findById(pathwayId)
                .orElseThrow(() -> new ApiException("Pathway not found", HttpStatus.NOT_FOUND));

        if (!pathway.getStudent().getId().equals(studentId)) {
            throw new ApiException("Access denied", HttpStatus.FORBIDDEN);
        }

        List<ExamAttempt> recentAttempts = examAttemptRepository.findTop10ByStudent_IdOrderBySubmittedAtDesc(studentId);
        int effectiveScore = recentAttempts.stream()
                .filter(attempt -> attempt.getScore() != null)
                .findFirst()
                .map(attempt -> attempt.getScore().intValue())
                .orElse(0);

        final int finalScore = effectiveScore;
        pathway.setMentorSummary(finalScore < 60
                ? "Há»‡ thá»‘ng Ä‘Ã£ tá»± Ä‘á»™ng thay Ä‘á»•i lá»™ trÃ¬nh há»c táº­p do Ä‘iá»ƒm bÃ i kiá»ƒm tra gáº§n nháº¥t cá»§a báº¡n hÆ¡i tháº¥p. TÃ´i Ä‘ang táº­p trung Ä‘iá»u chá»‰nh láº¡i lá»™ trÃ¬nh vÃ o cÃ¡c ká»¹ nÄƒng ná»n táº£ng mÃ  báº¡n cáº§n náº¯m vá»¯ng trÆ°á»›c tiÃªn."
                : "Hiá»‡u suáº¥t bÃ i kiá»ƒm tra gáº§n Ä‘Ã¢y cá»§a báº¡n lÃ  cháº¥p nháº­n Ä‘Æ°á»£c, vÃ¬ váº­y lá»™ trÃ¬nh hiá»‡n táº¡i váº«n lÃ  lá»±a chá»n tá»‘t nháº¥t.");

        if (pathway.getNodes() != null) {
            boolean firstNodeSeen = false;
            for (PathwayNode node : pathway.getNodes()) {
                if (!firstNodeSeen && node.getStepOrder() != null && node.getStepOrder() == 1) {
                    node.setStatus("IN_PROGRESS");
                    // Reset progress only if less than current real progress
                    int realProgress = calculateCourseProgressPercent(studentId, node.getCourse().getId());
                    node.setProgressPercent(Math.max(node.getProgressPercent(), realProgress));
                    firstNodeSeen = true;
                } else if (!"COMPLETED".equalsIgnoreCase(node.getStatus())) {
                    node.setStatus("LOCKED");
                    node.setProgressPercent(0);
                }
            }
        }

        LearningPathway savedPathway = learningPathwayRepository.save(pathway);
        return toResponseDto(savedPathway, studentId);
    }

    @Transactional(readOnly = true)
    public LearningPathwayResponseDTO getPathwayById(Long pathwayId, Long studentId) {
        LearningPathway pathway = learningPathwayRepository.findById(pathwayId)
                .orElseThrow(() -> new ApiException("Pathway not found", HttpStatus.NOT_FOUND));

        if (!pathway.getStudent().getId().equals(studentId)) {
            throw new ApiException("Access denied", HttpStatus.FORBIDDEN);
        }

        return toResponseDto(pathway, studentId);
    }

    @Transactional(readOnly = true)
    public LearningPathwayResponseDTO getMyPathway(Long studentId) {
        LearningPathway pathway = learningPathwayRepository.findByStudentIdAndStatus(studentId, "ACTIVE")
                .orElseThrow(() -> new ApiException("No active learning pathway found", HttpStatus.NOT_FOUND));

        return toResponseDto(pathway, studentId);
    }

    @Transactional
    public LearningPathwayResponseDTO processMentorAction(Long pathwayId, Long studentId,
            MentorActionRequestDTO request) {
        LearningPathway pathway = learningPathwayRepository.findById(pathwayId)
                .orElseThrow(() -> new ApiException("Pathway not found", HttpStatus.NOT_FOUND));

        if (!pathway.getStudent().getId().equals(studentId)) {
            throw new ApiException("Access denied", HttpStatus.FORBIDDEN);
        }

        String actionType = request.getActionType();
        switch (actionType) {
            case "FAST_TRACK" -> {
                // Find current IN_PROGRESS node and actually skip it
                PathwayNode currentNode = findCurrentInProgressNode(pathway);
                if (currentNode != null) {
                    currentNode.setNodeType("FAST_TRACK_SKIPPED");
                    currentNode.setIsOptional(true);
                    currentNode.setSkippedAt(java.time.LocalDateTime.now());
                    currentNode.setStatus("COMPLETED");
                    currentNode.setRerouteReason("Skipped by learner via Fast Track action");

                    // Unlock next node
                    if (pathway.getNodes() != null) {
                        pathway.getNodes().stream()
                                .filter(n -> n.getStepOrder() == currentNode.getStepOrder() + 1)
                                .findFirst()
                                .ifPresent(next -> {
                                    if ("LOCKED".equalsIgnoreCase(next.getStatus())) {
                                        next.setStatus("IN_PROGRESS");
                                    }
                                });
                    }
                    pathway.setMentorSummary("âœ… ÄÃ£ bá» qua khÃ³a há»c '" + currentNode.getCourse().getTitle()
                            + "' vÃ  má»Ÿ khÃ³a bÆ°á»›c tiáº¿p theo cho báº¡n.");
                } else {
                    pathway.setMentorSummary("KhÃ´ng tÃ¬m tháº¥y khÃ³a há»c nÃ o Ä‘ang há»c Ä‘á»ƒ bá» qua.");
                }
            }
            case "ADJUST_SCHEDULE" -> {
                // Recalculate timeboxing with current data
                Integer newHours = null;
                if (request.getPayload() != null && request.getPayload().get("hoursPerWeek") != null) {
                    newHours = ((Number) request.getPayload().get("hoursPerWeek")).intValue();
                }
                if (newHours != null && newHours > 0) {
                    pathway.setHoursPerWeek(newHours);
                }
                if (pathway.getTargetDate() != null && pathway.getHoursPerWeek() != null
                        && pathway.getHoursPerWeek() > 0) {
                    applyTimeboxing(pathway, pathway.getTargetDate(), pathway.getHoursPerWeek(), null);
                    pathway.setScheduleStatus("ON_TRACK");
                    pathway.setMentorSummary("ðŸ“… Lá»‹ch trÃ¬nh Ä‘Ã£ Ä‘Æ°á»£c tÃ­nh toÃ¡n láº¡i" +
                            (newHours != null ? " vá»›i " + newHours + " giá»/tuáº§n." : ".") +
                            " HÃ£y cá»‘ gáº¯ng theo Ä‘Ãºng tiáº¿n Ä‘á»™ nhÃ©!");
                } else {
                    pathway.setScheduleStatus("AT_RISK");
                    pathway.setMentorSummary(
                            "âš ï¸ Lá»‹ch trÃ¬nh chÆ°a thá»ƒ tÃ­nh láº¡i vÃ¬ chÆ°a cÃ³ ngÃ y má»¥c tiÃªu hoáº·c sá»‘ giá»/tuáº§n. HÃ£y cáº­p nháº­t má»¥c tiÃªu cá»§a báº¡n.");
                }
            }
            case "TAKE_QUIZ" -> {
                // Generate dynamic mini-quiz based on current node's course
                PathwayNode currentNode = findCurrentInProgressNode(pathway);
                String quizContent = generateMiniQuiz(currentNode);
                pathway.setMentorSummary(quizContent);
            }
            case "WHAT_WILL_I_LEARN" -> {
                // Build personalized overview from actual pathway data
                StringBuilder overview = new StringBuilder("ðŸ“š **Tá»•ng quan lá»™ trÃ¬nh cá»§a báº¡n:**\n\n");
                if (pathway.getGoalName() != null) {
                    overview.append("ðŸŽ¯ Má»¥c tiÃªu: ").append(pathway.getGoalName()).append("\n");
                }
                int total = pathway.getNodes() != null ? pathway.getNodes().size() : 0;
                long completed = pathway.getNodes() != null
                        ? pathway.getNodes().stream().filter(n -> "COMPLETED".equalsIgnoreCase(n.getStatus())).count()
                        : 0;
                overview.append("ðŸ“Š Tiáº¿n Ä‘á»™: ").append(completed).append("/").append(total)
                        .append(" bÆ°á»›c hoÃ n thÃ nh\n\n");
                overview.append("CÃ¡c ká»¹ nÄƒng sáº½ Ä‘Æ°á»£c cáº£i thiá»‡n:\n");
                if (pathway.getNodes() != null) {
                    for (PathwayNode node : pathway.getNodes()) {
                        String status = switch (node.getStatus().toUpperCase()) {
                            case "COMPLETED" -> "âœ…";
                            case "IN_PROGRESS" -> "ðŸ”„";
                            default -> "ðŸ”’";
                        };
                        String skill = node.getCourse().getCategory() != null
                                ? node.getCourse().getCategory().getParamValue()
                                : "General";
                        overview.append(status).append(" BÆ°á»›c ").append(node.getStepOrder())
                                .append(": ").append(node.getCourse().getTitle())
                                .append(" (").append(skill).append(")\n");
                    }
                }
                pathway.setMentorSummary(overview.toString());
            }
            default -> {
                pathway.setMentorSummary("TÃ´i Ä‘Ã£ nháº­n Ä‘Æ°á»£c yÃªu cáº§u cá»§a báº¡n (" + actionType
                        + "), nhÆ°ng chÆ°a biáº¿t cÃ¡ch xá»­ lÃ½ nÃ³ lÃºc nÃ y.");
            }
        }

        LearningPathway savedPathway = learningPathwayRepository.save(pathway);
        return toResponseDto(savedPathway, studentId);
    }

    private PathwayNode findCurrentInProgressNode(LearningPathway pathway) {
        if (pathway.getNodes() == null)
            return null;
        return pathway.getNodes().stream()
                .filter(n -> "IN_PROGRESS".equalsIgnoreCase(n.getStatus()))
                .findFirst()
                .orElse(null);
    }

    private String generateMiniQuiz(PathwayNode currentNode) {
        if (currentNode == null) {
            return "ðŸ“ KhÃ´ng tÃ¬m tháº¥y khÃ³a há»c Ä‘ang há»c Ä‘á»ƒ táº¡o mini-quiz. HÃ£y báº¯t Ä‘áº§u má»™t khÃ³a há»c trÆ°á»›c.";
        }
        try {
            String courseName = currentNode.getCourse().getTitle();
            String category = currentNode.getCourse().getCategory() != null
                    ? currentNode.getCourse().getCategory().getParamValue()
                    : "General English";

            String prompt = """
                    Táº¡o 3 cÃ¢u há»i tráº¯c nghiá»‡m (má»—i cÃ¢u 4 lá»±a chá»n A/B/C/D) vá» chá»§ Ä‘á» "%s" (%s) cho há»c sinh luyá»‡n thi THPT Quá»‘c gia Tiáº¿ng Anh.
                    Format má»—i cÃ¢u:
                    **CÃ¢u X:** [cÃ¢u há»i]
                    A. [lá»±a chá»n]
                    B. [lá»±a chá»n]
                    C. [lá»±a chá»n]
                    D. [lá»±a chá»n]
                    âœ… ÄÃ¡p Ã¡n: [Ä‘Ã¡p Ã¡n Ä‘Ãºng]

                    Chá»‰ tráº£ vá» Ä‘Ãºng 3 cÃ¢u há»i, khÃ´ng thÃªm gÃ¬ khÃ¡c.
                    """
                    .formatted(courseName, category);

            List<com.hango.hango_backend.dto.GeminiGenerateRequest.Content> history = List.of(
                    com.hango.hango_backend.dto.GeminiGenerateRequest.Content.builder()
                            .role("user")
                            .parts(List.of(com.hango.hango_backend.dto.GeminiGenerateRequest.Part.builder()
                                    .text(prompt).build()))
                            .build());

            String quizText = geminiClientService.generateChatResponse(
                    "Báº¡n lÃ  giÃ¡o viÃªn Tiáº¿ng Anh THPT. Táº¡o cÃ¢u há»i tráº¯c nghiá»‡m cháº¥t lÆ°á»£ng.", history);
            return "ðŸ“ **Mini-Quiz: " + courseName + "**\n\n" + quizText;
        } catch (Exception e) {
            log.warn("Failed to generate mini-quiz: {}", e.getMessage());
            return "ðŸ“ TÃ´i Ä‘ang gáº·p sá»± cá»‘ khi táº¡o mini-quiz. Vui lÃ²ng thá»­ láº¡i sau.";
        }
    }

    @Transactional
    public LearningPathwayResponseDTO applySchedule(Long pathwayId, Long studentId,
            PathwayScheduleRequestDTO requestDTO) {
        LearningPathway pathway = learningPathwayRepository.findById(pathwayId)
                .orElseThrow(() -> new ApiException("Pathway not found", HttpStatus.NOT_FOUND));

        if (!pathway.getStudent().getId().equals(studentId)) {
            throw new ApiException("Access denied", HttpStatus.FORBIDDEN);
        }

        pathway.setGoalName(requestDTO.getGoalName());
        pathway.setTargetDate(requestDTO.getTargetDate());
        pathway.setHoursPerWeek(requestDTO.getHoursPerWeek());
        pathway.setScheduleStatus("ON_TRACK");

        applyTimeboxing(pathway, requestDTO.getTargetDate(), requestDTO.getHoursPerWeek(),
                requestDTO.getPreferredStudyDays());

        LearningPathway savedPathway = learningPathwayRepository.save(pathway);
        return toResponseDto(savedPathway, studentId);
    }

    @Transactional(readOnly = true)
    public String getScheduleStatus(Long pathwayId, Long studentId) {
        LearningPathway pathway = learningPathwayRepository.findById(pathwayId)
                .orElseThrow(() -> new ApiException("Pathway not found", HttpStatus.NOT_FOUND));

        if (!pathway.getStudent().getId().equals(studentId)) {
            throw new ApiException("Access denied", HttpStatus.FORBIDDEN);
        }

        return pathway.getScheduleStatus() != null ? pathway.getScheduleStatus() : "NONE";
    }

    private void applyTimeboxing(LearningPathway pathway, LocalDate targetDate, Integer hoursPerWeek,
            List<Integer> preferredStudyDays) {
        if (pathway.getNodes() == null || pathway.getNodes().isEmpty())
            return;

        // Uoc luong so gio moi node = so lesson * 2h (node COMPLETED khong ton nang
        // luong)
        List<Integer> estimatedHoursPerNode = new ArrayList<>();
        for (PathwayNode node : pathway.getNodes()) {
            if ("COMPLETED".equalsIgnoreCase(node.getStatus())) {
                estimatedHoursPerNode.add(0); // Completed nodes consume no forward capacity
            } else {
                long totalLessons = lessonRepository.countByCourseId(node.getCourse().getId());
                estimatedHoursPerNode.add(totalLessons == 0 ? 3 : (int) (totalLessons * 2));
            }
        }

        List<PathwayTimeboxingScheduler.NodeSchedule> schedule = PathwayTimeboxingScheduler.scheduleForward(
                LocalDate.now(),
                hoursPerWeek,
                preferredStudyDays,
                estimatedHoursPerNode,
                pathway.getNodes().size());

        for (int i = 0; i < pathway.getNodes().size(); i++) {
            PathwayNode node = pathway.getNodes().get(i);
            if ("COMPLETED".equalsIgnoreCase(node.getStatus())) {
                continue; // Do not alter the historical schedule of completed nodes
            }

            PathwayTimeboxingScheduler.NodeSchedule nodeSchedule = schedule.get(i);

            node.setStartDate(nodeSchedule.getStartDate() != null ? nodeSchedule.getStartDate().atStartOfDay() : null);
            node.setDeadline(nodeSchedule.getDeadline() != null ? nodeSchedule.getDeadline().atTime(23, 59) : null);
            node.setEstimatedHours(nodeSchedule.getEstimatedHours());

            boolean isBehind = false;
            if (nodeSchedule.getDeadline() != null) {
                // If the scheduled deadline is after the user's target date, we are behind
                if (targetDate != null && nodeSchedule.getDeadline().isAfter(targetDate)) {
                    isBehind = true;
                }
                // Or if the deadline has already passed
                if (nodeSchedule.getDeadline().isBefore(LocalDate.now())) {
                    isBehind = true;
                }
            }
            node.setScheduleStatus(isBehind ? "BEHIND" : "ON_TRACK");
        }

        // D1: aggregate trang thai pathway tu cac node - co node chua hoan thanh bi
        // BEHIND thi pathway BEHIND
        refreshScheduleStatus(pathway);
    }

    /** Tinh lai pathway.scheduleStatus tu trang thai cua tung node con lai. */
    private void refreshScheduleStatus(LearningPathway pathway) {
        if (pathway.getNodes() == null || pathway.getNodes().isEmpty())
            return;
        boolean anyBehind = pathway.getNodes().stream()
                .anyMatch(n -> !"COMPLETED".equalsIgnoreCase(n.getStatus())
                        && "BEHIND".equalsIgnoreCase(n.getScheduleStatus()));
        pathway.setScheduleStatus(anyBehind ? "BEHIND" : "ON_TRACK");
    }

    private LearningPathwayResponseDTO toResponseDto(LearningPathway pathway, Long studentId) {
        List<PathwayNodeDTO> nodeDTOs = pathway.getNodes().stream().map(node -> {
            int realProgress = calculateCourseProgressPercent(studentId, node.getCourse().getId());
            long totalLessons = lessonRepository.countByCourseId(node.getCourse().getId());
            long completedLessons = countCompletedLessons(studentId, node.getCourse().getId());
            String skillType = node.getCourse().getCategory() != null
                    ? node.getCourse().getCategory().getParamValue()
                    : null;

            // Auto-sync node status based on actual progress
            String resolvedStatus = node.getStatus();
            // Node duoc skip/detour bang tay (co nodeType) giu nguyen COMPLETED hop le
            boolean manuallyCompleted = node.getNodeType() != null && !node.getNodeType().isBlank();
            if (totalLessons > 0 && realProgress >= 100) {
                resolvedStatus = "COMPLETED";
            } else if ("COMPLETED".equalsIgnoreCase(resolvedStatus) && realProgress < 100 && !manuallyCompleted) {
                // E5: AI co the tra COMPLETED ao - ha ve IN_PROGRESS neu tien do that < 100%
                resolvedStatus = "IN_PROGRESS";
            } else if (realProgress > 0 && "LOCKED".equalsIgnoreCase(node.getStatus())) {
                resolvedStatus = "IN_PROGRESS";
            }

            return PathwayNodeDTO.builder()
                    .id(node.getId())
                    .step(node.getStepOrder())
                    .courseId(node.getCourse().getId())
                    .courseTitle(node.getCourse().getTitle())
                    .status(resolvedStatus)
                    .reasonWhy(node.getReasonWhy())
                    .progressPercent(realProgress)
                    .skillType(skillType)
                    .totalLessons(Math.toIntExact(Math.min(totalLessons, Integer.MAX_VALUE)))
                    .completedLessons(Math.toIntExact(Math.min(completedLessons, Integer.MAX_VALUE)))
                    .completedLessons(Math.toIntExact(Math.min(completedLessons, Integer.MAX_VALUE)))
                    .tags(node.getTags() != null && !node.getTags().isBlank()
                            ? Arrays.asList(node.getTags().split(","))
                            : (node.getCourse().getCategory() != null
                                    ? List.of("#" + node.getCourse().getCategory().getParamValue())
                                    : Collections.emptyList()))
                    .startDate(node.getStartDate() != null ? node.getStartDate().toString() : null)
                    .deadline(node.getDeadline() != null ? node.getDeadline().toString() : null)
                    .estimatedHours(node.getEstimatedHours())
                    .scheduleStatus(node.getScheduleStatus())
                    .masteryScore(node.getMasteryScore())
                    .isMastered(node.getIsMastered())
                    .nextReviewDate(node.getNextReviewDate() != null ? node.getNextReviewDate().toString() : null)
                    .reviewIntervalDays(node.getReviewIntervalDays())
                    .build();
        }).toList();

        int totalSteps = nodeDTOs.size();
        int completedSteps = (int) nodeDTOs.stream()
                .filter(n -> "COMPLETED".equalsIgnoreCase(n.getStatus()))
                .count();

        // Extract weak skills from recent exam attempts for Skill Analysis Panel
        List<ExamAttempt> recentAttempts = examAttemptRepository.findTop10ByStudent_IdOrderBySubmittedAtDesc(studentId);
        ExamResultAnalysisDTO analysisDTO = examResultAnalyzerService.analyzeLearnerAttempts(studentId, recentAttempts);
        List<String> weakSkills = Collections.emptyList();
        if (analysisDTO != null && analysisDTO.getKnowledgeGapsJson() != null) {
            try {
                @SuppressWarnings("unchecked")
                Map<String, Object> gaps = objectMapper.readValue(analysisDTO.getKnowledgeGapsJson(),
                        Map.class);
                Object ws = gaps.get("weak_skills");
                if (ws instanceof List<?> wsList) {
                    weakSkills = wsList.stream().map(Object::toString).toList();
                }
            } catch (Exception e) {
                log.debug("Failed to parse weak_skills from knowledge gap: {}", e.getMessage());
            }
        }

        List<String> suggestedActions = new ArrayList<>();

        // Context-aware suggested actions based on actual learner progress
        PathwayNode currentNode = null;
        if (pathway.getNodes() != null) {
            currentNode = pathway.getNodes().stream()
                    .filter(n -> "IN_PROGRESS".equalsIgnoreCase(n.getStatus()))
                    .findFirst()
                    .orElse(null);
        }

        if (currentNode != null) {
            int progress = calculateCourseProgressPercent(studentId, currentNode.getCourse().getId());
            suggestedActions.add("FAST_TRACK"); // Unconditionally allow fast-track for current node

            if (progress > 0 && progress < 50) {
                suggestedActions.add("TAKE_QUIZ");
            }
        } else if (completedSteps > 0 && completedSteps == totalSteps) {
            // Pathway is fully completed
            suggestedActions.add("TAKE_NEW_EXAM");
            pathway.setMentorSummary(
                    "ðŸŽ‰ ChÃºc má»«ng báº¡n Ä‘Ã£ hoÃ n thÃ nh xuáº¥t sáº¯c toÃ n bá»™ lá»™ trÃ¬nh hiá»‡n táº¡i! Äá»ƒ tiáº¿p tá»¥c nÃ¢ng cao trÃ¬nh Ä‘á»™, hÃ£y lÃ m má»™t bÃ i kiá»ƒm tra Ä‘Ã¡nh giÃ¡ nÄƒng lá»±c má»›i Ä‘á»ƒ tÃ´i cÃ³ thá»ƒ thiáº¿t káº¿ cho báº¡n má»™t lá»™ trÃ¬nh nÃ¢ng cáº¥p hÆ¡n nhÃ©!");
        }

        if ("BEHIND".equalsIgnoreCase(pathway.getScheduleStatus())
                || "AT_RISK".equalsIgnoreCase(pathway.getScheduleStatus())) {
            suggestedActions.add("ADJUST_SCHEDULE");
        }

        // Always offer overview
        suggestedActions.add("WHAT_WILL_I_LEARN");

        // If no contextual actions were added, add quiz as a safe default
        if (suggestedActions.size() == 1 && currentNode != null) {
            suggestedActions.add(0, "TAKE_QUIZ");
        }

        // D1: derive scheduleStatus hien hanh tu node (khong mutate entity trong tx
        // read-only)
        String derivedScheduleStatus = pathway.getScheduleStatus();
        if (pathway.getNodes() != null && !pathway.getNodes().isEmpty()) {
            boolean anyBehind = pathway.getNodes().stream()
                    .anyMatch(n -> !"COMPLETED".equalsIgnoreCase(n.getStatus())
                            && "BEHIND".equalsIgnoreCase(n.getScheduleStatus()));
            derivedScheduleStatus = anyBehind ? "BEHIND" : "ON_TRACK";
        }

        return LearningPathwayResponseDTO.builder()
                .pathwayId(pathway.getId())
                .roadmapId("RM_USER_" + studentId + "_" + pathway.getId())
                .examAttemptId(pathway.getExamAttempt() != null ? pathway.getExamAttempt().getId() : null)
                .mentorSummary(pathway.getMentorSummary())
                .nodes(nodeDTOs)
                .totalSteps(totalSteps)
                .completedSteps(completedSteps)
                .weakSkills(weakSkills)
                .goalName(pathway.getGoalName())
                .targetDate(pathway.getTargetDate() != null ? pathway.getTargetDate().toString() : null)
                .hoursPerWeek(pathway.getHoursPerWeek())
                .scheduleStatus(derivedScheduleStatus)
                .suggestedActions(suggestedActions)
                .build();
    }

    // ===================== MASTERY QUIZ (spec 20 - B1/B2) =====================

    /**
     * Lay de Mastery Quiz cho 1 node: uu tien cau hoi thuoc lesson FINAL_QUIZ cua
     * course, fallback ve moi lesson quiz khac cua course, cuoi cung lay tu
     * Question
     * Bank theo category. KHONG tra dap an ve FE.
     */
    // LearningPathwayService.getMasteryQuestions - thÃªm null-check
    @Transactional(readOnly = true)
    public List<MasteryQuestionDTO> getMasteryQuestions(Long pathwayId, Long nodeId, Long studentId) {
        LearningPathway pathway = learningPathwayRepository.findById(pathwayId)
                .orElseThrow(() -> new ApiException("Pathway not found", HttpStatus.NOT_FOUND));
        if (!pathway.getStudent().getId().equals(studentId)) {
            throw new ApiException("Access denied", HttpStatus.FORBIDDEN);
        }
        PathwayNode node = pathway.getNodes().stream()
                .filter(n -> n.getId().equals(nodeId))
                .findFirst()
                .orElseThrow(() -> new ApiException("Node not found in pathway", HttpStatus.NOT_FOUND));

        if ("LOCKED".equalsIgnoreCase(node.getStatus())) {
            throw new ApiException("Finish the course before taking its mastery quiz", HttpStatus.BAD_REQUEST);
        }

        // Defensive: course/category cÃ³ thá»ƒ null
        Course course = node.getCourse();
        if (course == null) {
            throw new ApiException("Node has no associated course", HttpStatus.INTERNAL_SERVER_ERROR);
        }
        Long courseId = course.getId();

        List<Long> quizLessonIds = resolveQuizLessonIds(courseId);

        if (!quizLessonIds.isEmpty()) {
            List<MasteryQuestionDTO> questions = loadQuestionsFromLessonQuizzes(quizLessonIds, 10);
            if (!questions.isEmpty()) {
                return questions;
            }
        }

        // Fallback: category có thể null
        String category = null;
        if (node.getCourse() != null && node.getCourse().getCategory() != null) {
            category = node.getCourse().getCategory().getParamValue();
        }
        return loadQuestionsFromBank(category, 10);
    }

    /**
     * Nop bai Mastery: cham server-side, luu attempt voi state='MASTERY' vao
     * lesson_quiz_attempts (khong can bang moi), cap nhat mastery/spaced-repetition
     * cua node va tra lai pathway da cap nhat.
     */
    @Transactional
    public LearningPathwayResponseDTO submitMasteryAnswers(
            Long pathwayId, Long nodeId, Long studentId,
            com.hango.hango_backend.dto.MasterySubmitRequestDTO request) {
        LearningPathway pathway = learningPathwayRepository.findById(pathwayId)
                .orElseThrow(() -> new ApiException("Pathway not found", HttpStatus.NOT_FOUND));
        if (!pathway.getStudent().getId().equals(studentId)) {
            throw new ApiException("Access denied", HttpStatus.FORBIDDEN);
        }
        PathwayNode node = pathway.getNodes().stream()
                .filter(n -> n.getId().equals(nodeId))
                .findFirst()
                .orElseThrow(() -> new ApiException("Node not found in pathway", HttpStatus.NOT_FOUND));

        Map<Long, List<Integer>> answers = new HashMap<>();
        if (request.getAnswers() != null) {
            request.getAnswers().forEach((k, v) -> {
                List<Integer> selectedList = new ArrayList<>();
                if (v instanceof Integer) {
                    selectedList.add((Integer) v);
                } else if (v instanceof List) {
                    for (Object item : (List<?>) v) {
                        if (item instanceof Integer) selectedList.add((Integer) item);
                    }
                }
                answers.put(Long.parseLong(k), selectedList);
            });
        }
        if (answers.isEmpty()) {
            throw new ApiException("Answers are required", HttpStatus.BAD_REQUEST);
        }

        Long courseId = node.getCourse().getId();
        List<Long> quizLessonIds = resolveQuizLessonIds(courseId);

        // Cham tung cau: dung bang question_options de xac dinh dap an dung
        int correct = 0;
        List<Map<String, Object>> answerRecords = new ArrayList<>();
        for (Map.Entry<Long, List<Integer>> entry : answers.entrySet()) {
            Long questionId = entry.getKey();
            List<Integer> selectedList = entry.getValue();
            List<Boolean> flags = jdbcTemplate.queryForList(
                    "SELECT qo.is_correct FROM question_options qo WHERE qo.question_id = ? ORDER BY id ASC",
                    Boolean.class, questionId);
            boolean ok = true;
            for (int i = 0; i < flags.size(); i++) {
                boolean isOptionCorrect = Boolean.TRUE.equals(flags.get(i));
                boolean isOptionSelected = selectedList.contains(i);
                if (isOptionCorrect != isOptionSelected) {
                    ok = false;
                    break;
                }
            }
            if (ok)
                correct++;
            Map<String, Object> rec = new LinkedHashMap<>();
            rec.put("questionId", questionId);
            rec.put("selectedOption", selectedList);
            rec.put("isCorrect", ok);
            answerRecords.add(rec);
        }

        int score = (int) Math.round(100.0 * correct / answers.size());

        // Luu attempt vao lesson_quiz_attempts voi state='MASTERY' (thay cho bang moi)
        Long primaryLessonId = !quizLessonIds.isEmpty() ? quizLessonIds.get(0) : null;
        if (primaryLessonId != null) {
            Lesson quizLesson = lessonRepository.findById(primaryLessonId).orElse(null);
            if (quizLesson != null) {
                User attemptStudent = userRepository.findById(studentId)
                        .orElseThrow(() -> new ApiException("User not found", HttpStatus.NOT_FOUND));
                int attemptNumber = quizAttemptRepository.countByLessonIdAndStudentId(primaryLessonId, studentId) + 1;
                String answersJson;
                try {
                    answersJson = objectMapper.writeValueAsString(answerRecords);
                } catch (com.fasterxml.jackson.core.JsonProcessingException e) {
                    answersJson = "{}";
                }
                quizAttemptRepository.save(com.hango.hango_backend.entity.LessonQuizAttempt.builder()
                        .lesson(quizLesson)
                        .student(attemptStudent)
                        .score((double) score)
                        .attemptNumber(attemptNumber)
                        .state(ATTEMPT_STATE_MASTERY)
                        .answersJson(answersJson)
                        .submittedAt(java.time.LocalDateTime.now())
                        .build());
            }
        } else {
            log.warn("Mastery submitted for node {} but course {} has no quiz lesson; only node fields updated", nodeId,
                    courseId);
        }

        applyMasteryResult(node, score);
        learningPathwayRepository.save(pathway);
        return toResponseDto(pathway, studentId);
    }

    /**
     * Lesson co cau hoi quiz cua course, uu tien FINAL_QUIZ, sap xep giam dan theo
     * thu tu bai.
     */
    private List<Long> resolveQuizLessonIds(Long courseId) {
        return jdbcTemplate.queryForList(
                "SELECT l.id FROM lessons l " +
                        "JOIN sections s ON l.section_id = s.id " +
                        "WHERE s.course_id = ? AND l.deleted_at IS NULL " +
                        "AND EXISTS (SELECT 1 FROM lesson_quizzes lq WHERE lq.lesson_id = l.id) " +
                        "ORDER BY (l.lesson_type = ?) DESC, l.display_order DESC",
                Long.class, courseId, LESSON_TYPE_FINAL_QUIZ);
    }

    /**
     * Doc cau hoi + options tu lesson_quizzes; KHONG tra correctIndex/explanation
     * ra ngoai.
     */
    private List<com.hango.hango_backend.dto.MasteryQuestionDTO> loadQuestionsFromLessonQuizzes(
            List<Long> lessonIds, int limit) {
        String inClause = lessonIds.stream().map(String::valueOf).collect(Collectors.joining(","));
        List<Long> questionIds = jdbcTemplate.queryForList(
                "SELECT DISTINCT q.id FROM questions q " +
                        "JOIN lesson_quizzes lq ON q.id = lq.question_id " +
                        "WHERE lq.lesson_id IN (" + inClause + ") ORDER BY RAND() LIMIT ?",
                Long.class, limit);
        return buildQuestionDtos(questionIds);
    }

    private List<com.hango.hango_backend.dto.MasteryQuestionDTO> loadQuestionsFromBank(String category, int limit) {
        List<Long> questionIds;
        if (category != null && !category.isBlank()) {
            questionIds = jdbcTemplate.queryForList(
                    "SELECT q.id FROM questions q " +
                            "JOIN system_parameters sk ON q.skill_param_id = sk.id AND q.status = 'APPROVED' " +
                            "WHERE UPPER(sk.param_value) IN (" +
                            "  SELECT UPPER(sp.param_key) FROM system_parameters sp " +
                            "  WHERE sp.param_type = 'SKILL_CATEGORY_MAP' AND UPPER(sp.param_value) = UPPER(?)" +
                            ") ORDER BY RAND() LIMIT ?",
                    Long.class, category.trim(), limit);
            if (!questionIds.isEmpty()) {
                return buildQuestionDtos(questionIds);
            }
        }
        // Cuoi cung: bat ky cau APPROVED nao
        try {
            questionIds = jdbcTemplate.queryForList(
                    "SELECT id FROM questions WHERE status = 'APPROVED' ORDER BY RAND() LIMIT ?",
                    Long.class, limit);
        } catch (Exception e) {
            questionIds = jdbcTemplate.queryForList(
                    "SELECT id FROM questions ORDER BY RAND() LIMIT ?", Long.class, limit);
        }
        return buildQuestionDtos(questionIds);
    }

    private List<com.hango.hango_backend.dto.MasteryQuestionDTO> buildQuestionDtos(List<Long> questionIds) {
        List<com.hango.hango_backend.dto.MasteryQuestionDTO> result = new ArrayList<>();
        for (Long qId : questionIds) {
            List<Map<String, Object>> rows = jdbcTemplate.queryForList(
                    "SELECT q.question_text, qg.context_text AS passage " +
                            "FROM questions q LEFT JOIN question_groups qg ON q.group_id = qg.id " +
                            "WHERE q.id = ?",
                    qId);
            if (rows.isEmpty())
                continue;
            List<Map<String, Object>> optionsData = jdbcTemplate.queryForList(
                    "SELECT option_text, is_correct FROM question_options WHERE question_id = ? ORDER BY id ASC",
                    qId);
            if (optionsData.isEmpty())
                continue;

            List<String> options = new ArrayList<>();
            int correctCount = 0;
            for (Map<String, Object> optRow : optionsData) {
                options.add((String) optRow.get("option_text"));
                Boolean isCorrect = (Boolean) optRow.get("is_correct");
                if (isCorrect != null && isCorrect) correctCount++;
            }

            result.add(com.hango.hango_backend.dto.MasteryQuestionDTO.builder()
                    .questionId(qId)
                    .questionText((String) rows.get(0).get("question_text"))
                    .passage((String) rows.get(0).get("passage"))
                    .options(options)
                    .isMultipleChoice(correctCount > 1)
                    .build());
        }
        return result;
    }

    /**
     * Ap ket qua mastery vao node: >=80 thi mastered + tang chu ky on tap
     * 1->3->7->14->30 ngay.
     */
    private void applyMasteryResult(PathwayNode node, Integer score) {
        node.setMasteryScore(score);
        if (score != null && score >= MASTERY_PASS_SCORE) {
            node.setIsMastered(true);
            if (node.getReviewIntervalDays() == null) {
                node.setReviewIntervalDays(1);
            } else {
                int current = node.getReviewIntervalDays();
                if (current == 1)
                    node.setReviewIntervalDays(3);
                else if (current == 3)
                    node.setReviewIntervalDays(7);
                else if (current == 7)
                    node.setReviewIntervalDays(14);
                else if (current == 14)
                    node.setReviewIntervalDays(30);
            }
            node.setNextReviewDate(java.time.LocalDateTime.now().plusDays(node.getReviewIntervalDays()));
        } else {
            node.setIsMastered(false);
        }
    }

    @Transactional
    public LearningPathwayResponseDTO submitNodeMastery(Long pathwayId, Long nodeId, Long studentId,
            com.hango.hango_backend.dto.MasterySubmitRequestDTO request) {
        LearningPathway pathway = learningPathwayRepository.findById(pathwayId)
                .orElseThrow(() -> new ApiException("Pathway not found", HttpStatus.NOT_FOUND));

        if (!pathway.getStudent().getId().equals(studentId)) {
            throw new ApiException("Access denied", HttpStatus.FORBIDDEN);
        }

        PathwayNode node = pathway.getNodes().stream()
                .filter(n -> n.getId().equals(nodeId))
                .findFirst()
                .orElseThrow(() -> new ApiException("Node not found in pathway", HttpStatus.NOT_FOUND));

        // B3: validate score hop le truoc khi ap dung
        if (request.getScore() == null || request.getScore() < 0 || request.getScore() > 100) {
            throw new ApiException("Score must be between 0 and 100", HttpStatus.BAD_REQUEST);
        }

        applyMasteryResult(node, request.getScore());
        pathway.setMentorSummary(Boolean.TRUE.equals(node.getIsMastered())
                ? "Congratulations on achieving Mastery! This course is scheduled for review in "
                        + node.getReviewIntervalDays() + " days."
                : "Your score is " + request.getScore() + ". You need " + MASTERY_PASS_SCORE
                        + " points to Master the course. Keep reviewing!");

        return toResponseDto(pathway, studentId);
    }

    /**
     * Calculates the real course completion percentage for a given learner and
     * course,
     * based on actual LessonProgress records stored in the DB.
     */
    private int calculateCourseProgressPercent(Long studentId, Long courseId) {
        try {
            long totalLessons = lessonRepository.countByCourseId(courseId);
            if (totalLessons == 0)
                return 0;
            long completedLessons = countCompletedLessons(studentId, courseId);
            return (int) Math.min(100, Math.round((double) completedLessons / totalLessons * 100));
        } catch (Exception e) {
            log.warn("Failed to calculate progress for student={} course={}: {}", studentId, courseId, e.getMessage());
            return 0;
        }
    }

    private long countCompletedLessons(Long studentId, Long courseId) {
        return lessonProgressRepository.countCompletedLessonsByUserIdAndCourseId(studentId, courseId);
    }

    private LearningPathwayResponseDTO createEmptyPathway(User student, ExamAttempt examAttempt, String mentorSummary) {
        archiveActivePathway(student.getId());

        LearningPathway pathway = LearningPathway.builder()
                .student(student)
                .examAttempt(examAttempt)
                .mentorSummary(mentorSummary)
                .status("ACTIVE")
                .build();

        LearningPathway savedPathway = learningPathwayRepository.save(pathway);
        return toResponseDto(savedPathway, student.getId());
    }

    private void archiveActivePathway(Long studentId) {
        // @OneToOne voi exam_attempt: phai go bo tham chieu cu truoc khi pathway moi
        // duoc dung lai cung examAttemptId, neu roi vao constraint violation
        Optional<LearningPathway> existingPathway = learningPathwayRepository.findByStudentIdAndStatus(studentId,
                "ACTIVE");
        existingPathway.ifPresent(pathway -> {
            pathway.setStatus("ARCHIVED");
            pathway.setExamAttempt(null); // Clear reference so the new pathway can reuse the same examAttemptId
                                          // (@OneToOne constraint)
            learningPathwayRepository.saveAndFlush(pathway);
        });
    }

    private LearningPathwayResponseDTO buildFallbackPathwayDto(
            ExamAttempt examAttempt,
            List<Course> availableCourses,
            boolean usingExistingCoursesFallback,
            List<String> weakCategories) {

        // Prioritize courses matching weak categories
        List<Course> prioritizedCourses = new ArrayList<>();
        List<Course> otherCourses = new ArrayList<>();

        for (Course course : availableCourses) {
            if (course.getCategory() != null && weakCategories.contains(course.getCategory().getParamValue())) {
                prioritizedCourses.add(course);
            } else {
                otherCourses.add(course);
            }
        }

        List<Course> selectedCourses = new ArrayList<>();
        selectedCourses.addAll(prioritizedCourses);
        selectedCourses.addAll(otherCourses);

        AtomicInteger step = new AtomicInteger(1);
        return LearningPathwayResponseDTO.builder()
                .roadmapId("AUTO_GEN")
                .mentorSummary(usingExistingCoursesFallback
                        ? "TÃ´i Ä‘Ã£ táº¡o má»™t lá»™ trÃ¬nh khá»Ÿi Ä‘áº§u tá»« cÃ¡c khÃ³a há»c hiá»‡n cÃ³ trong HanGo. Vui lÃ²ng Ä‘Äƒng táº£i thÃªm khÃ³a há»c Ä‘á»ƒ cÃ³ Ä‘Æ°á»£c nhá»¯ng gá»£i Ã½ chÃ­nh xÃ¡c hÆ¡n."
                        : "TÃ´i Ä‘Ã£ táº¡o má»™t lá»™ trÃ¬nh khá»Ÿi Ä‘áº§u táº­p trung vÃ o cÃ¡c Ä‘iá»ƒm yáº¿u cá»§a báº¡n tá»« bÃ i kiá»ƒm tra gáº§n nháº¥t.")
                .nodes(selectedCourses.stream()
                        .limit(4)
                        .map(course -> {
                            int currentStep = step.getAndIncrement();
                            return PathwayNodeDTO.builder()
                                    .step(currentStep)
                                    .courseId(course.getId())
                                    .courseTitle(course.getTitle())
                                    .status(currentStep == 1 ? "IN_PROGRESS" : "LOCKED")
                                    .reasonWhy(defaultReasonForCourse(course, examAttempt))
                                    .progressPercent(0)
                                    .tags(course.getCategory() != null
                                            ? List.of("#" + course.getCategory().getParamValue())
                                            : Collections.emptyList())
                                    .build();
                        })
                        .toList())
                .build();
    }

    private void addFallbackNodes(LearningPathway pathway, ExamAttempt examAttempt, List<Course> availableCourses) {
        for (int index = 0; index < Math.min(availableCourses.size(), 4); index++) {
            Course course = availableCourses.get(index);
            pathway.addNode(PathwayNode.builder()
                    .stepOrder(index + 1)
                    .course(course)
                    .status(index == 0 ? "IN_PROGRESS" : "LOCKED")
                    .reasonWhy(defaultReasonForCourse(course, examAttempt))
                    .progressPercent(0)
                    .build());
        }
    }

    private String normalizeNodeStatus(String status, boolean firstNode) {
        if (status == null || status.isBlank()) {
            return firstNode ? "IN_PROGRESS" : "LOCKED";
        }

        String normalized = status.trim().toUpperCase().replace('-', '_');
        return switch (normalized) {
            case "IN_PROGRESS", "COMPLETED", "LOCKED" -> normalized;
            default -> firstNode ? "IN_PROGRESS" : "LOCKED";
        };
    }

    private String defaultReasonForCourse(Course course, ExamAttempt examAttempt) {
        String scoreText = examAttempt.getScore() != null
                ? " Äiá»ƒm sá»‘ cá»§a báº¡n gáº§n Ä‘Ã¢y nháº¥t lÃ  " + examAttempt.getScore() + "."
                : "";
        String category = course.getCategory() != null ? course.getCategory().getParamValue() : "this topic";
        return "KhÃ³a há»c nÃ y giÃºp báº¡n cá»§ng cá»‘ thÃªm vá» " + category + " dá»±a trÃªn káº¿t quáº£ gáº§n Ä‘Ã¢y nháº¥t cá»§a báº¡n."
                + scoreText;
    }

    private List<String> extractWeakCategories(String knowledgeGapsJson) {
        if (knowledgeGapsJson == null || knowledgeGapsJson.isBlank())
            return Collections.emptyList();
        try {
            @SuppressWarnings("unchecked")
            Map<String, Object> map = objectMapper.readValue(knowledgeGapsJson, Map.class);
            Object weakCategoriesObj = map.get("weak_categories");
            if (weakCategoriesObj instanceof List<?> list) {
                return list.stream().map(Object::toString).toList();
            }
        } catch (Exception e) {
            log.debug("Failed to extract weak categories from knowledge gaps json: {}", e.getMessage());
        }
        return Collections.emptyList();
    }

    private List<String> extractLatestWeakCategories(String knowledgeGapsJson) {
        if (knowledgeGapsJson == null || knowledgeGapsJson.isBlank())
            return Collections.emptyList();
        try {
            @SuppressWarnings("unchecked")
            Map<String, Object> map = objectMapper.readValue(knowledgeGapsJson, Map.class);
            Object weakCategoriesObj = map.get("latest_weak_categories");
            if (weakCategoriesObj instanceof List<?> list) {
                return list.stream().map(Object::toString).toList();
            }
        } catch (Exception e) {
            log.debug("Failed to extract latest weak categories from knowledge gaps json: {}", e.getMessage());
        }
        return Collections.emptyList();
    }
}

