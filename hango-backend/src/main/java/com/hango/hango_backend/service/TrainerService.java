package com.hango.hango_backend.service;

import com.hango.hango_backend.dto.TrainerDashboardDTO;
import org.springframework.data.domain.Pageable;

public interface TrainerService {
    TrainerDashboardDTO getTrainerDashboard(String trainerEmail, Pageable pageable);
}
