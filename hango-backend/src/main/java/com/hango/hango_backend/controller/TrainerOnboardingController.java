package com.hango.hango_backend.controller;

import com.hango.hango_backend.dto.LoginResponse;
import com.hango.hango_backend.dto.TrainerProfileDTO;
import com.hango.hango_backend.dto.TrainerReviewRequest;
import com.hango.hango_backend.exception.ApiException;
import com.hango.hango_backend.service.CloudinaryService;
import com.hango.hango_backend.service.TrainerOnboardingService;
import jakarta.validation.Valid;
import lombok.extern.slf4j.Slf4j;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.security.core.userdetails.UsernameNotFoundException;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.multipart.MultipartFile;

import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

@RestController
@RequestMapping("/api/v1")
@RequiredArgsConstructor
@Slf4j
public class TrainerOnboardingController {
    private final TrainerOnboardingService trainerOnboardingService;
    private final CloudinaryService cloudinaryService;

    @PostMapping("/trainers/become-trainer")
    @PreAuthorize("hasAnyRole('LEARNER', 'TRAINER')")
    public ResponseEntity<?> becomeTrainer(
            @AuthenticationPrincipal UserDetails userDetails,
            @RequestParam(defaultValue = "PROFESSIONAL") String trainerType) {
        try {
            if (userDetails == null) {
                return errorResponse(HttpStatus.UNAUTHORIZED, "Unauthorized");
            }
            LoginResponse response = trainerOnboardingService.becomeTrainer(userDetails.getUsername(), trainerType);
            return ResponseEntity.ok(response);
        } catch (ApiException e) {
            return errorResponse(e.getStatus(), e.getMessage());
        } catch (UsernameNotFoundException e) {
            return errorResponse(HttpStatus.NOT_FOUND, e.getMessage());
        } catch (Exception e) {
            log.error("Unexpected error while upgrading user {} to trainer", userDetails != null ? userDetails.getUsername() : "unknown", e);
            return errorResponse(HttpStatus.INTERNAL_SERVER_ERROR, "An internal system error occurred. Please try again later.");
        }
    }

    @GetMapping("/trainers/profile")
    @PreAuthorize("hasAnyRole('LEARNER', 'TRAINER')")
    public ResponseEntity<?> getTrainerProfile(@AuthenticationPrincipal UserDetails userDetails) {
        try {
            if (userDetails == null) {
                return errorResponse(HttpStatus.UNAUTHORIZED, "Unauthorized");
            }
            TrainerProfileDTO profile = trainerOnboardingService.getTrainerProfile(userDetails.getUsername());
            return ResponseEntity.ok(profile);
        } catch (ApiException e) {
            return errorResponse(e.getStatus(), e.getMessage());
        } catch (UsernameNotFoundException e) {
            return errorResponse(HttpStatus.NOT_FOUND, e.getMessage());
        } catch (Exception e) {
            log.error("Unexpected error while loading trainer profile for {}", userDetails != null ? userDetails.getUsername() : "unknown", e);
            return errorResponse(HttpStatus.INTERNAL_SERVER_ERROR, "An internal system error occurred. Please try again later.");
        }
    }

    @PutMapping("/trainers/profile")
    @PreAuthorize("hasAnyRole('LEARNER', 'TRAINER')")
    public ResponseEntity<?> saveProfileDraft(
            @AuthenticationPrincipal UserDetails userDetails,
            @Valid @RequestBody TrainerProfileDTO request) {
        try {
            if (userDetails == null) {
                return errorResponse(HttpStatus.UNAUTHORIZED, "Unauthorized");
            }
            TrainerProfileDTO profile = trainerOnboardingService.saveProfileDraft(userDetails.getUsername(), request);
            return ResponseEntity.ok(profile);
        } catch (ApiException e) {
            return errorResponse(e.getStatus(), e.getMessage());
        } catch (UsernameNotFoundException e) {
            return errorResponse(HttpStatus.NOT_FOUND, e.getMessage());
        } catch (Exception e) {
            log.error("Unexpected error while saving trainer draft for {}", userDetails != null ? userDetails.getUsername() : "unknown", e);
            return errorResponse(HttpStatus.INTERNAL_SERVER_ERROR, "An internal system error occurred. Please try again later.");
        }
    }

    @PostMapping("/trainers/profile/submit")
    @PreAuthorize("hasAnyRole('LEARNER', 'TRAINER')")
    public ResponseEntity<?> submitProfile(
            @AuthenticationPrincipal UserDetails userDetails,
            @Valid @RequestBody TrainerProfileDTO request) {
        try {
            if (userDetails == null) {
                return errorResponse(HttpStatus.UNAUTHORIZED, "Unauthorized");
            }
            TrainerProfileDTO profile = trainerOnboardingService.submitProfileForReview(userDetails.getUsername(), request);
            return ResponseEntity.ok(profile);
        } catch (ApiException e) {
            return errorResponse(e.getStatus(), e.getMessage());
        } catch (UsernameNotFoundException e) {
            return errorResponse(HttpStatus.NOT_FOUND, e.getMessage());
        } catch (Exception e) {
            log.error("Unexpected error while submitting trainer profile for {}", userDetails != null ? userDetails.getUsername() : "unknown", e);
            return errorResponse(HttpStatus.INTERNAL_SERVER_ERROR, "An internal system error occurred. Please try again later.");
        }
    }

    @PostMapping("/trainers/profile/credentials/submit")
    @PreAuthorize("hasRole('TRAINER')")
    public ResponseEntity<?> submitCredentialUpdate(
            @AuthenticationPrincipal UserDetails userDetails,
            @Valid @RequestBody TrainerProfileDTO request) {
        try {
            if (userDetails == null) {
                return errorResponse(HttpStatus.UNAUTHORIZED, "Unauthorized");
            }
            return ResponseEntity.ok(
                    trainerOnboardingService.submitCredentialUpdate(userDetails.getUsername(), request));
        } catch (ApiException e) {
            return errorResponse(e.getStatus(), e.getMessage());
        } catch (Exception e) {
            log.error("Unexpected error while submitting trainer credential update", e);
            return errorResponse(HttpStatus.INTERNAL_SERVER_ERROR,
                    "An internal system error occurred. Please try again later.");
        }
    }

    @PostMapping("/trainers/documents/upload")
    @PreAuthorize("hasAnyRole('LEARNER', 'TRAINER')")
    public ResponseEntity<?> uploadTrainerDocument(@RequestParam("file") MultipartFile file) {
        try {
            String url = cloudinaryService.uploadTrainerDocument(file);
            return ResponseEntity.ok(Map.of("url", url));
        } catch (ApiException e) {
            return errorResponse(e.getStatus(), e.getMessage());
        } catch (Exception e) {
            log.error("Unexpected error while uploading trainer document", e);
            return errorResponse(HttpStatus.INTERNAL_SERVER_ERROR,
                    "The document could not be uploaded. Please try again later.");
        }
    }

    @PostMapping("/trainers/avatar/upload")
    @PreAuthorize("hasAnyRole('LEARNER', 'TRAINER')")
    public ResponseEntity<?> uploadTrainerAvatar(@RequestParam("file") MultipartFile file) {
        try {
            return ResponseEntity.ok(Map.of("url", cloudinaryService.uploadTrainerAvatar(file)));
        } catch (ApiException e) {
            return errorResponse(e.getStatus(), e.getMessage());
        } catch (Exception e) {
            log.error("Unexpected error while uploading trainer avatar", e);
            return errorResponse(HttpStatus.INTERNAL_SERVER_ERROR,
                    "The avatar could not be uploaded. Please try again later.");
        }
    }

    @GetMapping("/admin/trainer-profiles")
    @PreAuthorize("hasAuthority('MANAGE_ACCOUNTS_ROLES') or hasRole('ADMINISTRATOR')")
    public ResponseEntity<?> getTrainerProfilesForAdmin(
            @RequestParam(required = false) String search,
            @RequestParam(defaultValue = "ALL") String status) {
        try {
            List<TrainerProfileDTO> list = trainerOnboardingService.getTrainerProfilesForAdmin(search, status);
            return ResponseEntity.ok(list);
        } catch (ApiException e) {
            return errorResponse(e.getStatus(), e.getMessage());
        } catch (Exception e) {
            log.error("Unexpected error while loading trainer review queue", e);
            return errorResponse(HttpStatus.INTERNAL_SERVER_ERROR, "An internal system error occurred. Please try again later.");
        }
    }

    @PutMapping("/admin/trainer-profiles/{id}/review")
    @PreAuthorize("hasAuthority('MANAGE_ACCOUNTS_ROLES') or hasRole('ADMINISTRATOR')")
    public ResponseEntity<?> reviewTrainerProfile(
            @PathVariable Long id,
            @Valid @RequestBody TrainerReviewRequest request) {
        try {
            TrainerProfileDTO profile = trainerOnboardingService.reviewTrainerProfile(id, request);
            return ResponseEntity.ok(profile);
        } catch (ApiException e) {
            return errorResponse(e.getStatus(), e.getMessage());
        } catch (Exception e) {
            log.error("Unexpected error while reviewing trainer profile {}", id, e);
            return errorResponse(HttpStatus.INTERNAL_SERVER_ERROR, "An internal system error occurred. Please try again later.");
        }
    }

    private ResponseEntity<Map<String, String>> errorResponse(HttpStatus status, String message) {
        Map<String, String> payload = new LinkedHashMap<>();
        payload.put("error", message);
        return ResponseEntity.status(status).body(payload);
    }
}
