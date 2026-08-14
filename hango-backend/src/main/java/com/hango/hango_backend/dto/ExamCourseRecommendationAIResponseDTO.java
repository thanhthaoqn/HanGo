package com.hango.hango_backend.dto;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.util.List;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class ExamCourseRecommendationAIResponseDTO {

    private Long examAttemptId;

    /** AI phân tích học viên đang yếu ở đâu (tiếng Việt). */
    private String weaknessSummary;

    /** Danh sách khóa học AI gợi ý. */
    private List<RecommendedCourseDTO> recommendedCourses;

    @Data
    @Builder
    @NoArgsConstructor
    @AllArgsConstructor
    public static class RecommendedCourseDTO {
        private Long courseId;
        private String title;
        private String category;
        private String difficulty;
        private String reasonWhy;
        private String thumbnailUrl;
    }
}

