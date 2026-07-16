package com.hango.hango_backend.controller;

import com.hango.hango_backend.entity.User;
import com.hango.hango_backend.repository.RoleRepository;
import com.hango.hango_backend.repository.UserRepository;
import com.hango.hango_backend.service.AuthService;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.userdetails.UserDetails;

import java.util.Optional;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class AdminControllerTest {

    @Mock
    private UserRepository userRepository;
    @Mock
    private RoleRepository roleRepository;
    @Mock
    private AuthService authService;

    @InjectMocks
    private AdminController adminController;

    private User targetUser(Long id, String email) {
        return User.builder().id(id).email(email).status("ACTIVE").build();
    }

    private UserDetails adminPrincipal(String email) {
        UserDetails principal = mock(UserDetails.class);
        when(principal.getUsername()).thenReturn(email);
        return principal;
    }

    // =================================================================
    // updateUserStatus
    // =================================================================

    @Test
    void updateUserStatusShouldRejectStatusOutsideWhitelist() {
        ResponseEntity<?> response = adminController.updateUserStatus(5L, "LOCKED", mock(UserDetails.class));

        assertEquals(400, response.getStatusCode().value());
        verify(userRepository, never()).findById(any());
        verify(userRepository, never()).save(any());
    }

    @Test
    void updateUserStatusShouldReturn404WhenTargetNotFound() {
        when(userRepository.findById(99L)).thenReturn(Optional.empty());

        ResponseEntity<?> response = adminController.updateUserStatus(99L, "INACTIVE", mock(UserDetails.class));

        assertEquals(404, response.getStatusCode().value());
    }

    @Test
    void updateUserStatusShouldRejectAdminChangingOwnStatus() {
        User admin = targetUser(1L, "admin@example.com");
        when(userRepository.findById(1L)).thenReturn(Optional.of(admin));

        ResponseEntity<?> response = adminController.updateUserStatus(1L, "INACTIVE", adminPrincipal("admin@example.com"));

        assertEquals(400, response.getStatusCode().value());
        verify(userRepository, never()).save(any());
    }

    @Test
    void updateUserStatusShouldUpdateStatusForAnotherUser() {
        User target = targetUser(2L, "learner@example.com");
        when(userRepository.findById(2L)).thenReturn(Optional.of(target));

        ResponseEntity<?> response = adminController.updateUserStatus(2L, "inactive", adminPrincipal("admin@example.com"));

        assertEquals(200, response.getStatusCode().value());
        assertEquals("INACTIVE", target.getStatus());
        verify(userRepository).save(target);
    }
}
