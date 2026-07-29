package com.hango.hango_backend.security;

import com.hango.hango_backend.entity.Role;
import com.hango.hango_backend.entity.User;
import com.hango.hango_backend.repository.UserRepository;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.security.core.userdetails.UsernameNotFoundException;

import java.util.HashSet;
import java.util.Optional;
import java.util.Set;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class UserDetailsServiceImplTest {

    @Mock
    private UserRepository userRepository;

    @InjectMocks
    private UserDetailsServiceImpl userDetailsService;

    // =================================================================
    // loadUserByUsername
    // =================================================================

    @Test
    void loadUserByUsernameShouldBuildUserDetailsWithRolePrefixedAuthorities() {
        User user = User.builder()
                .id(7L)
                .email("trainer@example.com")
                .passwordHash("hashed-pw")
                .fullName("Trainer Name")
                .roles(new HashSet<>(Set.of(Role.builder().id(2L).roleName("TRAINER").build())))
                .build();
        when(userRepository.findByEmail("trainer@example.com")).thenReturn(Optional.of(user));

        UserDetails result = userDetailsService.loadUserByUsername("trainer@example.com");

        assertEquals("trainer@example.com", result.getUsername());
        assertEquals("hashed-pw", result.getPassword());
        assertTrue(result.getAuthorities().stream()
                .anyMatch(a -> a.getAuthority().equals("ROLE_TRAINER")));
    }

    @Test
    void loadUserByUsernameShouldThrowWhenUserNotFound() {
        when(userRepository.findByEmail("ghost@example.com")).thenReturn(Optional.empty());

        assertThrows(UsernameNotFoundException.class,
                () -> userDetailsService.loadUserByUsername("ghost@example.com"));
    }
}
