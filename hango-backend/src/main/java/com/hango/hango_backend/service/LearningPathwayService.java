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

import java.util.List;
import java.util.Optional;

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
        User student = userRepository.findById(studentId)
                .orElseThrow(() -> new ApiException("User not found", HttpStatus.NOT_FOUND));

        ExamAttempt examAttempt = examAttemptRepository.findById(examAttemptId)
                .orElseThrow(() -> new ApiException("Exam Attempt not found", HttpStatus.NOT_FOUND));

        if (!examAttempt.getStudent().getId().equals(studentId)) {
            throw new ApiException("Access denied to this exam attempt", HttpStatus.FORBIDDEN);
        }

        // 1. Lấy danh sách System Courses
        List<Course> availableCourses = courseRepository.findAll().stream()
                .filter(c -> "PUBLISHED".equalsIgnoreCase(c.getStatus()))
                .toList();

        StringBuilder courseListBuilder = new StringBuilder();
        for (Course c : availableCourses) {
            courseListBuilder.append(String.format("- ID: %d, Tên: %s, Thể loại: %s, Độ khó: %s, Tóm tắt: %s\n",
                    c.getId(),
                    c.getTitle(),
                    c.getCategory() != null ? c.getCategory().getParamValue() : "N/A",
                    c.getDifficulty() != null ? c.getDifficulty().getParamValue() : "N/A",
                    c.getDescription()
            ));
        }

        // 2. Build System Prompt
        String systemPrompt = """
                Bạn là một AI Mentor giàu kinh nghiệm ôn thi THPT Quốc gia môn Tiếng Anh.
                Nhiệm vụ của bạn là phân tích cấu trúc dữ liệu JSON bài làm của học viên, nhận diện lỗ hổng kiến thức,
                sau đó ĐỀ XUẤT một lộ trình học tập (Roadmap) cá nhân hoá, gồm tối đa 4 bước.
                
                QUY TẮC CỐT LÕI (BẮT BUỘC TUÂN THỦ):
                1. CHỈ ĐƯỢC PHÉP chọn khóa học (course_id) từ danh sách [AVAILABLE_COURSES] dưới đây. TUYỆT ĐỐI KHÔNG tự bịa ra khóa học.
                2. Lộ trình phải đi từ nền tảng (Ngữ pháp/Từ vựng cơ bản) lên nâng cao (Đọc hiểu).
                3. Định dạng trả về BẮT BUỘC là chuỗi JSON hợp lệ (không bao gồm markdown block ```json hay gì khác).
                
                [AVAILABLE_COURSES]
                %s
                
                ĐỊNH DẠNG JSON TRẢ VỀ:
                {
                  "roadmap_id": "AUTO_GEN",
                  "mentor_summary": "Nhận xét tổng quan của mentor về bài thi...",
                  "nodes": [
                    { "step": 1, "course_id": 1, "reason_why": "Lý do học phần này...", "status": "In_Progress", "tags": ["#Grammar"] },
                    { "step": 2, "course_id": 2, "reason_why": "Lý do học phần này...", "status": "Locked", "tags": ["#Reading"] }
                  ]
                }
                """.formatted(courseListBuilder.toString());

        // 3. Chuẩn bị nội dung gửi cho AI (Dữ liệu bài thi)
        String userContent = "Đây là kết quả thi của tôi: \n" + examAttempt.getAnswersJson();

        List<GeminiGenerateRequest.Content> chatHistory = List.of(
                GeminiGenerateRequest.Content.builder()
                        .role("user")
                        .parts(List.of(GeminiGenerateRequest.Part.builder().text(userContent).build()))
                        .build()
        );

        // 4. Gọi AI
        String aiResponseText = geminiClientService.generateChatResponse(systemPrompt, chatHistory);

        // 5. Làm sạch và Parse JSON
        aiResponseText = aiResponseText.replaceAll("(?s)^```json\\s*", "")
                .replaceAll("(?s)```\\s*$", "")
                .trim();

        LearningPathwayResponseDTO responseDto;
        try {
            responseDto = objectMapper.readValue(aiResponseText, LearningPathwayResponseDTO.class);
        } catch (Exception e) {
            log.error("Failed to parse AI JSON response: {}", aiResponseText, e);
            throw new ApiException("AI returned invalid JSON format", HttpStatus.INTERNAL_SERVER_ERROR);
        }

        // 6. Xoá lộ trình cũ nếu có (hoặc Archive)
        Optional<LearningPathway> existingPathway = learningPathwayRepository.findByStudentIdAndStatus(studentId, "ACTIVE");
        existingPathway.ifPresent(p -> {
            p.setStatus("ARCHIVED");
            learningPathwayRepository.save(p);
        });

        // 7. Lưu vào DB
        LearningPathway newPathway = LearningPathway.builder()
                .student(student)
                .examAttempt(examAttempt)
                .mentorSummary(responseDto.getMentorSummary())
                .status("ACTIVE")
                .build();

        if (responseDto.getNodes() != null) {
            for (PathwayNodeDTO nodeDto : responseDto.getNodes()) {
                Course course = availableCourses.stream()
                        .filter(c -> c.getId().equals(nodeDto.getCourseId()))
                        .findFirst()
                        .orElse(null);

                if (course != null) {
                    PathwayNode node = PathwayNode.builder()
                            .stepOrder(nodeDto.getStep())
                            .course(course)
                            .status(nodeDto.getStatus() != null ? nodeDto.getStatus() : "LOCKED")
                            .reasonWhy(nodeDto.getReasonWhy())
                            .progressPercent(0)
                            .build();
                    newPathway.addNode(node);
                }
            }
        }

        learningPathwayRepository.save(newPathway);

        // Cập nhật lại DTO để trả về cho Client
        responseDto.setPathwayId(newPathway.getId());
        responseDto.setRoadmapId("RM_USER_" + studentId + "_" + newPathway.getId());
        
        // Thêm CourseTitle vào DTO để hiển thị
        for (PathwayNodeDTO dto : responseDto.getNodes()) {
            availableCourses.stream()
                    .filter(c -> c.getId().equals(dto.getCourseId()))
                    .findFirst()
                    .ifPresent(c -> dto.setCourseTitle(c.getTitle()));
        }

        return responseDto;
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
        return LearningPathwayResponseDTO.builder()
                .pathwayId(savedPathway.getId())
                .roadmapId("RM_USER_" + studentId + "_" + savedPathway.getId())
                .mentorSummary(savedPathway.getMentorSummary())
                .nodes(savedPathway.getNodes().stream().map(node -> PathwayNodeDTO.builder()
                        .step(node.getStepOrder())
                        .courseId(node.getCourse().getId())
                        .courseTitle(node.getCourse().getTitle())
                        .status(node.getStatus())
                        .reasonWhy(node.getReasonWhy())
                        .progressPercent(node.getProgressPercent())
                        .tags(node.getCourse().getCategory() != null ? List.of("#" + node.getCourse().getCategory().getParamValue()) : java.util.Collections.emptyList())
                        .build()).toList())
                .build();
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
                        .tags(node.getCourse().getCategory() != null ? List.of("#" + node.getCourse().getCategory().getParamValue()) : java.util.Collections.emptyList())
                        .build()).toList())
                .build();
    }

    public String chatWithMentor(Long pathwayId, Long studentId, String message) {
        LearningPathway pathway = learningPathwayRepository.findById(pathwayId)
                .orElseThrow(() -> new ApiException("Pathway not found", HttpStatus.NOT_FOUND));

        if (!pathway.getStudent().getId().equals(studentId)) {
            throw new ApiException("Access denied", HttpStatus.FORBIDDEN);
        }

        String systemPrompt = """
                Bạn là AI Mentor. Học sinh đang theo lộ trình học tập do bạn đề xuất.
                Hãy trả lời câu hỏi của học sinh một cách ngắn gọn, súc tích và thân thiện.
                Lộ trình hiện tại của học sinh gồm các bước sau: %s
                """.formatted(pathway.getNodes().stream()
                .map(n -> "Bước " + n.getStepOrder() + ": " + n.getCourse().getTitle())
                .reduce("", (a, b) -> a + "\n" + b));

        List<GeminiGenerateRequest.Content> chatHistory = List.of(
                GeminiGenerateRequest.Content.builder()
                        .role("user")
                        .parts(List.of(GeminiGenerateRequest.Part.builder().text(message).build()))
                        .build()
        );

        return geminiClientService.generateChatResponse(systemPrompt, chatHistory);
    }
}
