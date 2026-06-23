package com.hango.hango_backend.service;

import com.hango.hango_backend.dto.TrainerDashboardSummaryDTO;
import com.hango.hango_backend.dto.TrainerCoursesResponseDTO;

public interface TrainerDashboardService {
    TrainerDashboardSummaryDTO getTrainerDashboardSummary(String email);
    TrainerCoursesResponseDTO getTrainerCourses(String email, String status, String search, String sortBy, String timePeriod);
}
