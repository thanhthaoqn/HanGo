package com.hango.hango_backend.service;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.hango.hango_backend.dto.GeminiGenerateRequest;
import com.hango.hango_backend.dto.LearningPathwayResponseDTO;
import com.hango.hango_backend.dto.PathwayNodeDTO;
import com.hango.hango_backend.entity.Course;
import com.hango.hango_backend.entity.ExamAttempt;
import com.hango.hango_backend.entity.LearningPathway;
import com.hango.hango_backend.entity.PathwayNode;
import com.hango.hango_backend.entity.User;
import com.hango.hango_backend.exeption.ApiException;
import com.hango.hango_backend.repository.CourseRepository;
import com.hango.hango_backend.repository.ExamAttemptRepository;
import com.hango.hango_backend.repository.LearningPathwayRepository;
import com.hango.hango_backend.repository.UserRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.Collections;
import java.util.List;
import java.util.Optional;
import java.util.concurrent.atomic.AtomicInteger;

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

    @Transactional
    public LearningPathwayResponseDTO generatePathway(Long studentId, Long examAttemptId) {
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

        String systemPrompt = """
                You are an experienced AI Mentor for high school English exam preparation.
                Analyze the learner exam result JSON and propose a personalized learning roadmap with at most 4 steps.

                Core rules:
                1. Only choose course_id values from [AVAILABLE_COURSES]. Never invent a course.
                2. Prioritize foundations first, then harder reading or advanced skills.
                3. Return valid JSON only, without markdown fences.

                [AVAILABLE_COURSES]
                %s

                JSON format:
                {
                  "roadmap_id": "AUTO_GEN",
                  "mentor_summary": "Short mentor analysis...",
                  "nodes": [
                    { "step": 1, "course_id": 1, "reason_why": "Why this course helps...", "status": "IN_PROGRESS", "tags": ["#Grammar"] },
                    { "step": 2, "course_id": 2, "reason_why": "Why this course helps...", "status": "LOCKED", "tags": ["#Reading"] }
                  ]
                }
                """.formatted(courseListBuilder);

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
                        : "I built a pathway from your exam result using the currently available HanGo courses.")
                .status("ACTIVE")
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

        LearningPathway savedPathway = learningPathwayRepository.save(newPathway);
        return toResponseDto(savedPathway, studentId);
    }

    @Transactional
    public LearningPathwayResponseDTO reroutePathway(Long pathwayId, Long studentId, int quizScore) {
        LearningPathway pathway = learningPathwayRepository.findById(pathwayId)
                .orElseThrow(() -> new ApiException("Pathway not found", HttpStatus.NOT_FOUND));

        if (!pathway.getStudent().getId().equals(studentId)) {
            throw new ApiException("Access denied", HttpStatus.FORBIDDEN);
        }

        pathway.setMentorSummary(quizScore < 60
                ? "Dynamic rerouting triggered because your latest quiz score was low. I am refocusing the roadmap on the foundational skills you need first."
                : "Your recent quiz performance is acceptable, so the current roadmap remains the best fit.");

        if (pathway.getNodes() != null) {
            boolean firstNodeSeen = false;
            for (PathwayNode node : pathway.getNodes()) {
                if (!firstNodeSeen && node.getStepOrder() != null && node.getStepOrder() == 1) {
                    node.setStatus("IN_PROGRESS");
                    node.setProgressPercent(Math.max(node.getProgressPercent(), 25));
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

    public String chatWithMentor(Long pathwayId, Long studentId, String message) {
        LearningPathway pathway = learningPathwayRepository.findById(pathwayId)
                .orElseThrow(() -> new ApiException("Pathway not found", HttpStatus.NOT_FOUND));

        if (!pathway.getStudent().getId().equals(studentId)) {
            throw new ApiException("Access denied", HttpStatus.FORBIDDEN);
        }

        String systemPrompt = """
                You are an AI Mentor. The learner is following this pathway.
                Answer briefly, clearly, and kindly.
                Current pathway steps: %s
                """.formatted(pathway.getNodes().stream()
                .map(node -> "Step " + node.getStepOrder() + ": " + node.getCourse().getTitle())
                .reduce("", (left, right) -> left + "\n" + right));

        List<GeminiGenerateRequest.Content> chatHistory = List.of(
                GeminiGenerateRequest.Content.builder()
                        .role("user")
                        .parts(List.of(GeminiGenerateRequest.Part.builder().text(message).build()))
                        .build());

        return geminiClientService.generateChatResponse(systemPrompt, chatHistory);
    }

    private LearningPathwayResponseDTO toResponseDto(LearningPathway pathway, Long studentId) {
        return LearningPathwayResponseDTO.builder()
                .pathwayId(pathway.getId())
                .roadmapId("RM_USER_" + studentId + "_" + pathway.getId())
                .mentorSummary(pathway.getMentorSummary())
                .nodes(pathway.getNodes().stream().map(node -> PathwayNodeDTO.builder()
                        .step(node.getStepOrder())
                        .courseId(node.getCourse().getId())
                        .courseTitle(node.getCourse().getTitle())
                        .status(node.getStatus())
                        .reasonWhy(node.getReasonWhy())
                        .progressPercent(node.getProgressPercent())
                        .tags(node.getCourse().getCategory() != null
                                ? List.of("#" + node.getCourse().getCategory().getParamValue())
                                : Collections.emptyList())
                        .build()).toList())
                .build();
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
                        ? "I generated a starter pathway from the courses currently available in HanGo. Publish more courses later to make recommendations sharper."
                        : "I generated a starter pathway from your latest exam result and the currently published HanGo courses.")
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
                ? " Your latest score was " + examAttempt.getScore() + "."
                : "";
        String category = course.getCategory() != null ? course.getCategory().getParamValue() : "this topic";
        return "This course helps reinforce " + category + " based on your recent test result." + scoreText;
    }
}
