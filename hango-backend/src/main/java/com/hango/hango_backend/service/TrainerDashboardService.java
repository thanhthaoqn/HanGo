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
}
