package com.hango.hango_backend.service;

import com.hango.hango_backend.dto.ExamResultAnalysisDTO;
import com.hango.hango_backend.entity.ExamAttempt;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;

import java.util.HashMap;
import java.util.Map;

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
        // Placeholder: hiện tại chỉ trả về chính raw JSON.
        // Sau khi có schema weakness/skills, thay bằng output chuẩn.
        return answersJson;
    }
}

