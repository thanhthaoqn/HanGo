package com.hango.hango_backend.controller;

import com.hango.hango_backend.dto.ProfileUpdateRequest;
import com.hango.hango_backend.dto.UserResponse;
import com.hango.hango_backend.service.AuthService;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.boot.webmvc.test.autoconfigure.WebMvcTest;
import org.springframework.http.MediaType;
import org.springframework.security.test.context.support.WithMockUser;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.test.web.servlet.MockMvc;

import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.verifyNoInteractions;
import static org.mockito.Mockito.when;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.put;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

/**
 * addFilters=false: isolates Bean Validation from the security filter chain (which requires
 * authentication for /api/v1/users/** and would otherwise return 401/403 before validation runs).
 */
@WebMvcTest(UserController.class)
@AutoConfigureMockMvc(addFilters = false)
class UserControllerValidationTest {

    @Autowired
    private MockMvc mockMvc;

    @MockitoBean
    private AuthService authService;

    // =================================================================
    // /api/v1/users/change-password — ChangePasswordRequest
    // =================================================================

    @Test
    void changePasswordShouldReturn400WhenCurrentPasswordIsBlank() throws Exception {
        mockMvc.perform(put("/api/v1/users/change-password")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"currentPassword\":\"\",\"newPassword\":\"newPass123\"}"))
                .andExpect(status().isBadRequest());
        verifyNoInteractions(authService);
    }

    @Test
    void changePasswordShouldReturn400WhenNewPasswordShorterThan8Chars() throws Exception {
        mockMvc.perform(put("/api/v1/users/change-password")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"currentPassword\":\"correctCurrent\",\"newPassword\":\"short\"}"))
                .andExpect(status().isBadRequest());
        verifyNoInteractions(authService);
    }

    // =================================================================
    // /api/v1/users/me (PUT) — ProfileUpdateRequest
    // =================================================================

    /**
     * Finding, not a fabricated expectation: ProfileUpdateRequest.java has NO Bean Validation
     * annotations at all (no @Email, no @Size) despite the controller using @Valid. This test
     * documents actual behaviour — an obviously-invalid email format is currently accepted
     * (200, not 400) because there is nothing for @Valid to check. Flagged in unit_test_plan.md
     * as a real gap; not fixed here since the user asked only for tests, not further code changes
     * this round.
     */
    @Test
    @WithMockUser(username = "known@example.com")
    void updateProfileShouldCurrentlyAcceptMalformedEmailBecauseNoValidationAnnotationExists() throws Exception {
        when(authService.updateProfile(anyString(), any(ProfileUpdateRequest.class)))
                .thenReturn(UserResponse.builder().email("not-an-email-at-all").build());

        mockMvc.perform(put("/api/v1/users/me")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"email\":\"not-an-email-at-all\"}"))
                .andExpect(status().isOk());
    }
}
