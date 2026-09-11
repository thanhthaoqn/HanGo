package com.hango.hango_backend.dto;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.util.List;

/**
 * Result of checking whether the Question Bank has enough questions to
 * satisfy every row of an Exam Matrix, using the same per-row filters
 * (skill/difficulty/group type/question source) that exam generation itself
 * uses - so "sufficient" here matches what generation would actually find.
 */
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class ExamMatrixSufficiencyDTO {
    private boolean sufficient;
    private List<Shortfall> shortfalls;

    @Data
    @Builder
    @NoArgsConstructor
    @AllArgsConstructor
    public static class Shortfall {
        private Long detailId;
        private String skillName;
        private String difficultyName;
        private String groupTypeName;
        private int required;
        private long available;
    }
}
