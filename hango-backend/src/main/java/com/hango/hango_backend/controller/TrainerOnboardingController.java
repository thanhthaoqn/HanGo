package com.hango.hango_backend.controller;

import com.hango.hango_backend.dto.LoginResponse;
import com.hango.hango_backend.dto.TrainerProfileDTO;
import com.hango.hango_backend.dto.TrainerReviewRequest;
import com.hango.hango_backend.service.TrainerOnboardingService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@CrossOrigin(origins = "*", maxAge = 3600)
@RestController
@RequestMapping("/api/v1")
@RequiredArgsConstructor
public class TrainerOnboardingController {

    private final TrainerOnboardingService trainerOnboardingService;

    @PostMapping("/trainers/become-trainer")
    @PreAuthorize("isAuthenticated()")
    public ResponseEntity<?> becomeTrainer(
            @AuthenticationPrincipal UserDetails userDetails,
            @RequestParam(defaultValue = "PROFESSIONAL") String trainerType) {
        try {
            if (userDetails == null) {
                return ResponseEntity.status(401).body("{\"error\": \"Unauthorized\"}");
            }
            LoginResponse response = trainerOnboardingService.becomeTrainer(userDetails.getUsername(), trainerType);
            return ResponseEntity.ok(response);
        } catch (Exception e) {
            e.printStackTrace();
            return ResponseEntity.badRequest().body("{\"error\": \"" + e.getMessage() + "\"}");
        }
    }

    @GetMapping("/trainers/profile")
    @PreAuthorize("hasAnyRole('TRAINER', 'ADMINISTRATOR', 'COURSE_MANAGER')")
    public ResponseEntity<?> getTrainerProfile(@AuthenticationPrincipal UserDetails userDetails) {
        try {
            if (userDetails == null) {
                return ResponseEntity.status(401).body("{\"error\": \"Unauthorized\"}");
            }
            TrainerProfileDTO profile = trainerOnboardingService.getTrainerProfile(userDetails.getUsername());
            return ResponseEntity.ok(profile);
        } catch (Exception e) {
            e.printStackTrace();
            return ResponseEntity.badRequest().body("{\"error\": \"" + e.getMessage() + "\"}");
        }
    }

    @PutMapping("/trainers/profile")
    @PreAuthorize("hasAnyRole('TRAINER', 'ADMINISTRATOR', 'COURSE_MANAGER')")
    public ResponseEntity<?> saveProfileDraft(
            @AuthenticationPrincipal UserDetails userDetails,
            @RequestBody TrainerProfileDTO request) {
        try {
            if (userDetails == null) {
                return ResponseEntity.status(401).body("{\"error\": \"Unauthorized\"}");
            }
            TrainerProfileDTO profile = trainerOnboardingService.saveProfileDraft(userDetails.getUsername(), request);
            return ResponseEntity.ok(profile);
        } catch (Exception e) {
            e.printStackTrace();
            return ResponseEntity.badRequest().body("{\"error\": \"" + e.getMessage() + "\"}");
        }
    }

    @PostMapping("/trainers/profile/submit")
    @PreAuthorize("hasAnyRole('TRAINER', 'ADMINISTRATOR', 'COURSE_MANAGER')")
    public ResponseEntity<?> submitProfile(
            @AuthenticationPrincipal UserDetails userDetails,
            @RequestBody TrainerProfileDTO request) {
        try {
            if (userDetails == null) {
                return ResponseEntity.status(401).body("{\"error\": \"Unauthorized\"}");
            }
            TrainerProfileDTO profile = trainerOnboardingService.submitProfileForReview(userDetails.getUsername(), request);
            return ResponseEntity.ok(profile);
        } catch (Exception e) {
            e.printStackTrace();
            return ResponseEntity.badRequest().body("{\"error\": \"" + e.getMessage() + "\"}");
        }
    }

    @GetMapping("/admin/trainer-profiles")
    @PreAuthorize("hasRole('ADMINISTRATOR')")
    public ResponseEntity<?> getTrainerProfilesForAdmin(
            @RequestParam(required = false) String search,
            @RequestParam(defaultValue = "ALL") String status) {
        try {
            List<TrainerProfileDTO> list = trainerOnboardingService.getTrainerProfilesForAdmin(search, status);
            return ResponseEntity.ok(list);
        } catch (Exception e) {
            e.printStackTrace();
            return ResponseEntity.badRequest().body("{\"error\": \"" + e.getMessage() + "\"}");
        }
    }

    @PutMapping("/admin/trainer-profiles/{id}/review")
    @PreAuthorize("hasRole('ADMINISTRATOR')")
    public ResponseEntity<?> reviewTrainerProfile(
            @PathVariable Long id,
            @RequestBody TrainerReviewRequest request) {
        try {
            TrainerProfileDTO profile = trainerOnboardingService.reviewTrainerProfile(id, request);
            return ResponseEntity.ok(profile);
        } catch (Exception e) {
            e.printStackTrace();
            return ResponseEntity.badRequest().body("{\"error\": \"" + e.getMessage() + "\"}");
        }
    }
}
