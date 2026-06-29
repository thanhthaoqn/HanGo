package com.hango.hango_backend.service;

import com.hango.hango_backend.dto.QuestionDTO;
import java.util.List;

public interface TrainerQuestionService {
    List<QuestionDTO> getTrainerQuestions(String email, String type, String search, String sortBy);
}
