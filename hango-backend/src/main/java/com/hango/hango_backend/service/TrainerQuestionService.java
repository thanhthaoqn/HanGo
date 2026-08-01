package com.hango.hango_backend.service;

import com.hango.hango_backend.dto.QuestionDTO;
import java.util.List;

public interface TrainerQuestionService {
    List<QuestionDTO> getTrainerQuestions(String email, String type, String search, String sortBy, Long skillId, Long categoryId, Long difficultyId);
    java.util.Map<String, Object> createQuestionBankGroup(String email, com.hango.hango_backend.dto.CreateGroupQuestionRequestDTO request);
    com.hango.hango_backend.dto.CreateGroupQuestionRequestDTO getQuestionDetail(String email, Long id, boolean isGroup);
    void updateQuestionBankGroup(String email, Long id, boolean isGroup, com.hango.hango_backend.dto.CreateGroupQuestionRequestDTO request);
    void updateQuestionStatus(String email, Long questionId, String status, boolean isGroup);
}
