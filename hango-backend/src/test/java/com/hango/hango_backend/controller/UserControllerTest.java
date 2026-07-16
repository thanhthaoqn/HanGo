package com.hango.hango_backend.controller;

import com.hango.hango_backend.dto.ChangePasswordRequest;
import com.hango.hango_backend.dto.ProfileUpdateRequest;
import com.hango.hango_backend.dto.UserResponse;
import com.hango.hango_backend.service.AuthService;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.security.core.userdetails.UsernameNotFoundException;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.doThrow;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class UserControllerTest {

    @Mock
    private AuthService authService;

    @InjectMocks
    private UserController userController;

    private UserDetails principal(String email) {
        UserDetails userDetails = mock(UserDetails.class);
        when(userDetails.getUsername()).thenReturn(email);
        return userDetails;
    }

    // =================================================================
    // getUserProfile
    // =================================================================

    @Test
    void getUserProfileShouldReturn401WhenUnauthenticated() {
        ResponseEntity<?> response = userController.getUserProfile(null);
        assertEquals(401, response.getStatusCode().value());
    }

    @Test
    void getUserProfileShouldReturn404WhenUserNotFound() {
        when(authService.getUserProfile("ghost@example.com")).thenThrow(new UsernameNotFoundException("User not found"));
        ResponseEntity<?> response = userController.getUserProfile(principal("ghost@example.com"));
        assertEquals(404, response.getStatusCode().value());
    }

    @Test
    void getUserProfileShouldReturn200OnSuccess() {
        when(authService.getUserProfile("known@example.com")).thenReturn(UserResponse.builder().email("known@example.com").build());
        ResponseEntity<?> response = userController.getUserProfile(principal("known@example.com"));
        assertEquals(200, response.getStatusCode().value());
    }

    // =================================================================
    // updateProfile
    // =================================================================

    @Test
    void updateProfileShouldReturn401WhenUnauthenticated() {
        ResponseEntity<?> response = userController.updateProfile(null, new ProfileUpdateRequest());
        assertEquals(401, response.getStatusCode().value());
    }

    @Test
    void updateProfileShouldReturn404WhenUserNotFound() {
        doThrow(new UsernameNotFoundException("User not found"))
                .when(authService).updateProfile(anyString(), any(ProfileUpdateRequest.class));
        ResponseEntity<?> response = userController.updateProfile(principal("ghost@example.com"), new ProfileUpdateRequest());
        assertEquals(404, response.getStatusCode().value());
    }

    @Test
    void updateProfileShouldReturn200OnSuccess() {
        when(authService.updateProfile(anyString(), any(ProfileUpdateRequest.class)))
                .thenReturn(UserResponse.builder().email("known@example.com").build());
        ResponseEntity<?> response = userController.updateProfile(principal("known@example.com"), new ProfileUpdateRequest());
        assertEquals(200, response.getStatusCode().value());
    }

    // =================================================================
    // changePassword
    // =================================================================

    @Test
    void changePasswordShouldReturn401WhenUnauthenticated() {
        ResponseEntity<?> response = userController.changePassword(null, new ChangePasswordRequest());
        assertEquals(401, response.getStatusCode().value());
    }

    @Test
    void changePasswordShouldReturn404WhenUserNotFound() {
        doThrow(new UsernameNotFoundException("User not found"))
                .when(authService).changePassword(anyString(), any(ChangePasswordRequest.class));
        ResponseEntity<?> response = userController.changePassword(principal("ghost@example.com"), new ChangePasswordRequest());
        assertEquals(404, response.getStatusCode().value());
    }

    @Test
    void changePasswordShouldReturn400OnIncorrectCurrentPassword() {
        doThrow(new IllegalArgumentException("Incorrect current password!"))
                .when(authService).changePassword(anyString(), any(ChangePasswordRequest.class));
        ResponseEntity<?> response = userController.changePassword(principal("known@example.com"), new ChangePasswordRequest());
        assertEquals(400, response.getStatusCode().value());
    }
}
