package com.hango.hango_backend.service;

import com.hango.hango_backend.dto.ExamMatrixDTO;
import com.hango.hango_backend.dto.ExamMatrixCreateRequestDTO;

import java.util.List;

public interface ExamMatrixService {
    List<ExamMatrixDTO> getAllExamMatrices();
    List<ExamMatrixDTO> getAllMatricesForManager();
    void createExamMatrix(String email, ExamMatrixCreateRequestDTO request);
    void updateExamMatrix(Long id, ExamMatrixCreateRequestDTO request);
    void toggleMatrixStatus(Long id);
    Long generateExamFromMatrix(Long matrixId, String examTitle, String description, Integer expectedQuestionCount, Double passingScore, Integer durationMinutes, Integer questionSourceType, String email);
}
