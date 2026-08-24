package com.hango.hango_backend.service;

import com.hango.hango_backend.dto.LoginResponse;
import com.hango.hango_backend.dto.TrainerProfileDTO;
import com.hango.hango_backend.dto.TrainerReviewRequest;
import java.util.List;

public interface TrainerOnboardingService {
    LoginResponse becomeTrainer(String email, String trainerType);
    TrainerProfileDTO getTrainerProfile(String email);
    TrainerProfileDTO saveProfileDraft(String email, TrainerProfileDTO dto);
    TrainerProfileDTO submitProfileForReview(String email, TrainerProfileDTO dto);
    TrainerProfileDTO submitCredentialUpdate(String email, TrainerProfileDTO dto);
    List<TrainerProfileDTO> getTrainerProfilesForAdmin(String search, String status);
    TrainerProfileDTO reviewTrainerProfile(Long userId, TrainerReviewRequest request);
}
