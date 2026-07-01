package com.hango.hango_backend.dto;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.math.BigDecimal;
import java.util.Map;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class ExamAttemptResponseDTO {
    private Long id;
    private Long examId;
    private BigDecimal score;
    private Integer attemptNumber;
    private String date;
    private String status;
    private Map<String, Integer> answers;
}
