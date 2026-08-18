package com.hango.hango_backend.dto;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.util.Map;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class ExamResultAnalysisDTO {

    private Long examAttemptId;

    private Double score;

    /** JSON thô từ examAttempt.answersJson. */
    private String rawAnswersJson;

    /**
     * JSON/chuỗi mô tả “knowledge gaps” ở dạng dự kiến.
     * Placeholder hiện tại: sẽ thay bằng schema chuẩn theo doc feature.
     */
    private String knowledgeGapsJson;

    /** Các hints thêm (ví dụ score) cho AI agent. */
    private Map<String, Object> hints;
}

