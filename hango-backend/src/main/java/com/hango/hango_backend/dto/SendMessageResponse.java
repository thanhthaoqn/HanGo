package com.hango.hango_backend.dto;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class SendMessageResponse {

    private Long conversationId;
    private String reply;

    /** true nếu câu hỏi của learner bị guardrail xác định là ngoài phạm vi bài học. */
    private boolean wasOutOfScope;

    /** 3 câu hỏi gợi ý để learner có thể bấm hỏi luôn (theo ngữ cảnh bài học). */
    private java.util.List<String> suggestedQuestions;
}

