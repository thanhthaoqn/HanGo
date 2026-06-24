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
public class LessonQuizAttemptDTO {
    private Integer attemptNumber;
    private String state;
    private String grade;
    private String submittedTime;
    private Map<String, Integer> answers;
}
