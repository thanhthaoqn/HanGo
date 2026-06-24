package com.hango.hango_backend.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;
import lombok.Data;

@Data
public class SendMessageRequest {

    /** Nếu null -> tạo conversation mới gắn với lessonId. Nếu có -> tiếp tục conversation cũ. */
    private Long conversationId;

    @NotNull(message = "Cần chỉ định bài học để AI biết phạm vi hỗ trợ")
    private Long lessonId;

    @NotBlank
    @Size(max = 500, message = "Câu hỏi không được vượt quá 500 ký tự")
    private String message;
}