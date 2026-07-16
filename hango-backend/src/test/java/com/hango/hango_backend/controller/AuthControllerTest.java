package com.hango.hango_backend.controller;

import com.hango.hango_backend.dto.ForgotPasswordRequest;
import com.hango.hango_backend.dto.GoogleLoginRequest;
import com.hango.hango_backend.dto.LoginRequest;
import com.hango.hango_backend.dto.LoginResponse;
import com.hango.hango_backend.dto.RegisterRequest;
import com.hango.hango_backend.dto.ResetPasswordRequest;
import com.hango.hango_backend.dto.UserResponse;
import com.hango.hango_backend.dto.VerifyOtpRequest;
import com.hango.hango_backend.service.AuthService;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.http.ResponseEntity;
import org.springframework.security.authentication.BadCredentialsException;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.security.core.userdetails.UsernameNotFoundException;
import org.springframework.web.multipart.MultipartFile;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.doThrow;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class AuthControllerTest {

    @Mock
    private AuthService authService;

    @InjectMocks
    private AuthController authController;

    // =================================================================
    // authenticateUser / googleLogin — must stay 400 for every failure
    // (no differentiated status code) to avoid leaking account existence
    // =================================================================

    @Test
    void authenticateUserShouldReturn400OnBadCredentialsNotDifferentiated() {
        when(authService.authenticateUser(any(LoginRequest.class)))
                .thenThrow(new BadCredentialsException("Bad credentials"));

        ResponseEntity<?> response = authController.authenticateUser(new LoginRequest());

        assertEquals(400, response.getStatusCode().value());
    }

    @Test
    void authenticateUserShouldReturn400OnUnknownUserNotDifferentiated() {
        when(authService.authenticateUser(any(LoginRequest.class)))
                .thenThrow(new UsernameNotFoundException("User not found"));

        ResponseEntity<?> response = authController.authenticateUser(new LoginRequest());

        assertEquals(400, response.getStatusCode().value());
    }

    @Test
    void googleLoginShouldReturn400OnAnyFailureNotDifferentiated() {
        when(authService.googleLogin(any(GoogleLoginRequest.class)))
                .thenThrow(new IllegalArgumentException("Google authentication failed: invalid token"));

        ResponseEntity<?> response = authController.googleLogin(new GoogleLoginRequest());

        assertEquals(400, response.getStatusCode().value());
    }

    @Test
    void authenticateUserShouldReturn200OnSuccess() {
        when(authService.authenticateUser(any(LoginRequest.class)))
                .thenReturn(new LoginResponse("jwt", 1L, "known@example.com", "Known User", java.util.List.of("LEARNER"), null));

        ResponseEntity<?> response = authController.authenticateUser(new LoginRequest());

        assertEquals(200, response.getStatusCode().value());
    }

    @Test
    void googleLoginShouldReturn200OnSuccess() {
        when(authService.googleLogin(any(GoogleLoginRequest.class)))
                .thenReturn(new LoginResponse("jwt", 1L, "known@example.com", "Known User", java.util.List.of("LEARNER"), null));

        ResponseEntity<?> response = authController.googleLogin(new GoogleLoginRequest());

        assertEquals(200, response.getStatusCode().value());
    }

    // =================================================================
    // registerUser
    // =================================================================

    @Test
    void registerUserShouldReturn400OnDuplicateEmail() {
        when(authService.registerUser(any(RegisterRequest.class)))
                .thenThrow(new IllegalArgumentException("Error: Email is already in use!"));

        ResponseEntity<?> response = authController.registerUser(new RegisterRequest());

        assertEquals(400, response.getStatusCode().value());
    }

    @Test
    void registerUserShouldReturn200OnSuccess() {
        when(authService.registerUser(any(RegisterRequest.class)))
                .thenReturn(UserResponse.builder().email("new@example.com").build());

        ResponseEntity<?> response = authController.registerUser(new RegisterRequest());

        assertEquals(200, response.getStatusCode().value());
    }

    // =================================================================
    // forgotPassword
    // =================================================================

    @Test
    void forgotPasswordShouldReturn400WhenEmailNotRegistered() {
        doThrow(new IllegalArgumentException("Email is not registered in the system."))
                .when(authService).forgotPassword(any(ForgotPasswordRequest.class));

        ResponseEntity<?> response = authController.forgotPassword(new ForgotPasswordRequest());

        assertEquals(400, response.getStatusCode().value());
    }

    @Test
    void forgotPasswordShouldReturn200OnSuccess() {
        ForgotPasswordRequest req = new ForgotPasswordRequest();
        req.setEmail("known@example.com");

        ResponseEntity<?> response = authController.forgotPassword(req);

        assertEquals(200, response.getStatusCode().value());
    }

    // =================================================================
    // verifyOtp
    // =================================================================

    @Test
    void verifyOtpShouldReturn400OnInvalidOtp() {
        doThrow(new IllegalArgumentException("Invalid OTP code."))
                .when(authService).verifyOtp(any(VerifyOtpRequest.class));

        ResponseEntity<?> response = authController.verifyOtp(new VerifyOtpRequest());

        assertEquals(400, response.getStatusCode().value());
    }

    @Test
    void verifyOtpShouldReturn200OnSuccess() {
        ResponseEntity<?> response = authController.verifyOtp(new VerifyOtpRequest());

        assertEquals(200, response.getStatusCode().value());
    }

    // =================================================================
    // verifyAccount / resendVerification / resetPassword / uploadAvatar
    // — now differentiate 404 when the account doesn't exist
    // =================================================================

    @Test
    void verifyAccountShouldReturn404WhenUserNotFound() {
        doThrow(new UsernameNotFoundException("User not found")).when(authService).verifyAccount("ghost@example.com");

        ResponseEntity<?> response = authController.verifyAccount("ghost@example.com");

        assertEquals(404, response.getStatusCode().value());
    }

    @Test
    void verifyAccountShouldReturn200OnSuccess() {
        ResponseEntity<?> response = authController.verifyAccount("known@example.com");

        assertEquals(200, response.getStatusCode().value());
    }

    // =================================================================
    // checkVerification
    // =================================================================

    @Test
    void checkVerificationShouldReturnTrueWhenVerified() {
        when(authService.isAccountVerified("known@example.com")).thenReturn(true);

        ResponseEntity<?> response = authController.checkVerification("known@example.com");

        assertEquals(200, response.getStatusCode().value());
        assertEquals(java.util.Map.of("verified", true), response.getBody());
    }

    @Test
    void checkVerificationShouldReturnFalseWhenNotVerifiedOrNotFound() {
        when(authService.isAccountVerified("ghost@example.com")).thenReturn(false);

        ResponseEntity<?> response = authController.checkVerification("ghost@example.com");

        assertEquals(200, response.getStatusCode().value());
        assertEquals(java.util.Map.of("verified", false), response.getBody());
    }

    @Test
    void resendVerificationShouldReturn404WhenUserNotFound() {
        doThrow(new UsernameNotFoundException("User not found")).when(authService).resendVerificationEmail("ghost@example.com");

        ResponseEntity<?> response = authController.resendVerification("ghost@example.com");

        assertEquals(404, response.getStatusCode().value());
    }

    @Test
    void resendVerificationShouldReturn200OnSuccess() {
        ResponseEntity<?> response = authController.resendVerification("known@example.com");

        assertEquals(200, response.getStatusCode().value());
    }

    @Test
    void resetPasswordShouldReturn404WhenUserNotFound() {
        doThrow(new UsernameNotFoundException("User not found")).when(authService).resetPassword(any(ResetPasswordRequest.class));

        ResponseEntity<?> response = authController.resetPassword(new ResetPasswordRequest());

        assertEquals(404, response.getStatusCode().value());
    }

    @Test
    void resetPasswordShouldReturn200OnSuccess() {
        ResponseEntity<?> response = authController.resetPassword(new ResetPasswordRequest());

        assertEquals(200, response.getStatusCode().value());
    }

    @Test
    void uploadAvatarShouldReturn404WhenUserNotFound() throws Exception {
        UserDetails principal = mock(UserDetails.class);
        when(principal.getUsername()).thenReturn("ghost@example.com");
        MultipartFile file = mock(MultipartFile.class);
        when(authService.updateAvatar(anyString(), any(MultipartFile.class)))
                .thenThrow(new UsernameNotFoundException("User not found"));

        ResponseEntity<?> response = authController.uploadAvatar(principal, file);

        assertEquals(404, response.getStatusCode().value());
    }

    @Test
    void uploadAvatarShouldReturn200OnSuccess() throws Exception {
        UserDetails principal = mock(UserDetails.class);
        when(principal.getUsername()).thenReturn("known@example.com");
        MultipartFile file = mock(MultipartFile.class);
        when(authService.updateAvatar(anyString(), any(MultipartFile.class)))
                .thenReturn(UserResponse.builder().email("known@example.com").build());

        ResponseEntity<?> response = authController.uploadAvatar(principal, file);

        assertEquals(200, response.getStatusCode().value());
    }
}
