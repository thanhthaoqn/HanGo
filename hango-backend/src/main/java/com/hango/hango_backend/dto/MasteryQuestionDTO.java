package com.hango.hango_backend.dto;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.util.List;

/**
 * Cau hoi Mastery Quiz tra ve cho FE - KHONG chua correctIndex/explanation
 * de tranh ro dap an. Cham diem dien ra hoan toan phia server.
 */
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class MasteryQuestionDTO {
    private Long questionId;
    private String passage;
    private String questionText;
    private List<String> options;
    private Boolean isMultipleChoice;
}
