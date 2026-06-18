package com.hango.hango_backend.controller;

import com.hango.hango_backend.dto.*;
import com.hango.hango_backend.service.AuthService;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.validation.annotation.Validated;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.multipart.MultipartFile;

import jakarta.validation.Valid;
import java.io.IOException;

@CrossOrigin(origins = "*", maxAge = 3600)
@RestController
@RequestMapping("/api/auth")
@Validated
public class AuthController {

    @Autowired
    private AuthService authService;

    @PostMapping("/login")
    public ResponseEntity<?> authenticateUser(@Valid @RequestBody LoginRequest loginRequest) {
        try {
            LoginResponse response = authService.authenticateUser(loginRequest);
            return ResponseEntity.ok(response);
        } catch (Exception e) {
            return ResponseEntity.badRequest().body("Error: " + e.getMessage());
        }
    }

    @PostMapping("/register")
    public ResponseEntity<?> registerUser(@Valid @RequestBody RegisterRequest registerRequest) {
        try {
            UserResponse response = authService.registerUser(registerRequest);
            return ResponseEntity.ok(response);
        } catch (Exception e) {
            return ResponseEntity.badRequest().body("Error: " + e.getMessage());
        }
    }

    @PostMapping("/google")
    public ResponseEntity<?> googleLogin(@Valid @RequestBody GoogleLoginRequest googleLoginRequest) {
        try {
            LoginResponse response = authService.googleLogin(googleLoginRequest);
            return ResponseEntity.ok(response);
        } catch (Exception e) {
            return ResponseEntity.badRequest().body("Error: " + e.getMessage());
        }
    }

    @PostMapping("/forgot-password")
    public ResponseEntity<?> forgotPassword(@Valid @RequestBody ForgotPasswordRequest request) {
        try {
            authService.forgotPassword(request);
            return ResponseEntity.ok("OTP sent successfully to " + request.getEmail());
        } catch (Exception e) {
            return ResponseEntity.badRequest().body("Error: " + e.getMessage());
        }
    }

    @PostMapping("/verify-otp")
    public ResponseEntity<?> verifyOtp(@Valid @RequestBody VerifyOtpRequest request) {
        try {
            authService.verifyOtp(request);
            return ResponseEntity.ok("OTP verified successfully");
        } catch (Exception e) {
            return ResponseEntity.badRequest().body("Error: " + e.getMessage());
        }
    }

    @GetMapping("/verify")
    public ResponseEntity<?> verifyAccount(@RequestParam("email") String email) {
        try {
            authService.verifyAccount(email);
            return ResponseEntity.ok()
                    .header("Content-Type", "text/html")
                    .body("<html><body style='font-family: Arial, sans-serif; text-align: center; margin-top: 100px; background-color: #F9FAFB;'>" +
                            "<div style='display: inline-block; padding: 40px; border-radius: 12px; background-color: #ffffff; box-shadow: 0 4px 12px rgba(0,0,0,0.05); max-width: 450px;'>" +
                            "<div style='width: 60px; height: 60px; background-color: #E6FDF9; border-radius: 50%; display: flex; align-items: center; justify-content: center; margin: 0 auto 20px;'>" +
                            "<span style='color: #28B79B; font-size: 32px; font-weight: bold;'>✓</span>" +
                            "</div>" +
                            "<h2 style='color: #1F2937; margin-bottom: 8px;'>Account Verified Successfully!</h2>" +
                            "<p style='color: #4B5563; line-height: 1.5; margin-bottom: 24px;'>Your account on HanGo has been successfully verified. You can now close this browser tab and sign in.</p>" +
                            "<p style='color: #9CA3AF; font-size: 13px;'>HanGo - Your trusted education partner</p>" +
                            "</div>" +
                            "</body></html>");
        } catch (Exception e) {
            return ResponseEntity.badRequest().body("Error: " + e.getMessage());
        }
    }

    @GetMapping("/check-verification")
    public ResponseEntity<?> checkVerification(@RequestParam("email") String email) {
        try {
            boolean verified = authService.isAccountVerified(email);
            return ResponseEntity.ok(java.util.Map.of("verified", verified));
        } catch (Exception e) {
            return ResponseEntity.badRequest().body("Error: " + e.getMessage());
        }
    }

    @PostMapping("/resend-verification")
    public ResponseEntity<?> resendVerification(@RequestParam("email") String email) {
        try {
            authService.resendVerificationEmail(email);
            return ResponseEntity.ok("Verification email resent successfully");
        } catch (Exception e) {
            return ResponseEntity.badRequest().body("Error: " + e.getMessage());
        }
    }


    @PostMapping("/reset-password")
    public ResponseEntity<?> resetPassword(@Valid @RequestBody ResetPasswordRequest request) {
        try {
            authService.resetPassword(request);
            return ResponseEntity.ok("Password updated successfully");
        } catch (Exception e) {
            return ResponseEntity.badRequest().body("Error: " + e.getMessage());
        }
    }

    @PostMapping("/profile/avatar")
    @PreAuthorize("hasRole('LEARNER') or hasRole('TRAINER') or hasRole('TRAINING_LEAD') or hasRole('ADMINISTRATOR')")
    public ResponseEntity<?> uploadAvatar(
            @AuthenticationPrincipal UserDetails userDetails,
            @RequestParam("file") MultipartFile file) {
        try {
            UserResponse response = authService.updateAvatar(userDetails.getUsername(), file);
            return ResponseEntity.ok(response);
        } catch (IOException e) {
            return ResponseEntity.internalServerError().body("Error uploading image: " + e.getMessage());
        } catch (Exception e) {
            return ResponseEntity.badRequest().body("Error: " + e.getMessage());
        }
    }
}
