package com.hango.hango_backend.service;

import java.time.LocalDate;
import java.util.Collections;
import java.util.List;
import java.util.Optional;
import java.util.concurrent.atomic.AtomicInteger;

import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.hango.hango_backend.dto.ExamResultAnalysisDTO;
import com.hango.hango_backend.dto.GeminiGenerateRequest;
import com.hango.hango_backend.dto.LearningPathwayResponseDTO;
import com.hango.hango_backend.dto.MentorActionRequestDTO;
import com.hango.hango_backend.dto.PathwayGenerateRequestDTO;
import com.hango.hango_backend.dto.PathwayNodeDTO;
import com.hango.hango_backend.dto.PathwayScheduleRequestDTO;
import com.hango.hango_backend.entity.Course;
import com.hango.hango_backend.entity.ExamAttempt;
import com.hango.hango_backend.entity.LearningPathway;
import com.hango.hango_backend.entity.PathwayNode;
import com.hango.hango_backend.entity.User;
import com.hango.hango_backend.exception.ApiException;
import com.hango.hango_backend.repository.CourseRepository;
import com.hango.hango_backend.repository.ExamAttemptRepository;
import com.hango.hango_backend.repository.LearningPathwayRepository;
import com.hango.hango_backend.repository.LessonProgressRepository;
import com.hango.hango_backend.repository.LessonRepository;
import com.hango.hango_backend.repository.UserRepository;

import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;


@Service
@Slf4j
@RequiredArgsConstructor
public class LearningPathwayService {

    private final LearningPathwayRepository learningPathwayRepository;
    private final ExamAttemptRepository examAttemptRepository;
    private final CourseRepository courseRepository;
    private final UserRepository userRepository;
    private final GeminiClientService geminiClientService;
    private final ObjectMapper objectMapper;
    private final ExamResultAnalyzerService examResultAnalyzerService;
    private final LessonProgressRepository lessonProgressRepository;
    private final LessonRepository lessonRepository;



    @Transactional
    public LearningPathwayResponseDTO generatePathway(Long studentId, PathwayGenerateRequestDTO requestDTO) {
        Long examAttemptId = requestDTO.getExamAttemptId();
        User student = userRepository.findByIdForUpdate(studentId)
                .orElseThrow(() -> new ApiException("User not found", HttpStatus.NOT_FOUND));

        ExamAttempt examAttempt = examAttemptRepository.findById(examAttemptId)
                .orElseThrow(() -> new ApiException("Exam Attempt not found", HttpStatus.NOT_FOUND));

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

        // AI cần đầu vào chuẩn dựa trên lịch sử làm bài của learner.
        // Giữ examAttemptId làm mốc (để đúng yêu cầu API), nhưng vẫn tổng hợp thêm N attempts gần nhất.
        List<ExamAttempt> recentAttempts = examAttemptRepository.findTop10ByStudent_IdOrderBySubmittedAtDesc(studentId);
        ExamResultAnalysisDTO examAnalysis = examResultAnalyzerService.analyzeLearnerAttempts(studentId, recentAttempts);
        if (examAnalysis == null) {
            // Fallback để tránh phá flow (đặc biệt trong unit tests khi mock chưa set returns).
            examAnalysis = examResultAnalyzerService.analyzeLatestExamAttempt(examAttempt);
        }



        String goalText = (requestDTO.getGoalName() != null && !requestDTO.getGoalName().isBlank())
                ? "MỤC TIÊU CỦA NGƯỜI HỌC: " + requestDTO.getGoalName() + "\n"
                : "";

        String systemPrompt = """

                .
                Bạn là Trợ lý lập lộ trình học tập.
                Nhiệm vụ: dựa trên JSON bài thi mới nhất của learner (answersJson) và phần phân tích do tool cung cấp để đề xuất lộ trình cá nhân hóa.

                %s
                Core rules:
                1. Only choose course_id values from [AVAILABLE_COURSES]. Never invent a course.
                2. Prioritize foundations first, then harder reading or advanced skills.
                3. ƯU TIÊN chọn các khóa học khắc phục trực tiếp các "weak_skills" trong phần phân tích và hướng tới MỤC TIÊU CỦA NGƯỜI HỌC. Đưa ra "reason_why" giải thích rõ tại sao khóa học này lại giúp cải thiện điểm yếu hoặc giúp đạt mục tiêu đó.
                4. "mentor_summary" PHẢI LÀ LỜI CHÀO VÀ TÓM TẮT TỔNG QUAN LỘ TRÌNH (ví dụ: "Chào bạn, lộ trình của bạn gồm X khóa học tập trung vào..."). TUYỆT ĐỐI KHÔNG sinh ra bài tập, mini-quiz, hay câu hỏi trắc nghiệm trong mentor_summary.
                5. Return valid JSON only, without markdown fences.

                [AVAILABLE_COURSES]
                %s

                TOOL INPUT (EXAM ANALYSIS):
                - examAttemptId: %s
                - score: %s
                - knowledge_gaps_json: %s

                JSON format:
                {
                  "roadmap_id": "AUTO_GEN",
                  "mentor_summary": "Short mentor analysis...",
                  "nodes": [
                    { "step": 1, "course_id": 1, "reason_why": "Why this course helps...", "status": "IN_PROGRESS", "tags": ["#Grammar"] },
                    { "step": 2, "course_id": 2, "reason_why": "Why this course helps...", "status": "LOCKED", "tags": ["#Reading"] }
                  ]
                }
                """.formatted(
                goalText,
                courseListBuilder,
                examAnalysis.getExamAttemptId(),
                examAnalysis.getScore(),
                examAnalysis.getKnowledgeGapsJson() == null ? "" : examAnalysis.getKnowledgeGapsJson()
        );


        String userContent = "Latest exam attempt: \n" + examAttempt.getAnswersJson();
        List<GeminiGenerateRequest.Content> chatHistory = List.of(
                GeminiGenerateRequest.Content.builder()
                        .role("user")
                        .parts(List.of(GeminiGenerateRequest.Part.builder().text(userContent).build()))
                        .build());

        LearningPathwayResponseDTO responseDto;
        try {
            String aiResponseText = geminiClientService.generateChatResponse(systemPrompt, chatHistory);
            aiResponseText = aiResponseText.replaceAll("(?s)^```json\\s*", "")
                    .replaceAll("(?s)```\\s*$", "")
                    .trim();
            responseDto = objectMapper.readValue(aiResponseText, LearningPathwayResponseDTO.class);
        } catch (Exception e) {
            log.warn("Falling back to deterministic learning pathway because AI generation failed: {}", e.getMessage());
            responseDto = buildFallbackPathwayDto(examAttempt, availableCourses, usingExistingCoursesFallback);
        }

        archiveActivePathway(studentId);

        LearningPathway newPathway = LearningPathway.builder()
                .student(student)
                .examAttempt(examAttempt)
                .mentorSummary(responseDto.getMentorSummary() != null
                        ? responseDto.getMentorSummary()
                        : "Tôi đã xây dựng một lộ trình từ kết quả bài kiểm tra của bạn bằng cách sử dụng các khóa học hiện có trong HanGo.")
                .status("ACTIVE")
                .goalName(requestDTO.getGoalName())
                .targetDate(requestDTO.getTargetDate())
                .hoursPerWeek(requestDTO.getHoursPerWeek())
                .scheduleStatus(requestDTO.getTargetDate() != null ? "ON_TRACK" : null)
                .build();

        if (responseDto.getNodes() != null) {
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
                            .progressPercent(0)
                            .build();
                    newPathway.addNode(node);
                }
            }
        }

        if (newPathway.getNodes().isEmpty()) {
            addFallbackNodes(newPathway, examAttempt, availableCourses);
        }

        if (requestDTO.getTargetDate() != null && requestDTO.getHoursPerWeek() != null && requestDTO.getHoursPerWeek() > 0) {
            applyTimeboxing(newPathway, requestDTO.getTargetDate(), requestDTO.getHoursPerWeek(), requestDTO.getPreferredStudyDays());
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
                ? "Hệ thống đã tự động thay đổi lộ trình học tập do điểm bài kiểm tra gần nhất của bạn hơi thấp. Tôi đang tập trung điều chỉnh lại lộ trình vào các kỹ năng nền tảng mà bạn cần nắm vững trước tiên."
                : "Hiệu suất bài kiểm tra gần đây của bạn là chấp nhận được, vì vậy lộ trình hiện tại vẫn là lựa chọn tốt nhất.");

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
    public LearningPathwayResponseDTO processMentorAction(Long pathwayId, Long studentId, MentorActionRequestDTO request) {
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
                    pathway.setMentorSummary("✅ Đã bỏ qua khóa học '" + currentNode.getCourse().getTitle() + "' và mở khóa bước tiếp theo cho bạn.");
                } else {
                    pathway.setMentorSummary("Không tìm thấy khóa học nào đang học để bỏ qua.");
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
                if (pathway.getTargetDate() != null && pathway.getHoursPerWeek() != null && pathway.getHoursPerWeek() > 0) {
                    applyTimeboxing(pathway, pathway.getTargetDate(), pathway.getHoursPerWeek(), null);
                    pathway.setScheduleStatus("ON_TRACK");
                    pathway.setMentorSummary("📅 Lịch trình đã được tính toán lại" +
                            (newHours != null ? " với " + newHours + " giờ/tuần." : ".") +
                            " Hãy cố gắng theo đúng tiến độ nhé!");
                } else {
                    pathway.setScheduleStatus("AT_RISK");
                    pathway.setMentorSummary("⚠️ Lịch trình chưa thể tính lại vì chưa có ngày mục tiêu hoặc số giờ/tuần. Hãy cập nhật mục tiêu của bạn.");
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
                StringBuilder overview = new StringBuilder("📚 **Tổng quan lộ trình của bạn:**\n\n");
                if (pathway.getGoalName() != null) {
                    overview.append("🎯 Mục tiêu: ").append(pathway.getGoalName()).append("\n");
                }
                int total = pathway.getNodes() != null ? pathway.getNodes().size() : 0;
                long completed = pathway.getNodes() != null ?
                        pathway.getNodes().stream().filter(n -> "COMPLETED".equalsIgnoreCase(n.getStatus())).count() : 0;
                overview.append("📊 Tiến độ: ").append(completed).append("/").append(total).append(" bước hoàn thành\n\n");
                overview.append("Các kỹ năng sẽ được cải thiện:\n");
                if (pathway.getNodes() != null) {
                    for (PathwayNode node : pathway.getNodes()) {
                        String status = switch (node.getStatus().toUpperCase()) {
                            case "COMPLETED" -> "✅";
                            case "IN_PROGRESS" -> "🔄";
                            default -> "🔒";
                        };
                        String skill = node.getCourse().getCategory() != null ?
                                node.getCourse().getCategory().getParamValue() : "General";
                        overview.append(status).append(" Bước ").append(node.getStepOrder())
                                .append(": ").append(node.getCourse().getTitle())
                                .append(" (").append(skill).append(")\n");
                    }
                }
                pathway.setMentorSummary(overview.toString());
            }
            default -> {
                pathway.setMentorSummary("Tôi đã nhận được yêu cầu của bạn (" + actionType + "), nhưng chưa biết cách xử lý nó lúc này.");
            }
        }

        LearningPathway savedPathway = learningPathwayRepository.save(pathway);
        return toResponseDto(savedPathway, studentId);
    }

    private PathwayNode findCurrentInProgressNode(LearningPathway pathway) {
        if (pathway.getNodes() == null) return null;
        return pathway.getNodes().stream()
                .filter(n -> "IN_PROGRESS".equalsIgnoreCase(n.getStatus()))
                .findFirst()
                .orElse(null);
    }

    private String generateMiniQuiz(PathwayNode currentNode) {
        if (currentNode == null) {
            return "📝 Không tìm thấy khóa học đang học để tạo mini-quiz. Hãy bắt đầu một khóa học trước.";
        }
        try {
            String courseName = currentNode.getCourse().getTitle();
            String category = currentNode.getCourse().getCategory() != null ?
                    currentNode.getCourse().getCategory().getParamValue() : "General English";

            String prompt = """
                    Tạo 3 câu hỏi trắc nghiệm (mỗi câu 4 lựa chọn A/B/C/D) về chủ đề "%s" (%s) cho học sinh luyện thi THPT Quốc gia Tiếng Anh.
                    Format mỗi câu:
                    **Câu X:** [câu hỏi]
                    A. [lựa chọn]
                    B. [lựa chọn]
                    C. [lựa chọn]
                    D. [lựa chọn]
                    ✅ Đáp án: [đáp án đúng]

                    Chỉ trả về đúng 3 câu hỏi, không thêm gì khác.
                    """.formatted(courseName, category);

            java.util.List<com.hango.hango_backend.dto.GeminiGenerateRequest.Content> history = java.util.List.of(
                    com.hango.hango_backend.dto.GeminiGenerateRequest.Content.builder()
                            .role("user")
                            .parts(java.util.List.of(com.hango.hango_backend.dto.GeminiGenerateRequest.Part.builder().text(prompt).build()))
                            .build());

            String quizText = geminiClientService.generateChatResponse(
                    "Bạn là giáo viên Tiếng Anh THPT. Tạo câu hỏi trắc nghiệm chất lượng.", history);
            return "📝 **Mini-Quiz: " + courseName + "**\n\n" + quizText;
        } catch (Exception e) {
            log.warn("Failed to generate mini-quiz: {}", e.getMessage());
            return "📝 Tôi đang gặp sự cố khi tạo mini-quiz. Vui lòng thử lại sau.";
        }
    }

    @Transactional
    public LearningPathwayResponseDTO applySchedule(Long pathwayId, Long studentId, PathwayScheduleRequestDTO requestDTO) {
        LearningPathway pathway = learningPathwayRepository.findById(pathwayId)
                .orElseThrow(() -> new ApiException("Pathway not found", HttpStatus.NOT_FOUND));

        if (!pathway.getStudent().getId().equals(studentId)) {
            throw new ApiException("Access denied", HttpStatus.FORBIDDEN);
        }

        pathway.setGoalName(requestDTO.getGoalName());
        pathway.setTargetDate(requestDTO.getTargetDate());
        pathway.setHoursPerWeek(requestDTO.getHoursPerWeek());
        pathway.setScheduleStatus("ON_TRACK");

        applyTimeboxing(pathway, requestDTO.getTargetDate(), requestDTO.getHoursPerWeek(), requestDTO.getPreferredStudyDays());

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

    private void applyTimeboxing(LearningPathway pathway, LocalDate targetDate, Integer hoursPerWeek, List<Integer> preferredStudyDays) {
        if (pathway.getNodes() == null || pathway.getNodes().isEmpty()) return;

        List<Integer> estimatedHoursPerNode = new java.util.ArrayList<>();
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
                pathway.getNodes().size()
        );

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
            if (totalLessons > 0 && realProgress >= 100) {
                resolvedStatus = "COMPLETED";
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
                    .tags(node.getCourse().getCategory() != null
                            ? List.of("#" + node.getCourse().getCategory().getParamValue())
                            : Collections.emptyList())
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
                java.util.Map<String, Object> gaps = objectMapper.readValue(analysisDTO.getKnowledgeGapsJson(), java.util.Map.class);
                Object ws = gaps.get("weak_skills");
                if (ws instanceof List<?> wsList) {
                    weakSkills = wsList.stream().map(Object::toString).toList();
                }
            } catch (Exception e) {
                log.debug("Failed to parse weak_skills from knowledge gap: {}", e.getMessage());
            }
        }

        List<String> suggestedActions = new java.util.ArrayList<>();

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
        }

        if ("BEHIND".equalsIgnoreCase(pathway.getScheduleStatus()) || "AT_RISK".equalsIgnoreCase(pathway.getScheduleStatus())) {
            suggestedActions.add("ADJUST_SCHEDULE");
        }

        // Always offer overview
        suggestedActions.add("WHAT_WILL_I_LEARN");

        // If no contextual actions were added, add quiz as a safe default
        if (suggestedActions.size() == 1) {
            suggestedActions.add(0, "TAKE_QUIZ");
        }

        return LearningPathwayResponseDTO.builder()
                .pathwayId(pathway.getId())
                .roadmapId("RM_USER_" + studentId + "_" + pathway.getId())
                .mentorSummary(pathway.getMentorSummary())
                .nodes(nodeDTOs)
                .totalSteps(totalSteps)
                .completedSteps(completedSteps)
                .weakSkills(weakSkills)
                .goalName(pathway.getGoalName())
                .targetDate(pathway.getTargetDate() != null ? pathway.getTargetDate().toString() : null)
                .hoursPerWeek(pathway.getHoursPerWeek())
                .scheduleStatus(pathway.getScheduleStatus())
                .suggestedActions(suggestedActions)
                .build();
    }

    @Transactional
    public LearningPathwayResponseDTO submitNodeMastery(Long pathwayId, Long nodeId, Long studentId, com.hango.hango_backend.dto.MasterySubmitRequestDTO request) {
        LearningPathway pathway = learningPathwayRepository.findById(pathwayId)
                .orElseThrow(() -> new ApiException("Pathway not found", HttpStatus.NOT_FOUND));

        if (!pathway.getStudent().getId().equals(studentId)) {
            throw new ApiException("Access denied", HttpStatus.FORBIDDEN);
        }

        PathwayNode node = pathway.getNodes().stream()
                .filter(n -> n.getId().equals(nodeId))
                .findFirst()
                .orElseThrow(() -> new ApiException("Node not found in pathway", HttpStatus.NOT_FOUND));

        node.setMasteryScore(request.getScore());
        
        if (request.getScore() != null && request.getScore() >= 80) { // Assuming 80 is the mastery threshold
            node.setIsMastered(true);
            
            // Spaced Repetition logic
            if (node.getReviewIntervalDays() == null) {
                node.setReviewIntervalDays(1);
            } else {
                // simple progression: 1 -> 3 -> 7 -> 14 -> 30
                int current = node.getReviewIntervalDays();
                if (current == 1) node.setReviewIntervalDays(3);
                else if (current == 3) node.setReviewIntervalDays(7);
                else if (current == 7) node.setReviewIntervalDays(14);
                else if (current == 14) node.setReviewIntervalDays(30);
            }
            node.setNextReviewDate(java.time.LocalDateTime.now().plusDays(node.getReviewIntervalDays()));
            pathway.setMentorSummary("Congratulations on achieving Mastery! This course is scheduled for review in " + node.getReviewIntervalDays() + " days.");
        } else {
            node.setIsMastered(false);
            pathway.setMentorSummary("Your score is " + request.getScore() + ". You need 80 points to Master the course. Keep reviewing!");
        }

        return toResponseDto(pathway, studentId);
    }

    /**
     * Calculates the real course completion percentage for a given learner and course,
     * based on actual LessonProgress records stored in the DB.
     */
    private int calculateCourseProgressPercent(Long studentId, Long courseId) {
        try {
            long totalLessons = lessonRepository.countByCourseId(courseId);
            if (totalLessons == 0) return 0;
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
        Optional<LearningPathway> existingPathway = learningPathwayRepository.findByStudentIdAndStatus(studentId, "ACTIVE");
        existingPathway.ifPresent(pathway -> {
            pathway.setStatus("ARCHIVED");
            learningPathwayRepository.save(pathway);
        });
    }

    private LearningPathwayResponseDTO buildFallbackPathwayDto(
            ExamAttempt examAttempt,
            List<Course> availableCourses,
            boolean usingExistingCoursesFallback) {
        AtomicInteger step = new AtomicInteger(1);
        return LearningPathwayResponseDTO.builder()
                .roadmapId("AUTO_GEN")
                .mentorSummary(usingExistingCoursesFallback
                        ? "Tôi đã tạo một lộ trình khởi đầu từ các khóa học hiện có trong HanGo. Vui lòng đăng tải thêm khóa học để có được những gợi ý chính xác hơn."
                        : "Tôi đã tạo một lộ trình khởi đầu từ kết quả bài kiểm tra gần nhất của bạn và các khóa học đang được công bố trong HanGo.")
                .nodes(availableCourses.stream()
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
                ? " Điểm số của bạn gần đây nhất là " + examAttempt.getScore() + "."
                : "";
        String category = course.getCategory() != null ? course.getCategory().getParamValue() : "this topic";
        return "Khóa học này giúp bạn củng cố thêm về " + category + " dựa trên kết quả gần đây nhất của bạn." + scoreText;
    }
}

