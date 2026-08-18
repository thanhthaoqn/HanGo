package com.hango.hango_backend.dto;

import com.fasterxml.jackson.annotation.JsonAlias;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import com.fasterxml.jackson.annotation.JsonIgnoreProperties;

/**
 * DTO đại diện cho từng câu trả lời trong answersJson của ExamAttempt.
 *
 * Mục đích: parse cấu trúc dữ liệu thô để thống kê gọn gàng trước khi đưa vào prompt AI.
 */
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
@JsonIgnoreProperties(ignoreUnknown = true)
public class UserAnswerDTO {

    private Long questionId;
    private String topic;
    @JsonAlias("skillType")
    private String skill;
    private Boolean isCorrect;
    private String userAnswer;
}

