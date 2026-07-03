package com.hango.hango_backend.service;

import com.hango.hango_backend.dto.ExamResultAnalysisDTO;
import com.hango.hango_backend.dto.UserAnswerDTO;
import com.hango.hango_backend.entity.ExamAttempt;
import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.ObjectMapper;

import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;

import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Objects;
import java.util.Set;
import java.util.stream.Collectors;


/**
 * Tool dùng cho AI Interactive Learning Pathway.
 *
 * Mục tiêu: cung cấp “đầu vào phân tích” (không phải prompt free-form) từ kết quả bài thi
 * để AI Agent/roadmap không bỏ qua dữ liệu.
 */
@Service
@Slf4j
@RequiredArgsConstructor
public class ExamResultAnalyzerService {

    private final ObjectMapper objectMapper;

    public ExamResultAnalysisDTO analyzeLatestExamAttempt(ExamAttempt examAttempt) {

        // Hiện tại repository đang lưu answersJson (string JSON). Chúng ta chưa có schema DTO parse sẵn,
        // nên tạm thời trả về raw + một vài trường suy ra (score/weaknesses nếu parse được).
        // Bước tiếp theo sẽ mở rộng: parse schema thật và trả về “lỗ hổng kiến thức” chuẩn.

        Map<String, Object> hints = new HashMap<>();

        String answersJson = examAttempt.getAnswersJson();
        hints.put("answersJson", answersJson);

        if (examAttempt.getScore() != null) {
            // examAttempt.getScore() có thể là BigDecimal, convert sang Integer cho DTO layer
            hints.put("score", examAttempt.getScore().intValue());
        }

        // weakness/difficulty sẽ được chuẩn hóa sau khi có DTO parse đúng schema.
        return ExamResultAnalysisDTO.builder()
                .examAttemptId(examAttempt.getId())
                .score(examAttempt.getScore() != null ? examAttempt.getScore().intValue() : null)
                .rawAnswersJson(answersJson)
                .knowledgeGapsJson(extractKnowledgeGapsPlaceholder(answersJson))
                .hints(hints)
                .build();
    }

    private String extractKnowledgeGapsPlaceholder(String answersJson) {
        // Parse answersJson -> thống kê câu sai theo topic/skill.
        // Sau đó serialize thành JSON ngắn để đưa vào prompt.
        if (answersJson == null || answersJson.isBlank()) {
            return "{}";
        }

        try {
            // Giả định answersJson có dạng mảng JSON các object trả lời.
            List<UserAnswerDTO> answers = objectMapper.readValue(
                    answersJson,
                    objectMapper.getTypeFactory().constructCollectionType(List.class, UserAnswerDTO.class)
            );

            List<UserAnswerDTO> incorrectAnswers = answers.stream()
                    .filter(a -> Boolean.FALSE.equals(a.getIsCorrect()))
                    .toList();

            int incorrectCount = incorrectAnswers.size();

            // Gom nhóm topic bị làm sai nhiều nhất.
            Map<String, Long> incorrectByTopic = incorrectAnswers.stream()
                    .filter(a -> a.getTopic() != null && !a.getTopic().isBlank())
                    .collect(Collectors.groupingBy(
                            a -> a.getTopic().trim(),
                            Collectors.counting()
                    ));

            // Lấy top topic theo số lần sai (giới hạn để tiết kiệm token).
            List<String> criticalTopics = incorrectByTopic.entrySet().stream()
                    .sorted((e1, e2) -> Long.compare(e2.getValue(), e1.getValue()))
                    .limit(5)
                    .map(e -> e.getKey())
                    .toList();

            // Weak skills: các skill có câu trả lời sai, lấy distinct.
            // Nếu skill trống thì bỏ.
            Set<String> weakSkills = incorrectAnswers.stream()
                    .map(UserAnswerDTO::getSkill)
                    .filter(Objects::nonNull)
                    .map(String::trim)
                    .filter(s -> !s.isBlank())
                    .collect(Collectors.toSet());

            Map<String, Object> summary = new HashMap<>();
            summary.put("weak_skills", weakSkills.stream().sorted().toList());
            summary.put("critical_topics", criticalTopics);
            summary.put("incorrect_count", incorrectCount);

            return objectMapper.writeValueAsString(summary);
        } catch (JsonProcessingException e) {
            // Nếu parse fail (schema JSON thực tế khác giả định), fallback về raw JSON để không làm đứt flow.
            log.warn("Failed to parse answersJson for knowledge gaps. Using raw fallback. error={}", e.getMessage());
            return answersJson;
        } catch (Exception e) {
            log.warn("Unexpected error while extracting knowledge gaps. Using raw fallback. error={}", e.getMessage());
            return answersJson;
        }
    }

}

