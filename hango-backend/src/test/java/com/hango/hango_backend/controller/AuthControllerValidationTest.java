package com.hango.hango_backend.controller;

import com.hango.hango_backend.service.AuthService;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.boot.webmvc.test.autoconfigure.WebMvcTest;
import org.springframework.http.MediaType;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.test.web.servlet.MockMvc;

import static org.mockito.Mockito.verifyNoInteractions;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

/**
 * Exercises the real Spring MVC + Bean Validation pipeline (@Valid on DTOs) through MockMvc,
 * which plain Mockito unit tests (AuthControllerTest) cannot reach since they call controller
 * methods directly in Java, bypassing HTTP deserialization/validation entirely.
 * All endpoints under /api/auth/** are permitAll (see SecurityConfig), so no auth setup needed.
 */
@WebMvcTest(AuthController.class)
@AutoConfigureMockMvc(addFilters = false)
class AuthControllerValidationTest {

    @Autowired
    private MockMvc mockMvc;

    @MockitoBean
    private AuthService authService;

    // =================================================================
    // /api/auth/login — LoginRequest
    // =================================================================

    @Test
    void loginShouldReturn400WhenEmailIsBlank() throws Exception {
        mockMvc.perform(post("/api/auth/login")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"email\":\"\",\"password\":\"pass1234\"}"))
                .andExpect(status().isBadRequest());
        verifyNoInteractions(authService);
    }

    @Test
    void loginShouldReturn400WhenEmailIsNotValidFormat() throws Exception {
        mockMvc.perform(post("/api/auth/login")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"email\":\"not-an-email\",\"password\":\"pass1234\"}"))
                .andExpect(status().isBadRequest());
        verifyNoInteractions(authService);
    }

    @Test
    void loginShouldReturn400WhenPasswordIsBlank() throws Exception {
        mockMvc.perform(post("/api/auth/login")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"email\":\"valid@example.com\",\"password\":\"\"}"))
                .andExpect(status().isBadRequest());
        verifyNoInteractions(authService);
    }

    // =================================================================
    // /api/auth/register — RegisterRequest
    // =================================================================

    @Test
    void registerShouldReturn400WhenEmailIsNotValidFormat() throws Exception {
        mockMvc.perform(post("/api/auth/register")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"email\":\"not-an-email\",\"password\":\"pass1234\",\"fullName\":\"New User\"}"))
                .andExpect(status().isBadRequest());
        verifyNoInteractions(authService);
    }

    @Test
    void registerShouldReturn400WhenPasswordShorterThan8Chars() throws Exception {
        mockMvc.perform(post("/api/auth/register")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"email\":\"new@example.com\",\"password\":\"short\",\"fullName\":\"New User\"}"))
                .andExpect(status().isBadRequest());
        verifyNoInteractions(authService);
    }

    @Test
    void registerShouldReturn400WhenFullNameIsBlank() throws Exception {
        mockMvc.perform(post("/api/auth/register")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"email\":\"new@example.com\",\"password\":\"pass1234\",\"fullName\":\"\"}"))
                .andExpect(status().isBadRequest());
        verifyNoInteractions(authService);
    }

    // =================================================================
    // /api/auth/google — GoogleLoginRequest
    // =================================================================

    @Test
    void googleLoginShouldReturn400WhenIdTokenIsBlank() throws Exception {
        mockMvc.perform(post("/api/auth/google")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"idToken\":\"\"}"))
                .andExpect(status().isBadRequest());
        verifyNoInteractions(authService);
    }

    // =================================================================
    // /api/auth/forgot-password — ForgotPasswordRequest
    // =================================================================

    @Test
    void forgotPasswordShouldReturn400WhenEmailIsNotValidFormat() throws Exception {
        mockMvc.perform(post("/api/auth/forgot-password")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"email\":\"not-an-email\"}"))
                .andExpect(status().isBadRequest());
        verifyNoInteractions(authService);
    }

    // =================================================================
    // /api/auth/verify-otp — VerifyOtpRequest
    // =================================================================

    @Test
    void verifyOtpShouldReturn400WhenOtpCodeIsNotExactly6Digits() throws Exception {
        mockMvc.perform(post("/api/auth/verify-otp")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"email\":\"known@example.com\",\"otpCode\":\"123\"}"))
                .andExpect(status().isBadRequest());
        verifyNoInteractions(authService);
    }

    // =================================================================
    // /api/auth/reset-password — ResetPasswordRequest
    // =================================================================

    @Test
    void resetPasswordShouldReturn400WhenNewPasswordShorterThan8Chars() throws Exception {
        mockMvc.perform(post("/api/auth/reset-password")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"email\":\"known@example.com\",\"newPassword\":\"short\"}"))
                .andExpect(status().isBadRequest());
        verifyNoInteractions(authService);
    }
}
