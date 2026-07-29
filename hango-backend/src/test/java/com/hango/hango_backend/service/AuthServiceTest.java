package com.hango.hango_backend.service;

import java.time.LocalDateTime;
import java.util.HashSet;
import java.util.List;
import java.util.Optional;
import java.util.Set;

import static org.junit.jupiter.api.Assertions.assertDoesNotThrow;
import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNotEquals;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;
import org.junit.jupiter.api.Disabled;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.eq;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import static org.mockito.Mockito.doThrow;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.security.authentication.AuthenticationManager;
import org.springframework.security.authentication.BadCredentialsException;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.authority.SimpleGrantedAuthority;
import org.springframework.security.core.userdetails.UsernameNotFoundException;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.web.multipart.MultipartFile;
import com.google.api.client.googleapis.auth.oauth2.GoogleIdToken;
import com.google.api.client.googleapis.auth.oauth2.GoogleIdTokenVerifier;

import com.hango.hango_backend.dto.ChangePasswordRequest;
import com.hango.hango_backend.dto.ForgotPasswordRequest;
import com.hango.hango_backend.dto.GoogleLoginRequest;
import com.hango.hango_backend.dto.LoginRequest;
import com.hango.hango_backend.dto.LoginResponse;
import com.hango.hango_backend.dto.ProfileUpdateRequest;
import com.hango.hango_backend.dto.RegisterRequest;
import com.hango.hango_backend.dto.ResetPasswordRequest;
import com.hango.hango_backend.dto.UserResponse;
import com.hango.hango_backend.dto.VerifyOtpRequest;
import com.hango.hango_backend.entity.PasswordResetOtp;
import com.hango.hango_backend.entity.Role;
import com.hango.hango_backend.entity.User;
import com.hango.hango_backend.repository.PasswordResetOtpRepository;
import com.hango.hango_backend.repository.RoleRepository;
import com.hango.hango_backend.repository.UserRepository;
import com.hango.hango_backend.security.UserDetailsImpl;
import com.hango.hango_backend.util.JwtUtils;

@ExtendWith(MockitoExtension.class)
class AuthServiceTest {

    @Mock
    private AuthenticationManager authenticationManager;
    @Mock
    private UserRepository userRepository;
    @Mock
    private RoleRepository roleRepository;
    @Mock
    private PasswordEncoder encoder;
    @Mock
    private JwtUtils jwtUtils;
    @Mock
    private CloudinaryService cloudinaryService;
    @Mock
    private GoogleIdTokenVerifier googleIdTokenVerifier;
    @Mock
    private PasswordResetOtpRepository passwordResetOtpRepository;
    @Mock
    private EmailService emailService;
    @Mock
    private Authentication authentication;

    @InjectMocks
    private AuthService authService;

    private LoginRequest loginRequest(String email, String password) {
        LoginRequest req = new LoginRequest();
        req.setEmail(email);
        req.setPassword(password);
        return req;
    }

    private User activeUser(String email, String status) {
        return User.builder()
                .id(1L)
                .email(email)
                .passwordHash("hashed")
                .fullName("Active User")
                .status(status)
                .isVerified(true)
                .roles(new HashSet<>(Set.of(Role.builder().id(1L).roleName("LEARNER").build())))
                .build();
    }

    // =================================================================
    // authenticateUser
    // =================================================================

    @Test
    void authenticateUserShouldReturnTokenAndUpdateLastLoginWhenCredentialsValidAndAccountActive() {
        User user = activeUser("active@example.com", "ACTIVE");
        UserDetailsImpl principal = new UserDetailsImpl(1L, "active@example.com", "Active User", "hashed",
                List.of(new SimpleGrantedAuthority("ROLE_LEARNER")));

        when(authenticationManager.authenticate(any())).thenReturn(authentication);
        when(authentication.getPrincipal()).thenReturn(principal);
        when(userRepository.findByEmail("active@example.com")).thenReturn(Optional.of(user));
        when(jwtUtils.generateJwtToken(authentication)).thenReturn("mock-jwt-token");
        when(userRepository.save(any(User.class))).thenAnswer(inv -> inv.getArgument(0));

        LoginResponse response = authService.authenticateUser(loginRequest("active@example.com", "correct-password"));

        assertEquals("mock-jwt-token", response.getToken());
        assertEquals("active@example.com", response.getEmail());
        assertEquals(List.of("ROLE_LEARNER"), response.getRoles());

        ArgumentCaptor<User> savedUser = ArgumentCaptor.forClass(User.class);
        verify(userRepository).save(savedUser.capture());
        assertNotNull(savedUser.getValue().getLastLoginAt());
    }

    @Test
    void authenticateUserShouldPropagateBadCredentialsExceptionOnWrongPassword() {
        when(authenticationManager.authenticate(any())).thenThrow(new BadCredentialsException("Bad credentials"));

        LoginRequest req = new LoginRequest();
        req.setEmail("active@example.com");
        req.setPassword("wrong-password");

        assertThrows(BadCredentialsException.class, () -> authService.authenticateUser(req));
        verify(userRepository, never()).save(any());
    }

    @Test
    void authenticateUserShouldRejectInactiveAccount() {
        User user = activeUser("inactive@example.com", "INACTIVE");
        UserDetailsImpl principal = new UserDetailsImpl(1L, "inactive@example.com", "Inactive User", "hashed",
                List.of(new SimpleGrantedAuthority("ROLE_LEARNER")));

        when(authenticationManager.authenticate(any())).thenReturn(authentication);
        when(authentication.getPrincipal()).thenReturn(principal);
        when(userRepository.findByEmail("inactive@example.com")).thenReturn(Optional.of(user));

        LoginRequest req = new LoginRequest();
        req.setEmail("inactive@example.com");
        req.setPassword("correct-password");

        IllegalArgumentException ex = assertThrows(IllegalArgumentException.class,
                () -> authService.authenticateUser(req));
        assertTrue(ex.getMessage().contains("deactivated"));
        verify(jwtUtils, never()).generateJwtToken(any());
        verify(userRepository, never()).save(any());
    }

    @Test
    void authenticateUserShouldRejectInactiveAccountCaseInsensitively() {
        User user = activeUser("inactive2@example.com", "inactive");
        UserDetailsImpl principal = new UserDetailsImpl(1L, "inactive2@example.com", "Inactive User", "hashed",
                List.of(new SimpleGrantedAuthority("ROLE_LEARNER")));

        when(authenticationManager.authenticate(any())).thenReturn(authentication);
        when(authentication.getPrincipal()).thenReturn(principal);
        when(userRepository.findByEmail("inactive2@example.com")).thenReturn(Optional.of(user));

        LoginRequest req = new LoginRequest();
        req.setEmail("inactive2@example.com");
        req.setPassword("correct-password");

        assertThrows(IllegalArgumentException.class, () -> authService.authenticateUser(req));
    }

    @Test
    void authenticateUserShouldCurrentlyAllowLoginForNonInactiveStatusSuchAsLocked() {
        User user = activeUser("locked@example.com", "LOCKED");
        UserDetailsImpl principal = new UserDetailsImpl(1L, "locked@example.com", "Locked User", "hashed",
                List.of(new SimpleGrantedAuthority("ROLE_LEARNER")));

        when(authenticationManager.authenticate(any())).thenReturn(authentication);
        when(authentication.getPrincipal()).thenReturn(principal);
        when(userRepository.findByEmail("locked@example.com")).thenReturn(Optional.of(user));
        when(jwtUtils.generateJwtToken(authentication)).thenReturn("mock-jwt-token");
        when(userRepository.save(any(User.class))).thenAnswer(inv -> inv.getArgument(0));

        LoginRequest req = new LoginRequest();
        req.setEmail("locked@example.com");
        req.setPassword("correct-password");

        LoginResponse response = assertDoesNotThrow(() -> authService.authenticateUser(req));
        assertEquals("mock-jwt-token", response.getToken());
    }

    @Test
    void authenticateUserShouldThrowUsernameNotFoundWhenUserMissingAfterAuthentication() {
        UserDetailsImpl principal = new UserDetailsImpl(1L, "ghost@example.com", "Ghost", "hashed",
                List.of(new SimpleGrantedAuthority("ROLE_LEARNER")));

        when(authenticationManager.authenticate(any())).thenReturn(authentication);
        when(authentication.getPrincipal()).thenReturn(principal);
        when(userRepository.findByEmail("ghost@example.com")).thenReturn(Optional.empty());

        LoginRequest req = new LoginRequest();
        req.setEmail("ghost@example.com");
        req.setPassword("any-password");

        assertThrows(UsernameNotFoundException.class, () -> authService.authenticateUser(req));
    }

    // =================================================================
    // registerUser
    // =================================================================

    private RegisterRequest registerRequest(String email, String password, String requestedRole) {
        RegisterRequest req = new RegisterRequest();
        req.setEmail(email);
        req.setPassword(password);
        req.setFullName("New User");
        req.setRole(requestedRole);
        return req;
    }

    @Test
    void registerUserShouldCreateLearnerAccountAndSendVerificationEmailOnHappyPath() {
        when(userRepository.existsByEmail("new@example.com")).thenReturn(false);
        when(roleRepository.findByRoleName("LEARNER"))
                .thenReturn(Optional.of(Role.builder().id(1L).roleName("LEARNER").build()));
        when(encoder.encode("pass1234")).thenReturn("ENCODED_HASH");
        when(userRepository.save(any(User.class))).thenAnswer(inv -> {
            User u = inv.getArgument(0);
            u.setId(42L);
            return u;
        });

        UserResponse response = authService.registerUser(registerRequest("new@example.com", "pass1234", null));

        assertEquals("new@example.com", response.getEmail());
        assertEquals(List.of("LEARNER"), response.getRoles());
        verify(emailService).sendVerificationEmail("new@example.com");

        ArgumentCaptor<User> savedUser = ArgumentCaptor.forClass(User.class);
        verify(userRepository).save(savedUser.capture());
        assertEquals("ENCODED_HASH", savedUser.getValue().getPasswordHash());
        assertNotEquals("pass1234", savedUser.getValue().getPasswordHash());
    }

    @Test
    void registerUserShouldRejectDuplicateEmail() {
        when(userRepository.existsByEmail("existing@example.com")).thenReturn(true);

        IllegalArgumentException ex = assertThrows(IllegalArgumentException.class,
                () -> authService.registerUser(registerRequest("existing@example.com", "pass1234", null)));
        assertTrue(ex.getMessage().contains("already in use"));
        verify(roleRepository, never()).findByRoleName(anyString());
        verify(userRepository, never()).save(any());
    }

    @Test
    void registerUserShouldCreateLearnerRoleWhenItDoesNotExistYet() {
        when(userRepository.existsByEmail("new2@example.com")).thenReturn(false);
        when(roleRepository.findByRoleName("LEARNER")).thenReturn(Optional.empty());
        when(roleRepository.save(any(Role.class))).thenAnswer(inv -> inv.getArgument(0));
        when(encoder.encode(anyString())).thenReturn("ENCODED_HASH");
        when(userRepository.save(any(User.class))).thenAnswer(inv -> inv.getArgument(0));

        authService.registerUser(registerRequest("new2@example.com", "pass1234", null));

        ArgumentCaptor<Role> savedRole = ArgumentCaptor.forClass(Role.class);
        verify(roleRepository).save(savedRole.capture());
        assertEquals("LEARNER", savedRole.getValue().getRoleName());
    }

    @Test
    void registerUserShouldAllowSelfRegistrationAsTrainerWhenRoleRequested() {
        when(userRepository.existsByEmail("new3@example.com")).thenReturn(false);
        when(roleRepository.findByRoleName("TRAINER"))
                .thenReturn(Optional.of(Role.builder().id(2L).roleName("TRAINER").build()));
        when(encoder.encode(anyString())).thenReturn("ENCODED_HASH");
        when(userRepository.save(any(User.class))).thenAnswer(inv -> inv.getArgument(0));

        UserResponse response = authService.registerUser(registerRequest("new3@example.com", "pass1234", "TRAINER"));

        assertEquals(List.of("TRAINER"), response.getRoles());
        verify(roleRepository, never()).findByRoleName("LEARNER");
    }

    @Test
    void registerUserShouldRejectRoleOutsideLearnerTrainerWhitelist() {
        when(userRepository.existsByEmail("new5@example.com")).thenReturn(false);

        IllegalArgumentException ex = assertThrows(IllegalArgumentException.class,
                () -> authService.registerUser(registerRequest("new5@example.com", "pass1234", "ADMINISTRATOR")));
        assertTrue(ex.getMessage().contains("Invalid registration role"));
        verify(userRepository, never()).save(any());
    }

    @Test
    void registerUserShouldStillSucceedWhenVerificationEmailDispatchFails() {
        when(userRepository.existsByEmail("new4@example.com")).thenReturn(false);
        when(roleRepository.findByRoleName("LEARNER"))
                .thenReturn(Optional.of(Role.builder().id(1L).roleName("LEARNER").build()));
        when(encoder.encode(anyString())).thenReturn("ENCODED_HASH");
        when(userRepository.save(any(User.class))).thenAnswer(inv -> inv.getArgument(0));
        doThrow(new RuntimeException("SMTP down")).when(emailService).sendVerificationEmail("new4@example.com");

        UserResponse response = assertDoesNotThrow(
                () -> authService.registerUser(registerRequest("new4@example.com", "pass1234", null)));
        assertEquals("new4@example.com", response.getEmail());
    }

    // =================================================================
    // createUserByAdmin
    // =================================================================

    @Test
    void createUserByAdminShouldRejectDuplicateEmail() {
        when(userRepository.existsByEmail("existing@example.com")).thenReturn(true);

        IllegalArgumentException ex = assertThrows(IllegalArgumentException.class,
                () -> authService.createUserByAdmin(registerRequest("existing@example.com", "pass1234", "TRAINER")));
        assertTrue(ex.getMessage().contains("already in use"));
        verify(userRepository, never()).save(any());
    }

    @Test
    void createUserByAdminShouldDefaultToTrainerRoleWhenNoneRequested() {
        when(userRepository.existsByEmail("cm1@example.com")).thenReturn(false);
        when(roleRepository.findByRoleName("TRAINER"))
                .thenReturn(Optional.of(Role.builder().id(2L).roleName("TRAINER").build()));
        when(encoder.encode(anyString())).thenReturn("ENCODED_HASH");
        when(userRepository.save(any(User.class))).thenAnswer(inv -> inv.getArgument(0));

        UserResponse response = authService.createUserByAdmin(registerRequest("cm1@example.com", "pass1234", null));

        assertEquals(List.of("TRAINER"), response.getRoles());
    }

    @Test
    void createUserByAdminShouldAllowCreatingTrainerLeadRole() {
        when(userRepository.existsByEmail("cm2@example.com")).thenReturn(false);
        when(roleRepository.findByRoleName("TRAINER_LEAD"))
                .thenReturn(Optional.of(Role.builder().id(3L).roleName("TRAINER_LEAD").build()));
        when(encoder.encode(anyString())).thenReturn("ENCODED_HASH");
        when(userRepository.save(any(User.class))).thenAnswer(inv -> inv.getArgument(0));

        UserResponse response = authService.createUserByAdmin(registerRequest("cm2@example.com", "pass1234", "TRAINER_LEAD"));

        assertEquals(List.of("TRAINER_LEAD"), response.getRoles());
    }

    @Test
    void createUserByAdminShouldNormalizeAdminAliasToAdministrator() {
        when(userRepository.existsByEmail("admin2@example.com")).thenReturn(false);
        when(roleRepository.findByRoleName("ADMINISTRATOR"))
                .thenReturn(Optional.of(Role.builder().id(4L).roleName("ADMINISTRATOR").build()));
        when(encoder.encode(anyString())).thenReturn("ENCODED_HASH");
        when(userRepository.save(any(User.class))).thenAnswer(inv -> inv.getArgument(0));

        UserResponse response = authService.createUserByAdmin(registerRequest("admin2@example.com", "pass1234", "admin"));

        assertEquals(List.of("ADMINISTRATOR"), response.getRoles());
    }

    @Test
    void createUserByAdminShouldRejectRoleOutsideWhitelistInsteadOfSilentlyCreatingGarbageRole() {
        // Regression test: previously any non-empty string was accepted and, if the role didn't already
        // exist, silently auto-created a new garbage row in the roles table (e.g. a typo'd role name).
        when(userRepository.existsByEmail("typo@example.com")).thenReturn(false);

        IllegalArgumentException ex = assertThrows(IllegalArgumentException.class,
                () -> authService.createUserByAdmin(registerRequest("typo@example.com", "pass1234", "TRANIER")));
        assertTrue(ex.getMessage().contains("Invalid role"));
        verify(roleRepository, never()).findByRoleName(anyString());
        verify(roleRepository, never()).save(any());
        verify(userRepository, never()).save(any());
    }

    @Test
    void createUserByAdminShouldMarkAccountVerifiedAndActiveByDefault() {
        when(userRepository.existsByEmail("cm3@example.com")).thenReturn(false);
        when(roleRepository.findByRoleName("TRAINER"))
                .thenReturn(Optional.of(Role.builder().id(2L).roleName("TRAINER").build()));
        when(encoder.encode(anyString())).thenReturn("ENCODED_HASH");
        when(userRepository.save(any(User.class))).thenAnswer(inv -> inv.getArgument(0));

        authService.createUserByAdmin(registerRequest("cm3@example.com", "pass1234", "TRAINER"));

        ArgumentCaptor<User> savedUser = ArgumentCaptor.forClass(User.class);
        verify(userRepository).save(savedUser.capture());
        assertTrue(savedUser.getValue().getIsVerified());
        assertEquals("ACTIVE", savedUser.getValue().getStatus());
    }

    // =================================================================
    // googleLogin
    // =================================================================

    private GoogleIdToken mockGoogleIdToken(String email, String name, String picture) {
        GoogleIdToken.Payload payload = new GoogleIdToken.Payload();
        payload.setEmail(email);
        if (name != null) {
            payload.set("name", name);
        }
        if (picture != null) {
            payload.set("picture", picture);
        }

        return new GoogleIdToken(new GoogleIdToken.Header(), payload, new byte[0], new byte[0]);
    }

    @Test
    void googleLoginShouldJitProvisionLearnerAccountOnFirstSignIn() throws Exception {
        when(googleIdTokenVerifier.verify("valid-google-token"))
                .thenReturn(mockGoogleIdToken("newgoogleuser@example.com", "Google User Name", "https://google.example/pic.png"));
        when(userRepository.findByEmail("newgoogleuser@example.com")).thenReturn(Optional.empty());
        when(roleRepository.findByRoleName("LEARNER"))
                .thenReturn(Optional.of(Role.builder().id(1L).roleName("LEARNER").build()));
        when(encoder.encode(anyString())).thenReturn("RANDOM_ENCODED");
        when(userRepository.save(any(User.class))).thenAnswer(inv -> {
            User u = inv.getArgument(0);
            if (u.getId() == null) {
                u.setId(55L);
            }
            return u;
        });
        when(jwtUtils.generateJwtTokenFromUsername("newgoogleuser@example.com")).thenReturn("google-jwt-token");

        GoogleLoginRequest req = new GoogleLoginRequest();
        req.setIdToken("valid-google-token");
        LoginResponse response = authService.googleLogin(req);

        assertEquals("google-jwt-token", response.getToken());
        assertEquals("newgoogleuser@example.com", response.getEmail());
        assertEquals("Google User Name", response.getFullName());
        assertEquals(List.of("LEARNER"), response.getRoles());

        ArgumentCaptor<User> savedUser = ArgumentCaptor.forClass(User.class);
        verify(userRepository, org.mockito.Mockito.atLeastOnce()).save(savedUser.capture());
        assertTrue(savedUser.getValue().getIsVerified());
    }

    @Test
    void googleLoginShouldReuseExistingAccountWithoutCreatingDuplicateRole() throws Exception {
        User existing = activeUser("existinggoogleuser@example.com", "ACTIVE");
        when(googleIdTokenVerifier.verify("valid-google-token"))
                .thenReturn(mockGoogleIdToken("existinggoogleuser@example.com", "Existing User", null));
        when(userRepository.findByEmail("existinggoogleuser@example.com")).thenReturn(Optional.of(existing));
        when(userRepository.save(any(User.class))).thenAnswer(inv -> inv.getArgument(0));
        when(jwtUtils.generateJwtTokenFromUsername("existinggoogleuser@example.com")).thenReturn("google-jwt-token");

        GoogleLoginRequest req = new GoogleLoginRequest();
        req.setIdToken("valid-google-token");
        LoginResponse response = authService.googleLogin(req);

        assertEquals("existinggoogleuser@example.com", response.getEmail());
        verify(roleRepository, never()).findByRoleName(anyString());
    }

    @Test
    void googleLoginShouldRejectInactiveAccount() throws Exception {
        User inactive = activeUser("inactivegoogleuser@example.com", "INACTIVE");
        when(googleIdTokenVerifier.verify("valid-google-token"))
                .thenReturn(mockGoogleIdToken("inactivegoogleuser@example.com", "Inactive User", null));
        when(userRepository.findByEmail("inactivegoogleuser@example.com")).thenReturn(Optional.of(inactive));

        GoogleLoginRequest req = new GoogleLoginRequest();
        req.setIdToken("valid-google-token");

        IllegalArgumentException ex = assertThrows(IllegalArgumentException.class, () -> authService.googleLogin(req));
        assertTrue(ex.getMessage().contains("Google authentication failed"));
        verify(jwtUtils, never()).generateJwtTokenFromUsername(anyString());
    }

    @Test
    void googleLoginShouldWrapVerificationFailureAsIllegalArgumentExceptionForMalformedToken() throws Exception {
        when(googleIdTokenVerifier.verify("not-a-real-jwt")).thenReturn(null);

        GoogleLoginRequest req = new GoogleLoginRequest();
        req.setIdToken("not-a-real-jwt");

        IllegalArgumentException ex = assertThrows(IllegalArgumentException.class, () -> authService.googleLogin(req));
        assertTrue(ex.getMessage().startsWith("Google authentication failed"));
        verify(userRepository, never()).save(any());
    }

    // =================================================================
    // forgotPassword
    // =================================================================

    @Test
    void forgotPasswordShouldRejectUnregisteredEmail() {
        when(userRepository.existsByEmail("unknown@example.com")).thenReturn(false);

        ForgotPasswordRequest req = new ForgotPasswordRequest();
        req.setEmail("unknown@example.com");

        assertThrows(IllegalArgumentException.class, () -> authService.forgotPassword(req));
        verify(passwordResetOtpRepository, never()).save(any());
    }

    @Test
    void forgotPasswordShouldReplaceExistingOtpAndSendSixDigitCodeByEmail() {
        when(userRepository.existsByEmail("known@example.com")).thenReturn(true);
        when(passwordResetOtpRepository.save(any(PasswordResetOtp.class))).thenAnswer(inv -> inv.getArgument(0));

        ForgotPasswordRequest req = new ForgotPasswordRequest();
        req.setEmail("known@example.com");
        authService.forgotPassword(req);

        verify(passwordResetOtpRepository).deleteByEmail("known@example.com");

        ArgumentCaptor<PasswordResetOtp> savedOtp = ArgumentCaptor.forClass(PasswordResetOtp.class);
        verify(passwordResetOtpRepository).save(savedOtp.capture());
        String otpCode = savedOtp.getValue().getOtpCode();
        assertEquals(6, otpCode.length());
        assertTrue(otpCode.chars().allMatch(Character::isDigit));
        assertTrue(savedOtp.getValue().getExpiryTime().isAfter(LocalDateTime.now().plusMinutes(4)));
        assertTrue(savedOtp.getValue().getExpiryTime().isBefore(LocalDateTime.now().plusMinutes(6)));

        verify(emailService).sendOtpEmail(eq("known@example.com"), eq(otpCode));
    }

    // =================================================================
    // verifyOtp
    // =================================================================

    @Test
    void verifyOtpShouldRejectWhenNoMatchingOtpExists() {
        when(passwordResetOtpRepository.findByEmailAndOtpCode("known@example.com", "000000"))
                .thenReturn(Optional.empty());

        VerifyOtpRequest req = new VerifyOtpRequest();
        req.setEmail("known@example.com");
        req.setOtpCode("000000");

        IllegalArgumentException ex = assertThrows(IllegalArgumentException.class, () -> authService.verifyOtp(req));
        assertTrue(ex.getMessage().contains("Invalid OTP"));
    }

    @Test
    void verifyOtpShouldDeleteAndRejectExpiredOtp() {
        PasswordResetOtp expired = PasswordResetOtp.builder()
                .id(1L).email("known@example.com").otpCode("123456")
                .expiryTime(LocalDateTime.now().minusMinutes(1))
                .build();
        when(passwordResetOtpRepository.findByEmailAndOtpCode("known@example.com", "123456"))
                .thenReturn(Optional.of(expired));

        VerifyOtpRequest req = new VerifyOtpRequest();
        req.setEmail("known@example.com");
        req.setOtpCode("123456");

        IllegalArgumentException ex = assertThrows(IllegalArgumentException.class, () -> authService.verifyOtp(req));
        assertTrue(ex.getMessage().contains("expired"));
        verify(passwordResetOtpRepository).delete(expired);
    }

    @Test
    void verifyOtpShouldAcceptValidUnexpiredOtpWithoutDeletingIt() {
        PasswordResetOtp valid = PasswordResetOtp.builder()
                .id(1L).email("known@example.com").otpCode("123456")
                .expiryTime(LocalDateTime.now().plusMinutes(3))
                .build();
        when(passwordResetOtpRepository.findByEmailAndOtpCode("known@example.com", "123456"))
                .thenReturn(Optional.of(valid));

        VerifyOtpRequest req = new VerifyOtpRequest();
        req.setEmail("known@example.com");
        req.setOtpCode("123456");

        assertDoesNotThrow(() -> authService.verifyOtp(req));
        verify(passwordResetOtpRepository, never()).delete(any());
    }

    // =================================================================
    // resetPassword
    // =================================================================

    @Test
    void resetPasswordShouldThrowWhenUserNotFound() {
        when(userRepository.findByEmail("unknown@example.com")).thenReturn(Optional.empty());

        ResetPasswordRequest req = new ResetPasswordRequest();
        req.setEmail("unknown@example.com");
        req.setNewPassword("newPass123");

        assertThrows(UsernameNotFoundException.class, () -> authService.resetPassword(req));
    }

    @Test
    void resetPasswordShouldEncodeNewPasswordAndClearOtpsOnSuccess() {
        User user = activeUser("known@example.com", "ACTIVE");
        when(userRepository.findByEmail("known@example.com")).thenReturn(Optional.of(user));
        when(encoder.encode("newPass123")).thenReturn("NEW_ENCODED_HASH");

        ResetPasswordRequest req = new ResetPasswordRequest();
        req.setEmail("known@example.com");
        req.setNewPassword("newPass123");
        authService.resetPassword(req);

        assertEquals("NEW_ENCODED_HASH", user.getPasswordHash());
        verify(userRepository).save(user);
        verify(passwordResetOtpRepository).deleteByEmail("known@example.com");
    }

    // =================================================================
    // verifyAccount
    // =================================================================

    @Test
    void verifyAccountShouldThrowWhenUserNotFound() {
        when(userRepository.findByEmail("unknown@example.com")).thenReturn(Optional.empty());
        assertThrows(UsernameNotFoundException.class, () -> authService.verifyAccount("unknown@example.com"));
    }

    @Test
    void verifyAccountShouldMarkUserVerified() {
        User user = activeUser("pending@example.com", "ACTIVE");
        user.setIsVerified(false);
        when(userRepository.findByEmail("pending@example.com")).thenReturn(Optional.of(user));

        authService.verifyAccount("pending@example.com");

        assertTrue(user.getIsVerified());
        verify(userRepository).save(user);
    }

    // =================================================================
    // resendVerificationEmail
    // =================================================================

    @Test
    void resendVerificationEmailShouldThrowWhenUserNotFound() {
        when(userRepository.findByEmail("unknown@example.com")).thenReturn(Optional.empty());
        assertThrows(UsernameNotFoundException.class,
                () -> authService.resendVerificationEmail("unknown@example.com"));
    }

    @Test
    void resendVerificationEmailShouldRejectAlreadyVerifiedAccount() {
        User user = activeUser("verified@example.com", "ACTIVE");
        user.setIsVerified(true);
        when(userRepository.findByEmail("verified@example.com")).thenReturn(Optional.of(user));

        IllegalArgumentException ex = assertThrows(IllegalArgumentException.class,
                () -> authService.resendVerificationEmail("verified@example.com"));
        assertTrue(ex.getMessage().contains("already verified"));
    }

    @Test
    void resendVerificationEmailShouldDispatchEmailForUnverifiedAccount() {
        User user = activeUser("pending2@example.com", "ACTIVE");
        user.setIsVerified(false);
        when(userRepository.findByEmail("pending2@example.com")).thenReturn(Optional.of(user));

        assertDoesNotThrow(() -> authService.resendVerificationEmail("pending2@example.com"));
        verify(emailService).sendVerificationEmail("pending2@example.com");
    }

    @Test
    void resendVerificationEmailShouldRethrowWhenEmailDispatchFails() {
        User user = activeUser("pending3@example.com", "ACTIVE");
        user.setIsVerified(false);
        when(userRepository.findByEmail("pending3@example.com")).thenReturn(Optional.of(user));
        doThrow(new RuntimeException("SMTP down")).when(emailService).sendVerificationEmail("pending3@example.com");

        assertThrows(RuntimeException.class, () -> authService.resendVerificationEmail("pending3@example.com"));
    }

    // =================================================================
    // isAccountVerified
    // =================================================================

    @Test
    void isAccountVerifiedShouldReturnFalseWhenUserNotFound() {
        when(userRepository.findByEmail("unknown@example.com")).thenReturn(Optional.empty());
        assertFalse(authService.isAccountVerified("unknown@example.com"));
    }

    @Test
    void isAccountVerifiedShouldReturnTrueWhenUserVerified() {
        User user = activeUser("verified@example.com", "ACTIVE");
        user.setIsVerified(true);
        when(userRepository.findByEmail("verified@example.com")).thenReturn(Optional.of(user));
        assertTrue(authService.isAccountVerified("verified@example.com"));
    }

    @Test
    void isAccountVerifiedShouldReturnFalseWhenFlagIsNull() {
        User user = activeUser("nullflag@example.com", "ACTIVE");
        user.setIsVerified(null);
        when(userRepository.findByEmail("nullflag@example.com")).thenReturn(Optional.of(user));
        assertFalse(authService.isAccountVerified("nullflag@example.com"));
    }

    // =================================================================
    // getUserProfile
    // =================================================================

    @Test
    void getUserProfileShouldThrowWhenUserNotFound() {
        when(userRepository.findByEmail("unknown@example.com")).thenReturn(Optional.empty());
        assertThrows(UsernameNotFoundException.class, () -> authService.getUserProfile("unknown@example.com"));
    }

    @Test
    void getUserProfileShouldReturnMappedUserResponse() {
        User user = activeUser("known@example.com", "ACTIVE");
        when(userRepository.findByEmail("known@example.com")).thenReturn(Optional.of(user));

        UserResponse response = authService.getUserProfile("known@example.com");

        assertEquals("known@example.com", response.getEmail());
        assertEquals(List.of("LEARNER"), response.getRoles());
    }

    // =================================================================
    // getUserById
    // =================================================================

    @Test
    void getUserByIdShouldThrowWhenUserNotFound() {
        when(userRepository.findById(99L)).thenReturn(Optional.empty());
        assertThrows(UsernameNotFoundException.class, () -> authService.getUserById(99L));
    }

    @Test
    void getUserByIdShouldReturnMappedUserResponse() {
        User user = activeUser("known@example.com", "ACTIVE");
        when(userRepository.findById(1L)).thenReturn(Optional.of(user));

        UserResponse response = authService.getUserById(1L);

        assertEquals(1L, response.getId());
        assertEquals("known@example.com", response.getEmail());
    }

    // =================================================================
    // updateProfile
    // =================================================================

    @Test
    void updateProfileShouldThrowWhenUserNotFound() {
        when(userRepository.findByEmail("unknown@example.com")).thenReturn(Optional.empty());
        assertThrows(UsernameNotFoundException.class,
                () -> authService.updateProfile("unknown@example.com", new ProfileUpdateRequest()));
    }

    @Test
    void updateProfileShouldOnlyChangeFieldsPresentOnRequest() {
        User user = activeUser("known@example.com", "ACTIVE");
        user.setPhoneNumber("0000000000");
        when(userRepository.findByEmail("known@example.com")).thenReturn(Optional.of(user));
        when(userRepository.save(any(User.class))).thenAnswer(inv -> inv.getArgument(0));

        ProfileUpdateRequest req = new ProfileUpdateRequest();
        req.setFullName("Updated Name");

        authService.updateProfile("known@example.com", req);

        assertEquals("Updated Name", user.getFullName());
        assertEquals("0000000000", user.getPhoneNumber());
    }

    @Test
    void updateProfileShouldResetIsVerifiedWhenEmailChanges() {
        User user = activeUser("known@example.com", "ACTIVE");
        user.setIsVerified(true);
        when(userRepository.findByEmail("known@example.com")).thenReturn(Optional.of(user));
        when(userRepository.existsByEmail("new@example.com")).thenReturn(false);
        when(userRepository.save(any(User.class))).thenAnswer(inv -> inv.getArgument(0));

        ProfileUpdateRequest req = new ProfileUpdateRequest();
        req.setEmail("new@example.com");
        authService.updateProfile("known@example.com", req);

        assertEquals("new@example.com", user.getEmail());
        assertFalse(user.getIsVerified());
    }

    @Test
    void updateProfileShouldRejectUsernameAlreadyTaken() {
        User user = activeUser("known@example.com", "ACTIVE");
        user.setUsername("olduser");
        when(userRepository.findByEmail("known@example.com")).thenReturn(Optional.of(user));
        when(userRepository.existsByUsername("takenuser")).thenReturn(true);

        ProfileUpdateRequest req = new ProfileUpdateRequest();
        req.setUsername("takenuser");

        IllegalArgumentException ex = assertThrows(IllegalArgumentException.class,
                () -> authService.updateProfile("known@example.com", req));
        assertTrue(ex.getMessage().contains("Username is already in use"));
        verify(userRepository, never()).save(any());
    }

    @Test
    void updateProfileShouldNotCheckUsernameUniquenessWhenUnchanged() {
        User user = activeUser("known@example.com", "ACTIVE");
        user.setUsername("sameuser");
        when(userRepository.findByEmail("known@example.com")).thenReturn(Optional.of(user));
        when(userRepository.save(any(User.class))).thenAnswer(inv -> inv.getArgument(0));

        ProfileUpdateRequest req = new ProfileUpdateRequest();
        req.setUsername("sameuser");

        assertDoesNotThrow(() -> authService.updateProfile("known@example.com", req));
        verify(userRepository, never()).existsByUsername(anyString());
    }

    @Test
    void updateProfileShouldRejectEmailAlreadyTaken() {
        User user = activeUser("known@example.com", "ACTIVE");
        when(userRepository.findByEmail("known@example.com")).thenReturn(Optional.of(user));
        when(userRepository.existsByEmail("taken@example.com")).thenReturn(true);

        ProfileUpdateRequest req = new ProfileUpdateRequest();
        req.setEmail("taken@example.com");

        IllegalArgumentException ex = assertThrows(IllegalArgumentException.class,
                () -> authService.updateProfile("known@example.com", req));
        assertTrue(ex.getMessage().contains("Email is already in use"));
        verify(userRepository, never()).save(any());
    }

    // =================================================================
    // changePassword
    // =================================================================

    @Test
    void changePasswordShouldThrowWhenUserNotFound() {
        when(userRepository.findByEmail("unknown@example.com")).thenReturn(Optional.empty());
        assertThrows(UsernameNotFoundException.class,
                () -> authService.changePassword("unknown@example.com", new ChangePasswordRequest()));
    }

    @Test
    void changePasswordShouldRejectIncorrectCurrentPassword() {
        User user = activeUser("known@example.com", "ACTIVE");
        when(userRepository.findByEmail("known@example.com")).thenReturn(Optional.of(user));
        when(encoder.matches("wrongCurrent", "hashed")).thenReturn(false);

        ChangePasswordRequest req = new ChangePasswordRequest();
        req.setCurrentPassword("wrongCurrent");
        req.setNewPassword("newPass123");

        IllegalArgumentException ex = assertThrows(IllegalArgumentException.class,
                () -> authService.changePassword("known@example.com", req));
        assertTrue(ex.getMessage().contains("Incorrect current password"));
        verify(userRepository, never()).save(any());
    }

    @Test
    void changePasswordShouldEncodeAndSaveNewPasswordWhenCurrentPasswordMatches() {
        User user = activeUser("known@example.com", "ACTIVE");
        when(userRepository.findByEmail("known@example.com")).thenReturn(Optional.of(user));
        when(encoder.matches("correctCurrent", "hashed")).thenReturn(true);
        when(encoder.encode("newPass123")).thenReturn("NEW_ENCODED_HASH");

        ChangePasswordRequest req = new ChangePasswordRequest();
        req.setCurrentPassword("correctCurrent");
        req.setNewPassword("newPass123");
        authService.changePassword("known@example.com", req);

        assertEquals("NEW_ENCODED_HASH", user.getPasswordHash());
        verify(userRepository).save(user);
    }

    // =================================================================
    // updateAvatar
    // =================================================================

    private MultipartFile validAvatarFile() {
        MultipartFile file = mock(MultipartFile.class);
        when(file.isEmpty()).thenReturn(false);
        when(file.getSize()).thenReturn(1024L * 500); // 500KB
        when(file.getContentType()).thenReturn("image/png");
        return file;
    }

    @Test
    void updateAvatarShouldThrowWhenUserNotFound() {
        when(userRepository.findByEmail("unknown@example.com")).thenReturn(Optional.empty());
        MultipartFile file = mock(MultipartFile.class);
        assertThrows(UsernameNotFoundException.class, () -> authService.updateAvatar("unknown@example.com", file));
    }

    @Test
    void updateAvatarShouldRejectEmptyFile() {
        User user = activeUser("known@example.com", "ACTIVE");
        when(userRepository.findByEmail("known@example.com")).thenReturn(Optional.of(user));
        MultipartFile file = mock(MultipartFile.class);
        when(file.isEmpty()).thenReturn(true);

        IllegalArgumentException ex = assertThrows(IllegalArgumentException.class,
                () -> authService.updateAvatar("known@example.com", file));
        assertTrue(ex.getMessage().contains("required"));
        verify(userRepository, never()).save(any());
    }

    @Test
    void updateAvatarShouldUploadToCloudinaryAndSaveReturnedUrl() throws Exception {
        User user = activeUser("known@example.com", "ACTIVE");
        when(userRepository.findByEmail("known@example.com")).thenReturn(Optional.of(user));
        MultipartFile file = validAvatarFile();
        when(cloudinaryService.uploadImage(file)).thenReturn("https://cloudinary.example/avatar.png");
        when(userRepository.save(any(User.class))).thenAnswer(inv -> inv.getArgument(0));

        authService.updateAvatar("known@example.com", file);

        assertEquals("https://cloudinary.example/avatar.png", user.getAvatarUrl());
        verify(userRepository).save(user);
    }

    @Test
    void updateAvatarShouldPropagateIOExceptionFromCloudinaryUpload() throws Exception {
        User user = activeUser("known@example.com", "ACTIVE");
        when(userRepository.findByEmail("known@example.com")).thenReturn(Optional.of(user));
        MultipartFile file = validAvatarFile();
        when(cloudinaryService.uploadImage(file)).thenThrow(new java.io.IOException("Cloudinary unreachable"));

        assertThrows(java.io.IOException.class, () -> authService.updateAvatar("known@example.com", file));
        verify(userRepository, never()).save(any());
    }

    @Test
    void updateAvatarShouldRejectFileLargerThan2MB() {
        User user = activeUser("known@example.com", "ACTIVE");
        when(userRepository.findByEmail("known@example.com")).thenReturn(Optional.of(user));
        MultipartFile file = mock(MultipartFile.class);
        when(file.isEmpty()).thenReturn(false);
        when(file.getSize()).thenReturn(3L * 1024 * 1024); // 3MB

        IllegalArgumentException ex = assertThrows(IllegalArgumentException.class,
                () -> authService.updateAvatar("known@example.com", file));
        assertTrue(ex.getMessage().contains("2MB"));
        verify(userRepository, never()).save(any());
    }

    @Test
    void updateAvatarShouldRejectUnsupportedContentType() {
        User user = activeUser("known@example.com", "ACTIVE");
        when(userRepository.findByEmail("known@example.com")).thenReturn(Optional.of(user));
        MultipartFile file = mock(MultipartFile.class);
        when(file.isEmpty()).thenReturn(false);
        when(file.getSize()).thenReturn(1024L);
        when(file.getContentType()).thenReturn("application/pdf");

        IllegalArgumentException ex = assertThrows(IllegalArgumentException.class,
                () -> authService.updateAvatar("known@example.com", file));
        assertTrue(ex.getMessage().contains("jpg"));
        verify(userRepository, never()).save(any());
    }
}
