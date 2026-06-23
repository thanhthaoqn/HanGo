package com.hango.hango_backend.service;

import com.hango.hango_backend.dto.TrainerDashboardSummaryDTO;

public interface TrainerDashboardService {
    TrainerDashboardSummaryDTO getTrainerDashboardSummary(String email);
}
