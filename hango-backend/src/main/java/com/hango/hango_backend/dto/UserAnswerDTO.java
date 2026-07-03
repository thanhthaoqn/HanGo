package com.hango.hango_backend.dto;

import lombok.Builder;
import lombok.Data;

/**
 * DTO đại diện cho từng câu trả lời trong answersJson của ExamAttempt.
 *
 * Mục đích: parse cấu trúc dữ liệu thô để thống kê gọn gàng trước khi đưa vào prompt AI.
 */
@Data
@Builder
public class UserAnswerDTO {

    private Long questionId;
    private String topic;
    private String skill;
    private Boolean isCorrect;
    private String userAnswer;
}

