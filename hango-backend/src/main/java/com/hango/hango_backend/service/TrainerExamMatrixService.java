package com.hango.hango_backend.service;

import com.hango.hango_backend.dto.ExamMatrixDTO;
import com.hango.hango_backend.dto.ExamMatrixCreateRequestDTO;

import java.util.List;

public interface TrainerExamMatrixService {
    List<ExamMatrixDTO> getAllExamMatrices();
    void createExamMatrix(String email, ExamMatrixCreateRequestDTO request);
    Long generateExamFromMatrix(Long matrixId, String examTitle, String email);
}
