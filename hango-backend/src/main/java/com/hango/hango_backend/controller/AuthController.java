package com.hango.hango_backend.controller;

import com.hango.hango_backend.dto.*;
import com.hango.hango_backend.exception.ApiException;
import com.hango.hango_backend.service.AuthService;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.security.core.userdetails.UsernameNotFoundException;
import org.springframework.validation.annotation.Validated;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.multipart.MultipartFile;

import jakarta.validation.Valid;
import java.io.IOException;
import java.util.Map;

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
        } catch (ApiException e) {
            return ResponseEntity.status(e.getStatus()).body(Map.of("message", e.getMessage()));
        } catch (Exception e) {
            return ResponseEntity.badRequest().body("Error: " + e.getMessage());
        }
    }

    @PostMapping("/register")
    public ResponseEntity<?> registerUser(@Valid @RequestBody RegisterRequest registerRequest) {
        try {
            UserResponse response = authService.registerUser(registerRequest);
            return ResponseEntity.ok(response);
        } catch (ApiException e) {
            return ResponseEntity.status(e.getStatus()).body(Map.of("message", e.getMessage()));
        } catch (Exception e) {
            return ResponseEntity.badRequest().body("Error: " + e.getMessage());
        }
    }

    @PostMapping("/google")
    public ResponseEntity<?> googleLogin(@Valid @RequestBody GoogleLoginRequest googleLoginRequest) {
        try {
            LoginResponse response = authService.googleLogin(googleLoginRequest);
            return ResponseEntity.ok(response);
        } catch (ApiException e) {
            return ResponseEntity.status(e.getStatus()).body(Map.of("message", e.getMessage()));
        } catch (Exception e) {
            return ResponseEntity.badRequest().body("Error: " + e.getMessage());
        }
    }

    @PostMapping("/forgot-password")
    public ResponseEntity<?> forgotPassword(@Valid @RequestBody ForgotPasswordRequest request) {
        try {
            authService.forgotPassword(request);
            // Always a generic, conditional message: never reveals whether the email is
            // registered. Phrased as "if registered" on purpose -- callers must not
            // present this as a guaranteed send (see forgot_password_page.dart).
            return ResponseEntity.ok("If an account exists for this email, a password reset code has been sent to it. Please check your inbox (and spam folder).");
        } catch (Exception e) {
            return ResponseEntity.badRequest().body("Error: " + e.getMessage());
        }
    }

    @PostMapping("/verify-otp")
    public ResponseEntity<?> verifyOtp(@Valid @RequestBody VerifyOtpRequest request) {
        try {
            authService.verifyOtp(request);
            return ResponseEntity.ok("OTP verified successfully");
        } catch (ApiException e) {
            return ResponseEntity.status(e.getStatus()).body(Map.of("message", e.getMessage()));
        } catch (Exception e) {
            return ResponseEntity.badRequest().body("Error: " + e.getMessage());
        }
    }

    @GetMapping("/verify")
    public ResponseEntity<?> verifyAccount(@RequestParam(value = "token", required = false) String token) {
        try {
            if (token == null || token.isBlank()) {
                throw new ApiException("Invalid verification link.", org.springframework.http.HttpStatus.BAD_REQUEST);
            }
            authService.verifyAccountByToken(token);
            return verifyResultPage("Account Verified Successfully!",
                    "Your account on HanGo has been successfully verified. You can now close this browser tab and sign in.",
                    "#E6FDF9", "#28B79B", "✓", org.springframework.http.HttpStatus.OK);
        } catch (ApiException e) {
            // A repeat click on an already-consumed link means the account is already in
            // the desired end state, not an error the user needs to act on.
            if (e.getMessage() != null && e.getMessage().contains("already been verified")) {
                return verifyResultPage("Already Verified",
                        "Your account was already verified. You can sign in now.",
                        "#E6FDF9", "#28B79B", "✓", org.springframework.http.HttpStatus.OK);
            }
            return verifyResultPage("Verification Link Invalid", e.getMessage(), "#FEF2F2", "#DC2626", "!", e.getStatus());
        } catch (Exception e) {
            return verifyResultPage("Verification Link Invalid",
                    "This verification link could not be processed. Please request a new one.",
                    "#FEF2F2", "#DC2626", "!", org.springframework.http.HttpStatus.BAD_REQUEST);
        }
    }

    private ResponseEntity<String> verifyResultPage(String title, String message, String iconBg, String iconColor,
            String icon, org.springframework.http.HttpStatus status) {
        String html = "<html><head><meta charset='UTF-8'></head><body style='font-family: Arial, sans-serif; text-align: center; margin-top: 100px; background-color: #F9FAFB;'>" +
                "<div style='display: inline-block; padding: 40px; border-radius: 12px; background-color: #ffffff; box-shadow: 0 4px 12px rgba(0,0,0,0.05); max-width: 450px;'>" +
                "<div style='width: 60px; height: 60px; background-color: " + iconBg + "; border-radius: 50%; display: flex; align-items: center; justify-content: center; margin: 0 auto 20px;'>" +
                "<span style='color: " + iconColor + "; font-size: 32px; font-weight: bold;'>" + icon + "</span>" +
                "</div>" +
                "<h2 style='color: #1F2937; margin-bottom: 8px;'>" + title + "</h2>" +
                "<p style='color: #4B5563; line-height: 1.5; margin-bottom: 24px;'>" + message + "</p>" +
                "<p style='color: #9CA3AF; font-size: 13px;'>HanGo - Your trusted education partner</p>" +
                "</div>" +
                "</body></html>";
        return ResponseEntity.status(status).header("Content-Type", "text/html; charset=UTF-8").body(html);
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
        } catch (UsernameNotFoundException e) {
            return ResponseEntity.status(404).body("Error: " + e.getMessage());
        } catch (ApiException e) {
            return ResponseEntity.status(e.getStatus()).body(Map.of("message", e.getMessage()));
        } catch (Exception e) {
            return ResponseEntity.badRequest().body("Error: " + e.getMessage());
        }
    }


    @PostMapping("/reset-password")
    public ResponseEntity<?> resetPassword(@Valid @RequestBody ResetPasswordRequest request) {
        try {
            authService.resetPassword(request);
            return ResponseEntity.ok("Password updated successfully");
        } catch (UsernameNotFoundException e) {
            return ResponseEntity.status(404).body("Error: " + e.getMessage());
        } catch (ApiException e) {
            return ResponseEntity.status(e.getStatus()).body(Map.of("message", e.getMessage()));
        } catch (Exception e) {
            return ResponseEntity.badRequest().body("Error: " + e.getMessage());
        }
    }

    @PostMapping("/refresh-token")
    public ResponseEntity<?> refreshToken(@Valid @RequestBody RefreshTokenRequest request) {
        try {
            TokenRefreshResponse response = authService.refreshAccessToken(request.getRefreshToken());
            return ResponseEntity.ok(response);
        } catch (ApiException e) {
            return ResponseEntity.status(e.getStatus()).body(Map.of("message", e.getMessage()));
        } catch (Exception e) {
            return ResponseEntity.badRequest().body("Error: " + e.getMessage());
        }
    }

    @PostMapping("/logout")
    public ResponseEntity<?> logout(@Valid @RequestBody RefreshTokenRequest request) {
        try {
            authService.logout(request.getRefreshToken());
            return ResponseEntity.ok("Logged out successfully");
        } catch (Exception e) {
            return ResponseEntity.badRequest().body("Error: " + e.getMessage());
        }
    }

    @PostMapping("/profile/avatar")
    @PreAuthorize("hasAuthority('ENROLL_AND_LEARN_COURSES') or hasAuthority('MANAGE_ACCOUNTS_ROLES') or hasAuthority('MANAGE_ACCOUNTS_ROLES') or hasRole('ADMINISTRATOR') or hasRole('COURSE_MANAGER')")
    public ResponseEntity<?> uploadAvatar(
            @AuthenticationPrincipal UserDetails userDetails,
            @RequestParam("file") MultipartFile file) {
        try {
            UserResponse response = authService.updateAvatar(userDetails.getUsername(), file);
            return ResponseEntity.ok(response);
        } catch (UsernameNotFoundException e) {
            return ResponseEntity.status(404).body("Error: " + e.getMessage());
        } catch (IOException e) {
            return ResponseEntity.internalServerError().body("Error uploading image: " + e.getMessage());
        } catch (Exception e) {
            return ResponseEntity.badRequest().body("Error: " + e.getMessage());
        }
    }
}
