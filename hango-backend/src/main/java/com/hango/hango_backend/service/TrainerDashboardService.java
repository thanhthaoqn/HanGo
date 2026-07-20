package com.hango.hango_backend.service;

import com.hango.hango_backend.dto.TrainerDashboardSummaryDTO;
import com.hango.hango_backend.dto.TrainerCoursesResponseDTO;
import java.util.List;
import com.hango.hango_backend.entity.SystemParameter;

public interface TrainerDashboardService {
    TrainerDashboardSummaryDTO getTrainerDashboardSummary(String email);
    TrainerCoursesResponseDTO getTrainerCourses(String email, String status, String search, String sortBy, String timePeriod);
    void createTrainerCourse(String email, com.hango.hango_backend.dto.TrainerCreateCourseRequestDTO request);
    List<SystemParameter> getSystemParametersByType(String paramType);
    void updateTrainerCourse(Long id, String email, com.hango.hango_backend.dto.TrainerCreateCourseRequestDTO request);
    void submitTrainerCourse(Long id, String email);
    List<com.hango.hango_backend.dto.TrainerExamResponseDTO> getTrainerExams(String email);
    void createTrainerExam(String email, com.hango.hango_backend.dto.TrainerCreateExamRequestDTO request);

    void saveExamQuestions(Long examId, String email, com.hango.hango_backend.dto.TrainerSaveExamQuestionsRequestDTO request);
    
    com.hango.hango_backend.dto.TrainerSaveExamQuestionsRequestDTO getExamQuestions(Long examId, String email);
    
    void updateExamStatus(Long examId, String email, String status);
    
    void updateExamVisibility(Long examId, String email, String visibility);
    
    void deleteTrainerExam(Long examId, String email);
    void deleteTrainerCourse(Long id, String email);
    void publishTrainerCourse(Long id, String email);
}
