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
    @PreAuthorize("isAuthenticated()")
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
    @PreAuthorize("isAuthenticated()")
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
    @PreAuthorize("isAuthenticated()")
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
    @PreAuthorize("hasAuthority('MANAGE_ACCOUNTS_ROLES') or hasRole('ADMINISTRATOR')")
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
    @PreAuthorize("hasAuthority('MANAGE_ACCOUNTS_ROLES') or hasRole('ADMINISTRATOR')")
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

    private final com.hango.hango_backend.service.GeminiClientService geminiClientService;

    @PostMapping(value = "/trainers/analyze-document", consumes = org.springframework.http.MediaType.MULTIPART_FORM_DATA_VALUE)
    @PreAuthorize("isAuthenticated()")
    public ResponseEntity<?> analyzeDocumentFile(@RequestParam("file") org.springframework.web.multipart.MultipartFile file) {
        try {
            if (file == null || file.isEmpty()) {
                return ResponseEntity.badRequest().body("{\"error\": \"File is required\"}");
            }
            byte[] bytes = file.getBytes();
            String contentType = file.getContentType();
            String resultJson = geminiClientService.analyzeDocumentImage(bytes, contentType);
            if (resultJson == null || resultJson.isBlank()) {
                return ResponseEntity.badRequest().body("{\"error\": \"AI Vision analysis failed\"}");
            }
            return ResponseEntity.ok()
                    .header("Content-Type", "application/json")
                    .body(resultJson);
        } catch (Exception e) {
            e.printStackTrace();
            return ResponseEntity.badRequest().body("{\"error\": \"" + e.getMessage() + "\"}");
        }
    }

    @PostMapping(value = "/trainers/analyze-document-url")
    @PreAuthorize("isAuthenticated()")
    public ResponseEntity<?> analyzeDocumentUrl(@RequestBody java.util.Map<String, String> body) {
        try {
            String imageUrl = body.get("imageUrl");
            if (imageUrl == null || imageUrl.isBlank()) {
                return ResponseEntity.badRequest().body("{\"error\": \"imageUrl is required\"}");
            }
            byte[] bytes = org.springframework.web.reactive.function.client.WebClient.create()
                    .get()
                    .uri(imageUrl)
                    .retrieve()
                    .bodyToMono(byte[].class)
                    .block();
            String contentType = "image/jpeg";
            if (imageUrl.toLowerCase().endsWith(".png")) contentType = "image/png";
            else if (imageUrl.toLowerCase().endsWith(".webp")) contentType = "image/webp";

            String resultJson = geminiClientService.analyzeDocumentImage(bytes, contentType);
            if (resultJson == null || resultJson.isBlank()) {
                return ResponseEntity.badRequest().body("{\"error\": \"AI Vision analysis failed\"}");
            }
            return ResponseEntity.ok()
                    .header("Content-Type", "application/json")
                    .body(resultJson);
        } catch (Exception e) {
            e.printStackTrace();
            return ResponseEntity.badRequest().body("{\"error\": \"" + e.getMessage() + "\"}");
        }
    }
}
