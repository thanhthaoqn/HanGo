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
public class CreateTrainerQuestionAIRequestDTO {
    /**
     * MODE cho AI generate
     * SINGLE: câu đơn (4 options/câu), 1 đáp án đúng
     * MULTIPLE: group question (>=2 subQuestions/group), mỗi subQuestion 4 options, 1 đáp án đúng
     */
    private String mode;

    /**
     * sectionId nơi tạo question.
     * (vẫn trả về payload cho FE trong bước UI-populate; sectionId dùng cho prompt scope & category/difficulty default)
     */
    private Long sectionId;

    /**
     * topic/seed do trainer cung cấp
     */
    private String topicSeed;

    /**
     * quantity cho SINGLE: số câu
     * quantity cho MULTIPLE: số subQuestions (tối thiểu 2)
     */
    private Integer quantity;

    /**
     * default category/difficulty nếu null => backend fallback
     */
    private Long categoryId;
    private Long difficultyId;
}

