package com.hango.hango_backend.service;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.hango.hango_backend.config.GeminiProperties;
import com.hango.hango_backend.dto.ExamCourseRecommendationAIResponseDTO;
import com.hango.hango_backend.dto.ExamResultAnalysisDTO;
import com.hango.hango_backend.entity.Course;
import com.hango.hango_backend.entity.ExamAttempt;
import com.hango.hango_backend.dto.ExamCourseRecommendationAIResponseDTO.RecommendedCourseDTO;
import com.hango.hango_backend.repository.CourseRepository;
import com.hango.hango_backend.repository.ExamAttemptRepository;
import com.hango.hango_backend.repository.SystemParameterRepository;
import com.hango.hango_backend.service.ExamResultAnalyzerService;
import com.hango.hango_backend.service.GeminiClientService;
import com.hango.hango_backend.service.SkillCategoryMappingService;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import com.hango.hango_backend.dto.GeminiGenerateRequest;
import com.hango.hango_backend.exception.ApiException;

import java.util.Collections;
import java.util.List;
import java.util.Map;

@Service
@Slf4j
@RequiredArgsConstructor
public class ExamCourseRecommendationAIService {

    private final ExamAttemptRepository examAttemptRepository;
    private final CourseRepository courseRepository;
    private final ExamResultAnalyzerService examResultAnalyzerService;
    private final GeminiClientService geminiClientService;
    private final ObjectMapper objectMapper;
    private final SkillCategoryMappingService skillCategoryMappingService;

    /**
     * Gợi ý khóa học bằng AI dựa trên examAttempt.answersJson/score.
     * Fallback: nếu AI fail => trả weaknessSummary rỗng + list rỗng để FE quay về rule-based.
     */
    public ExamCourseRecommendationAIResponseDTO recommendCoursesAI(Long examAttemptId, String weakestSkill) {
        if (examAttemptId == null) {
            throw new ApiException("examAttemptId is required", HttpStatus.BAD_REQUEST);
        }

        ExamAttempt attempt = examAttemptRepository.findById(examAttemptId)
                .orElseThrow(() -> new ApiException("ExamAttempt not found", HttpStatus.NOT_FOUND));

        // Phân tích CHỈ dựa trên examAttemptId hiện tại (không dùng các bài exam khác).
        // Lý do: tránh việc UI/AI suy luận sai do tổng hợp nhiều exam.
        ExamResultAnalysisDTO analysis = examResultAnalyzerService.analyzeLatestExamAttempt(attempt);


        // Lấy danh sách course hiện có (để AI chỉ chọn đúng course_id).
        List<Course> allCourses = courseRepository.findAll().stream()
                .filter(c -> c.getDeletedAt() == null)
                .toList();

        String mappedCategory = skillCategoryMappingService.getCategoryForSkill(weakestSkill);
        String categoryHint = "";
        if (mappedCategory != null) {
            categoryHint = " (This skill belongs to the " + mappedCategory + " category. Prioritize courses from this category).";
        }

        StringBuilder courseList = new StringBuilder();
        for (Course c : allCourses) {
            courseList.append("- ID: ").append(c.getId())
                    .append(", Title: ").append(c.getTitle())
                    .append(", Category: ").append(c.getCategory() != null ? c.getCategory().getParamValue() : "N/A")
                    .append(", Difficulty: ").append(c.getDifficulty() != null ? c.getDifficulty().getParamValue() : "N/A")
                    .append("\n");
        }

        String systemPrompt = """
                You are a “Duolingo-style study buddy”. Speak friendly English, nói bằng tiếng Anh.

                Hãy nói chuyện thân thiện, dễ gần, tích cực; không phán xét.

                Nhiệm vụ của bạn:
                1) Viết `weaknessSummary` ngắn gọn, ấm áp như nhắn với bạn học.
                   - Nếu điểm `score_avg_hint` cao (>= 9) hoặc knowledge_gaps_json cho thấy ít lỗi, hãy nói rằng bạn đang làm rất tốt và chỉ gợi ý “review nhẹ” (không khẳng định yếu nhiều).
                   - Nếu điểm thấp hơn thì mô tả rõ điểm yếu dựa trên TOOL INPUT.

                2) Đề xuất đúng 3 khóa học phù hợp nhất và kèm `reasonWhy` thân thiện, dễ hiểu (vì sao khóa này giúp bạn tiến bộ nhanh).

                Ràng buộc bắt buộc:
                - Chỉ được chọn courseId tồn tại trong [AVAILABLE_COURSES]. Tuyệt đối không bịa courseId.
                - Chỉ trả về JSON thuần (không markdown), schema đúng như dưới.

                [AVAILABLE_COURSES]
                %s

                TOOL INPUT (EXAM ANALYSIS):
                - score_avg_hint: %s
                - knowledge_gaps_json: %s
                - explicit_weakest_skill: %s%s

                JSON OUTPUT SCHEMA:
                {
                  "weaknessSummary": "...",
                  "recommendedCourses": [
                    {"courseId": 1, "reasonWhy": "..."},
                    {"courseId": 2, "reasonWhy": "..."},
                    {"courseId": 3, "reasonWhy": "..."}
                  ]
                }
                """.formatted(

                courseList,
                courseList,
                analysis.getHints() != null && analysis.getHints().get("score_avg") != null ? analysis.getHints().get("score_avg").toString() : "0",
                analysis.getKnowledgeGapsJson() == null ? "{}" : analysis.getKnowledgeGapsJson(),
                weakestSkill != null ? weakestSkill : "N/A",
                categoryHint
        );


        List<GeminiGenerateRequest.Content> chatHistory = List.of(
                GeminiGenerateRequest.Content.builder()
                        .role("user")
                        .parts(List.of(GeminiGenerateRequest.Part.builder().text("Tôi cần đề xuất khóa học sau exam. Hãy trả đúng JSON schema.").build()))
                        .build()
        );

        try {
            String aiResponseText = geminiClientService.generateChatResponse(systemPrompt, chatHistory);
            aiResponseText = aiResponseText.replaceAll("(?s)^```json\\s*", "")
                    .replaceAll("(?s)```\\s*$", "")
                    .trim();

            // Parse response: weaknessSummary + recommendedCourses[].
            @SuppressWarnings("unchecked")
            Map<String, Object> parsed = objectMapper.readValue(aiResponseText, Map.class);

            String weaknessSummary = parsed.get("weaknessSummary") != null ? parsed.get("weaknessSummary").toString() : "";
            List<Map<String, Object>> recs = (List<Map<String, Object>>) parsed.get("recommendedCourses");

            if (recs == null) recs = Collections.emptyList();

            // Map course info back to include title/category/difficulty.
            return ExamCourseRecommendationAIResponseDTO.builder()
                    .examAttemptId(examAttemptId)
                    .weaknessSummary(weaknessSummary)
                    .recommendedCourses(recs.stream().limit(3).map(r -> {
                        Long cid = r.get("courseId") instanceof Number ? ((Number) r.get("courseId")).longValue() : Long.parseLong(String.valueOf(r.get("courseId")));
                        Course course = allCourses.stream().filter(c -> c.getId().equals(cid)).findFirst().orElse(null);

                        String reasonWhy = r.get("reasonWhy") != null ? r.get("reasonWhy").toString() : "";

                        return RecommendedCourseDTO.builder()
                                .courseId(cid)
                                .title(course != null ? course.getTitle() : "")
                                .category(course != null && course.getCategory() != null ? course.getCategory().getParamValue() : "")
                                .difficulty(course != null && course.getDifficulty() != null ? course.getDifficulty().getParamValue() : "")
                                .reasonWhy(reasonWhy)
                                .thumbnailUrl(course != null ? course.getThumbnailUrl() : null)
                                .build();
                    }).toList())
                    .build();
        } catch (Exception e) {
            log.warn("AI recommend failed, fallback empty. cause={}", e.getMessage());
            return ExamCourseRecommendationAIResponseDTO.builder()
                    .examAttemptId(examAttemptId)
                    .weaknessSummary("")
                    .recommendedCourses(Collections.emptyList())
                    .build();
        }
    }
}

