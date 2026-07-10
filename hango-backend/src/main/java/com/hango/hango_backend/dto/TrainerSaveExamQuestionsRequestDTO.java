package com.hango.hango_backend.dto;

import lombok.Data;
import java.util.List;

@Data
public class TrainerSaveExamQuestionsRequestDTO {
    private List<CreateGroupQuestionRequestDTO> blocks;
}
