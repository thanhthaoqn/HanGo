package com.hango.hango_backend.service;

import com.hango.hango_backend.entity.User;
import com.hango.hango_backend.repository.UserRepository;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.time.LocalDateTime;
import java.util.Optional;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
class UserLockoutServiceTest {

    @Mock
    private UserRepository userRepository;

    @InjectMocks
    private UserLockoutService userLockoutService;

    @Test
    void registerFailedLoginAttemptShouldIncrementAttemptsWhenLessThanFive() {
        User user = new User();
        user.setId(1L);
        user.setFailedLoginAttempts(2);

        when(userRepository.findById(1L)).thenReturn(Optional.of(user));

        userLockoutService.registerFailedLoginAttempt(1L);

        ArgumentCaptor<User> captor = ArgumentCaptor.forClass(User.class);
        verify(userRepository).save(captor.capture());

        assertEquals(3, captor.getValue().getFailedLoginAttempts());
        assertNull(captor.getValue().getLockedUntil());
    }

    @Test
    void registerFailedLoginAttemptShouldLockAccountOnFifthAttempt() {
        User user = new User();
        user.setId(1L);
        user.setFailedLoginAttempts(4);

        when(userRepository.findById(1L)).thenReturn(Optional.of(user));

        userLockoutService.registerFailedLoginAttempt(1L);

        ArgumentCaptor<User> captor = ArgumentCaptor.forClass(User.class);
        verify(userRepository).save(captor.capture());

        assertEquals(0, captor.getValue().getFailedLoginAttempts());
        assertNotNull(captor.getValue().getLockedUntil());
        assertTrue(captor.getValue().getLockedUntil().isAfter(LocalDateTime.now().plusMinutes(14)));
    }

    @Test
    void registerFailedLoginAttemptShouldDoNothingIfUserIdIsNull() {
        userLockoutService.registerFailedLoginAttempt(null);
        verify(userRepository, never()).save(any());
    }
}
