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
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;
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
import static org.mockito.Mockito.times;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.http.HttpStatus;
import org.springframework.security.authentication.AuthenticationManager;
import org.springframework.security.authentication.BadCredentialsException;
import org.springframework.security.core.Authentication;
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
import com.hango.hango_backend.dto.TokenRefreshResponse;
import com.hango.hango_backend.dto.UserResponse;
import com.hango.hango_backend.dto.VerifyOtpRequest;
import com.hango.hango_backend.entity.PasswordResetOtp;
import com.hango.hango_backend.entity.RefreshToken;
import com.hango.hango_backend.entity.Role;
import com.hango.hango_backend.entity.User;
import com.hango.hango_backend.exception.ApiException;
import com.hango.hango_backend.repository.PasswordResetOtpRepository;
import com.hango.hango_backend.repository.RefreshTokenRepository;
import com.hango.hango_backend.repository.RoleRepository;
import com.hango.hango_backend.repository.UserRepository;
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
    private RefreshTokenRepository refreshTokenRepository;
    @Mock
    private AuditLogService auditLogService;
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

    private User activeVerifiedUser(String email, String status) {
        return User.builder()
                .id(1L)
                .email(email)
                .passwordHash("hashed")
                .fullName("Active User")
                .status(status)
                .isVerified(true)
                .failedLoginAttempts(0)
                .roles(new HashSet<>(Set.of(Role.builder().id(1L).roleName("LEARNER").build())))
                .build();
    }

    private ApiException assertApiException(HttpStatus expectedStatus, Runnable action) {
        ApiException ex = assertThrows(ApiException.class, action::run);
        assertEquals(expectedStatus, ex.getStatus());
        return ex;
    }

    // =================================================================
    // authenticateUser
    // =================================================================
    @Test
    void authenticateUserShouldReturnTokensAndUpdateLastLoginWhenCredentialsValidAndAccountActiveAndVerified() {
        User user = activeVerifiedUser("active@example.com", "ACTIVE");

        when(userRepository.findByEmail("active@example.com")).thenReturn(Optional.of(user));
        when(authenticationManager.authenticate(any())).thenReturn(authentication);
        when(jwtUtils.generateJwtTokenFromUsername("active@example.com")).thenReturn("mock-jwt-token");
        when(jwtUtils.generateOpaqueRefreshToken()).thenReturn("raw-refresh-token");
        when(jwtUtils.hashToken("raw-refresh-token")).thenReturn("hashed-refresh-token");
        when(jwtUtils.getRefreshExpirationMs()).thenReturn(2_592_000_000L);
        when(userRepository.save(any(User.class))).thenAnswer(inv -> inv.getArgument(0));

        LoginResponse response = authService.authenticateUser(loginRequest("active@example.com", "correct-password"));

        assertEquals("mock-jwt-token", response.getToken());
        assertEquals("raw-refresh-token", response.getRefreshToken());
        assertEquals("active@example.com", response.getEmail());
        assertEquals(List.of("LEARNER", "ROLE_LEARNER"), response.getRoles());

        ArgumentCaptor<User> savedUser = ArgumentCaptor.forClass(User.class);
        verify(userRepository).save(savedUser.capture());
        assertNotNull(savedUser.getValue().getLastLoginAt());
        assertEquals(0, savedUser.getValue().getFailedLoginAttempts());

        verify(refreshTokenRepository).save(any(RefreshToken.class));
        verify(auditLogService, times(1)).log(any(), anyString(), any(), any());
    }

    @Test
    void authenticateUserShouldNormalizeEmailCasingAndWhitespace() {
        User user = activeVerifiedUser("active@example.com", "ACTIVE");
        when(userRepository.findByEmail("active@example.com")).thenReturn(Optional.of(user));
        when(authenticationManager.authenticate(any())).thenReturn(authentication);
        when(jwtUtils.generateJwtTokenFromUsername(anyString())).thenReturn("mock-jwt-token");
        when(jwtUtils.generateOpaqueRefreshToken()).thenReturn("raw-refresh-token");
        when(jwtUtils.hashToken(anyString())).thenReturn("hashed");
        when(jwtUtils.getRefreshExpirationMs()).thenReturn(2_592_000_000L);
        when(userRepository.save(any(User.class))).thenAnswer(inv -> inv.getArgument(0));

        authService.authenticateUser(loginRequest("  Active@Example.com  ", "correct-password"));

        verify(userRepository).findByEmail("active@example.com");
    }

    @Test
    void authenticateUserShouldRejectUnknownEmailWithGenericMessage() {
        when(userRepository.findByEmail("ghost@example.com")).thenReturn(Optional.empty());

        assertApiException(HttpStatus.UNAUTHORIZED,
                () -> authService.authenticateUser(loginRequest("ghost@example.com", "any-password")));

        verify(authenticationManager, never()).authenticate(any());
        verify(auditLogService).log(any(), anyString(), any(), any());
    }

    @Test
    void authenticateUserShouldStillRejectUnknownEmailWhenAuditLoggingItselfFails() {
        // Regression test: a failure inside the REQUIRES_NEW audit-log transaction
        // must never surface as (or replace) the caller's real error -- see the
        // comment on AuthService.logAudit().
        when(userRepository.findByEmail("ghost@example.com")).thenReturn(Optional.empty());
        doThrow(new org.springframework.transaction.UnexpectedRollbackException("Transaction silently rolled back"))
                .when(auditLogService).log(any(), anyString(), any(), any());

        ApiException ex = assertApiException(HttpStatus.UNAUTHORIZED,
                () -> authService.authenticateUser(loginRequest("ghost@example.com", "any-password")));
        assertEquals("Invalid email or password.", ex.getMessage());
    }

    @Test
    void authenticateUserShouldRejectBadCredentialsAndIncrementFailedAttempts() {
        User user = activeVerifiedUser("active@example.com", "ACTIVE");
        user.setFailedLoginAttempts(2);
        when(userRepository.findByEmail("active@example.com")).thenReturn(Optional.of(user));
        when(authenticationManager.authenticate(any())).thenThrow(new BadCredentialsException("Bad credentials"));

        assertApiException(HttpStatus.UNAUTHORIZED,
                () -> authService.authenticateUser(loginRequest("active@example.com", "wrong-password")));

        ArgumentCaptor<User> savedUser = ArgumentCaptor.forClass(User.class);
        verify(userRepository).save(savedUser.capture());
        assertEquals(3, savedUser.getValue().getFailedLoginAttempts());
        assertNull(savedUser.getValue().getLockedUntil());
        verify(jwtUtils, never()).generateJwtTokenFromUsername(anyString());
    }

    @Test
    void authenticateUserShouldLockAccountAfterFifthFailedAttempt() {
        User user = activeVerifiedUser("active@example.com", "ACTIVE");
        user.setFailedLoginAttempts(4);
        when(userRepository.findByEmail("active@example.com")).thenReturn(Optional.of(user));
        when(authenticationManager.authenticate(any())).thenThrow(new BadCredentialsException("Bad credentials"));

        assertApiException(HttpStatus.UNAUTHORIZED,
                () -> authService.authenticateUser(loginRequest("active@example.com", "wrong-password")));

        ArgumentCaptor<User> savedUser = ArgumentCaptor.forClass(User.class);
        verify(userRepository).save(savedUser.capture());
        assertEquals(0, savedUser.getValue().getFailedLoginAttempts());
        assertNotNull(savedUser.getValue().getLockedUntil());
        assertTrue(savedUser.getValue().getLockedUntil().isAfter(LocalDateTime.now().plusMinutes(14)));
    }

    @Test
    void authenticateUserShouldRejectLoginWhileAccountIsLockedWithoutCallingAuthenticationManager() {
        User user = activeVerifiedUser("locked@example.com", "ACTIVE");
        user.setLockedUntil(LocalDateTime.now().plusMinutes(10));
        when(userRepository.findByEmail("locked@example.com")).thenReturn(Optional.of(user));

        assertApiException(HttpStatus.LOCKED,
                () -> authService.authenticateUser(loginRequest("locked@example.com", "correct-password")));

        verify(authenticationManager, never()).authenticate(any());
    }

    @Test
    void authenticateUserShouldAllowLoginAfterLockExpires() {
        User user = activeVerifiedUser("locked@example.com", "ACTIVE");
        user.setLockedUntil(LocalDateTime.now().minusMinutes(1));
        when(userRepository.findByEmail("locked@example.com")).thenReturn(Optional.of(user));
        when(authenticationManager.authenticate(any())).thenReturn(authentication);
        when(jwtUtils.generateJwtTokenFromUsername(anyString())).thenReturn("mock-jwt-token");
        when(jwtUtils.generateOpaqueRefreshToken()).thenReturn("raw-refresh-token");
        when(jwtUtils.hashToken(anyString())).thenReturn("hashed");
        when(jwtUtils.getRefreshExpirationMs()).thenReturn(2_592_000_000L);
        when(userRepository.save(any(User.class))).thenAnswer(inv -> inv.getArgument(0));

        assertDoesNotThrow(() -> authService.authenticateUser(loginRequest("locked@example.com", "correct-password")));
    }

    @Test
    void authenticateUserShouldRejectAccountThatIsNotActiveStatus() {
        User user = activeVerifiedUser("locked-status@example.com", "LOCKED");
        when(userRepository.findByEmail("locked-status@example.com")).thenReturn(Optional.of(user));
        when(authenticationManager.authenticate(any())).thenReturn(authentication);

        assertApiException(HttpStatus.FORBIDDEN,
                () -> authService.authenticateUser(loginRequest("locked-status@example.com", "correct-password")));

        verify(jwtUtils, never()).generateJwtTokenFromUsername(anyString());
    }

    @Test
    void authenticateUserShouldRejectInactiveAccount() {
        User user = activeVerifiedUser("inactive@example.com", "INACTIVE");
        when(userRepository.findByEmail("inactive@example.com")).thenReturn(Optional.of(user));
        when(authenticationManager.authenticate(any())).thenReturn(authentication);

        assertApiException(HttpStatus.FORBIDDEN,
                () -> authService.authenticateUser(loginRequest("inactive@example.com", "correct-password")));

        verify(userRepository, never()).save(any());
    }

    @Test
    void authenticateUserShouldRejectUnverifiedAccountEvenWithCorrectPassword() {
        User user = activeVerifiedUser("unverified@example.com", "ACTIVE");
        user.setIsVerified(false);
        when(userRepository.findByEmail("unverified@example.com")).thenReturn(Optional.of(user));
        when(authenticationManager.authenticate(any())).thenReturn(authentication);

        assertApiException(HttpStatus.FORBIDDEN,
                () -> authService.authenticateUser(loginRequest("unverified@example.com", "correct-password")));

        verify(jwtUtils, never()).generateJwtTokenFromUsername(anyString());
        verify(refreshTokenRepository, never()).save(any());
    }

    // =================================================================
    // registerUser
    // =================================================================
    private RegisterRequest registerRequest(String email, String password, String requestedRole) {
        RegisterRequest req = new RegisterRequest();
        req.setEmail(email);
        req.setPassword(password);
        req.setConfirmPassword(password);
        req.setFullName("New User");
        req.setRole(requestedRole);
        return req;
    }

    @Test
    void registerUserShouldCreateUnverifiedLearnerAccountAndSendVerificationEmailWithTokenOnHappyPath() {
        when(userRepository.existsByEmail("new@example.com")).thenReturn(false);
        when(roleRepository.findByRoleName("LEARNER"))
                .thenReturn(Optional.of(Role.builder().id(1L).roleName("LEARNER").build()));
        when(encoder.encode("Pass1234!")).thenReturn("ENCODED_HASH");
        when(userRepository.save(any(User.class))).thenAnswer(inv -> {
            User u = inv.getArgument(0);
            u.setId(42L);
            return u;
        });

        UserResponse response = authService.registerUser(registerRequest("new@example.com", "Pass1234!", null));

        assertEquals("new@example.com", response.getEmail());
        assertEquals(List.of("LEARNER"), response.getRoles());
        verify(emailService).sendVerificationEmail(eq("new@example.com"), anyString());

        ArgumentCaptor<User> savedUser = ArgumentCaptor.forClass(User.class);
        verify(userRepository).save(savedUser.capture());
        assertEquals("ENCODED_HASH", savedUser.getValue().getPasswordHash());
        assertNotEquals("Pass1234!", savedUser.getValue().getPasswordHash());
        assertFalse(savedUser.getValue().getIsVerified());
        assertNotNull(savedUser.getValue().getVerificationToken());
        assertNotNull(savedUser.getValue().getVerificationTokenExpiry());
    }

    @Test
    void registerUserShouldNormalizeEmailToLowercaseTrimmed() {
        when(userRepository.existsByEmail("new@example.com")).thenReturn(false);
        when(roleRepository.findByRoleName("LEARNER"))
                .thenReturn(Optional.of(Role.builder().id(1L).roleName("LEARNER").build()));
        when(encoder.encode(anyString())).thenReturn("ENCODED_HASH");
        when(userRepository.save(any(User.class))).thenAnswer(inv -> inv.getArgument(0));

        authService.registerUser(registerRequest("  New@Example.com  ", "Pass1234!", null));

        verify(userRepository).existsByEmail("new@example.com");
    }

    @Test
    void registerUserShouldRejectConfirmPasswordMismatch() {
        RegisterRequest req = registerRequest("mismatch@example.com", "Pass1234!", null);
        req.setConfirmPassword("Different1!");

        ApiException ex = assertApiException(HttpStatus.BAD_REQUEST, () -> authService.registerUser(req));
        assertTrue(ex.getMessage().contains("do not match"));
        verify(userRepository, never()).save(any());
    }

    @Test
    void registerUserShouldRejectDuplicateEmailWithConflictStatus() {
        when(userRepository.existsByEmail("existing@example.com")).thenReturn(true);

        assertApiException(HttpStatus.CONFLICT,
                () -> authService.registerUser(registerRequest("existing@example.com", "Pass1234!", null)));
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

        authService.registerUser(registerRequest("new2@example.com", "Pass1234!", null));

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

        UserResponse response = authService.registerUser(registerRequest("new3@example.com", "Pass1234!", "TRAINER"));

        assertEquals(List.of("TRAINER"), response.getRoles());
        verify(roleRepository, never()).findByRoleName("LEARNER");
    }

    @Test
    void registerUserShouldRejectRoleOutsideLearnerTrainerWhitelist() {
        when(userRepository.existsByEmail("new5@example.com")).thenReturn(false);

        ApiException ex = assertApiException(HttpStatus.BAD_REQUEST,
                () -> authService.registerUser(registerRequest("new5@example.com", "Pass1234!", "ADMINISTRATOR")));
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
        doThrow(new RuntimeException("SMTP down")).when(emailService).sendVerificationEmail(eq("new4@example.com"), anyString());

        UserResponse response = assertDoesNotThrow(
                () -> authService.registerUser(registerRequest("new4@example.com", "Pass1234!", null)));
        assertEquals("new4@example.com", response.getEmail());
    }

    // =================================================================
    // createUserByAdmin
    // =================================================================
    @Test
    void createUserByAdminShouldRejectDuplicateEmail() {
        when(userRepository.existsByEmail("existing@example.com")).thenReturn(true);

        IllegalArgumentException ex = assertThrows(IllegalArgumentException.class,
                () -> authService.createUserByAdmin(registerRequest("existing@example.com", "Pass1234!", "TRAINER")));
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

        UserResponse response = authService.createUserByAdmin(registerRequest("cm1@example.com", "Pass1234!", null));

        assertEquals(List.of("TRAINER"), response.getRoles());
    }

    @Test
    void createUserByAdminShouldAllowCreatingTrainerLeadRole() {
        when(userRepository.existsByEmail("cm2@example.com")).thenReturn(false);
        when(roleRepository.findByRoleName("COURSE_MANAGER"))
                .thenReturn(Optional.of(Role.builder().id(3L).roleName("COURSE_MANAGER").build()));
        when(encoder.encode(anyString())).thenReturn("ENCODED_HASH");
        when(userRepository.save(any(User.class))).thenAnswer(inv -> inv.getArgument(0));

        UserResponse response = authService.createUserByAdmin(registerRequest("cm2@example.com", "pass1234", "COURSE_MANAGER"));

        assertEquals(List.of("COURSE_MANAGER"), response.getRoles());
    }

    @Test
    void createUserByAdminShouldNormalizeAdminAliasToAdministrator() {
        when(userRepository.existsByEmail("admin2@example.com")).thenReturn(false);
        when(roleRepository.findByRoleName("ADMINISTRATOR"))
                .thenReturn(Optional.of(Role.builder().id(4L).roleName("ADMINISTRATOR").build()));
        when(encoder.encode(anyString())).thenReturn("ENCODED_HASH");
        when(userRepository.save(any(User.class))).thenAnswer(inv -> inv.getArgument(0));

        UserResponse response = authService.createUserByAdmin(registerRequest("admin2@example.com", "Pass1234!", "admin"));

        assertEquals(List.of("ADMINISTRATOR"), response.getRoles());
    }

    @Test
    void createUserByAdminShouldRejectRoleOutsideWhitelistInsteadOfSilentlyCreatingGarbageRole() {
        when(userRepository.existsByEmail("typo@example.com")).thenReturn(false);

        IllegalArgumentException ex = assertThrows(IllegalArgumentException.class,
                () -> authService.createUserByAdmin(registerRequest("typo@example.com", "Pass1234!", "TRANIER")));
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

        authService.createUserByAdmin(registerRequest("cm3@example.com", "Pass1234!", "TRAINER"));

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
    void googleLoginShouldJitProvisionVerifiedLearnerAccountOnFirstSignIn() throws Exception {
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
        when(jwtUtils.generateOpaqueRefreshToken()).thenReturn("raw-refresh-token");
        when(jwtUtils.hashToken(anyString())).thenReturn("hashed");
        when(jwtUtils.getRefreshExpirationMs()).thenReturn(2_592_000_000L);

        GoogleLoginRequest req = new GoogleLoginRequest();
        req.setIdToken("valid-google-token");
        LoginResponse response = authService.googleLogin(req);

        assertEquals("google-jwt-token", response.getToken());
        assertEquals("raw-refresh-token", response.getRefreshToken());
        assertEquals("newgoogleuser@example.com", response.getEmail());
        assertEquals("Google User Name", response.getFullName());
        assertEquals(List.of("LEARNER", "ROLE_LEARNER"), response.getRoles());

        ArgumentCaptor<User> savedUser = ArgumentCaptor.forClass(User.class);
        verify(userRepository, org.mockito.Mockito.atLeastOnce()).save(savedUser.capture());
        assertTrue(savedUser.getValue().getIsVerified());
    }

    @Test
    void googleLoginShouldReuseExistingAccountWithoutCreatingDuplicateRole() throws Exception {
        User existing = activeVerifiedUser("existinggoogleuser@example.com", "ACTIVE");
        when(googleIdTokenVerifier.verify("valid-google-token"))
                .thenReturn(mockGoogleIdToken("existinggoogleuser@example.com", "Existing User", null));
        when(userRepository.findByEmail("existinggoogleuser@example.com")).thenReturn(Optional.of(existing));
        when(userRepository.save(any(User.class))).thenAnswer(inv -> inv.getArgument(0));
        when(jwtUtils.generateJwtTokenFromUsername("existinggoogleuser@example.com")).thenReturn("google-jwt-token");
        when(jwtUtils.generateOpaqueRefreshToken()).thenReturn("raw-refresh-token");
        when(jwtUtils.hashToken(anyString())).thenReturn("hashed");
        when(jwtUtils.getRefreshExpirationMs()).thenReturn(2_592_000_000L);

        GoogleLoginRequest req = new GoogleLoginRequest();
        req.setIdToken("valid-google-token");
        LoginResponse response = authService.googleLogin(req);

        assertEquals("existinggoogleuser@example.com", response.getEmail());
        verify(roleRepository, never()).findByRoleName(anyString());
    }

    @Test
    void googleLoginShouldRejectAccountThatIsNotActive() throws Exception {
        User inactive = activeVerifiedUser("inactivegoogleuser@example.com", "INACTIVE");
        when(googleIdTokenVerifier.verify("valid-google-token"))
                .thenReturn(mockGoogleIdToken("inactivegoogleuser@example.com", "Inactive User", null));
        when(userRepository.findByEmail("inactivegoogleuser@example.com")).thenReturn(Optional.of(inactive));

        GoogleLoginRequest req = new GoogleLoginRequest();
        req.setIdToken("valid-google-token");

        assertApiException(HttpStatus.FORBIDDEN, () -> authService.googleLogin(req));
        verify(jwtUtils, never()).generateJwtTokenFromUsername(anyString());
    }

    @Test
    void googleLoginShouldRejectWhenVerifierReturnsNullInsteadOfFallingBackToUnsafeParsing() throws Exception {
        // Regression test: this used to fall back to parsing the token without checking its
        // signature, which let an attacker forge a login as literally any email address.
        when(googleIdTokenVerifier.verify("not-a-real-jwt")).thenReturn(null);

        GoogleLoginRequest req = new GoogleLoginRequest();
        req.setIdToken("not-a-real-jwt");

        assertApiException(HttpStatus.UNAUTHORIZED, () -> authService.googleLogin(req));
        verify(userRepository, never()).save(any());
        verify(userRepository, never()).findByEmail(anyString());
    }

    @Test
    void googleLoginShouldRejectWhenVerifierThrows() throws Exception {
        when(googleIdTokenVerifier.verify("broken-token")).thenThrow(new java.security.GeneralSecurityException("boom"));

        GoogleLoginRequest req = new GoogleLoginRequest();
        req.setIdToken("broken-token");

        assertApiException(HttpStatus.UNAUTHORIZED, () -> authService.googleLogin(req));
    }

    // =================================================================
    // forgotPassword
    // =================================================================
    @Test
    void forgotPasswordShouldSilentlySucceedForUnregisteredEmailWithoutSendingAnything() {
        when(userRepository.findByEmail("unknown@example.com")).thenReturn(Optional.empty());

        ForgotPasswordRequest req = new ForgotPasswordRequest();
        req.setEmail("unknown@example.com");

        assertDoesNotThrow(() -> authService.forgotPassword(req));
        verify(passwordResetOtpRepository, never()).save(any());
        verify(emailService, never()).sendOtpEmail(anyString(), anyString());
    }

    @Test
    void forgotPasswordShouldReplaceExistingOtpAndSendSixDigitCodeByEmail() {
        User user = activeVerifiedUser("known@example.com", "ACTIVE");
        when(userRepository.findByEmail("known@example.com")).thenReturn(Optional.of(user));
        when(passwordResetOtpRepository.findTopByEmailOrderByIdDesc("known@example.com")).thenReturn(Optional.empty());
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

    @Test
    void forgotPasswordShouldNoOpWhenResendCooldownStillActive() {
        User user = activeVerifiedUser("known@example.com", "ACTIVE");
        PasswordResetOtp recent = PasswordResetOtp.builder()
                .id(1L).email("known@example.com").otpCode("111111")
                .expiryTime(LocalDateTime.now().plusMinutes(4))
                .lastSentAt(LocalDateTime.now().minusSeconds(10))
                .build();
        when(userRepository.findByEmail("known@example.com")).thenReturn(Optional.of(user));
        when(passwordResetOtpRepository.findTopByEmailOrderByIdDesc("known@example.com")).thenReturn(Optional.of(recent));

        ForgotPasswordRequest req = new ForgotPasswordRequest();
        req.setEmail("known@example.com");
        authService.forgotPassword(req);

        verify(passwordResetOtpRepository, never()).save(any());
        verify(emailService, never()).sendOtpEmail(anyString(), anyString());
    }

    // =================================================================
    // verifyOtp
    // =================================================================
    @Test
    void verifyOtpShouldRejectWhenNoOtpExistsForEmail() {
        when(passwordResetOtpRepository.findTopByEmailOrderByIdDesc("known@example.com"))
                .thenReturn(Optional.empty());

        VerifyOtpRequest req = new VerifyOtpRequest();
        req.setEmail("known@example.com");
        req.setOtpCode("000000");

        ApiException ex = assertApiException(HttpStatus.BAD_REQUEST, () -> authService.verifyOtp(req));
        assertTrue(ex.getMessage().contains("Invalid OTP"));
    }

    @Test
    void verifyOtpShouldDeleteAndRejectExpiredOtp() {
        PasswordResetOtp expired = PasswordResetOtp.builder()
                .id(1L).email("known@example.com").otpCode("123456")
                .expiryTime(LocalDateTime.now().minusMinutes(1))
                .build();
        when(passwordResetOtpRepository.findTopByEmailOrderByIdDesc("known@example.com"))
                .thenReturn(Optional.of(expired));

        VerifyOtpRequest req = new VerifyOtpRequest();
        req.setEmail("known@example.com");
        req.setOtpCode("123456");

        ApiException ex = assertApiException(HttpStatus.BAD_REQUEST, () -> authService.verifyOtp(req));
        assertTrue(ex.getMessage().contains("expired"));
        verify(passwordResetOtpRepository).delete(expired);
    }

    @Test
    void verifyOtpShouldAcceptValidUnexpiredOtpWithoutConsumingIt() {
        PasswordResetOtp valid = PasswordResetOtp.builder()
                .id(1L).email("known@example.com").otpCode("123456")
                .expiryTime(LocalDateTime.now().plusMinutes(3))
                .build();
        when(passwordResetOtpRepository.findTopByEmailOrderByIdDesc("known@example.com"))
                .thenReturn(Optional.of(valid));

        VerifyOtpRequest req = new VerifyOtpRequest();
        req.setEmail("known@example.com");
        req.setOtpCode("123456");

        assertDoesNotThrow(() -> authService.verifyOtp(req));
        verify(passwordResetOtpRepository, never()).delete(any());
        verify(passwordResetOtpRepository, never()).save(any());
    }

    @Test
    void verifyOtpShouldRejectAlreadyConsumedOtp() {
        PasswordResetOtp consumed = PasswordResetOtp.builder()
                .id(1L).email("known@example.com").otpCode("123456")
                .expiryTime(LocalDateTime.now().plusMinutes(3))
                .consumed(true)
                .build();
        when(passwordResetOtpRepository.findTopByEmailOrderByIdDesc("known@example.com"))
                .thenReturn(Optional.of(consumed));

        VerifyOtpRequest req = new VerifyOtpRequest();
        req.setEmail("known@example.com");
        req.setOtpCode("123456");

        ApiException ex = assertApiException(HttpStatus.BAD_REQUEST, () -> authService.verifyOtp(req));
        assertTrue(ex.getMessage().contains("already been used"));
    }

    @Test
    void verifyOtpShouldIncrementAttemptCountOnWrongCode() {
        PasswordResetOtp otp = PasswordResetOtp.builder()
                .id(1L).email("known@example.com").otpCode("123456")
                .expiryTime(LocalDateTime.now().plusMinutes(3))
                .attemptCount(1)
                .build();
        when(passwordResetOtpRepository.findTopByEmailOrderByIdDesc("known@example.com"))
                .thenReturn(Optional.of(otp));

        VerifyOtpRequest req = new VerifyOtpRequest();
        req.setEmail("known@example.com");
        req.setOtpCode("000000");

        assertApiException(HttpStatus.BAD_REQUEST, () -> authService.verifyOtp(req));

        ArgumentCaptor<PasswordResetOtp> savedOtp = ArgumentCaptor.forClass(PasswordResetOtp.class);
        verify(passwordResetOtpRepository).save(savedOtp.capture());
        assertEquals(2, savedOtp.getValue().getAttemptCount());
    }

    @Test
    void verifyOtpShouldDeleteOtpAfterTooManyWrongAttempts() {
        PasswordResetOtp otp = PasswordResetOtp.builder()
                .id(1L).email("known@example.com").otpCode("123456")
                .expiryTime(LocalDateTime.now().plusMinutes(3))
                .attemptCount(4)
                .build();
        when(passwordResetOtpRepository.findTopByEmailOrderByIdDesc("known@example.com"))
                .thenReturn(Optional.of(otp));

        VerifyOtpRequest req = new VerifyOtpRequest();
        req.setEmail("known@example.com");
        req.setOtpCode("000000");

        ApiException ex = assertApiException(HttpStatus.BAD_REQUEST, () -> authService.verifyOtp(req));
        assertTrue(ex.getMessage().contains("Too many"));
        verify(passwordResetOtpRepository).delete(otp);
        verify(passwordResetOtpRepository, never()).save(any());
    }

    // =================================================================
    // resetPassword
    // =================================================================
    private PasswordResetOtp validOtpFor(String email, String code) {
        return PasswordResetOtp.builder()
                .id(1L).email(email).otpCode(code)
                .expiryTime(LocalDateTime.now().plusMinutes(3))
                .build();
    }

    @Test
    void resetPasswordShouldRejectWhenNoOtpExists() {
        when(passwordResetOtpRepository.findTopByEmailOrderByIdDesc("unknown@example.com"))
                .thenReturn(Optional.empty());

        ResetPasswordRequest req = new ResetPasswordRequest();
        req.setEmail("unknown@example.com");
        req.setOtpCode("123456");
        req.setNewPassword("NewPass123!");

        assertApiException(HttpStatus.BAD_REQUEST, () -> authService.resetPassword(req));
        verify(userRepository, never()).findByEmail(anyString());
    }

    @Test
    void resetPasswordShouldRejectMismatchedOtpCode() {
        when(passwordResetOtpRepository.findTopByEmailOrderByIdDesc("known@example.com"))
                .thenReturn(Optional.of(validOtpFor("known@example.com", "123456")));

        ResetPasswordRequest req = new ResetPasswordRequest();
        req.setEmail("known@example.com");
        req.setOtpCode("999999");
        req.setNewPassword("NewPass123!");

        assertApiException(HttpStatus.BAD_REQUEST, () -> authService.resetPassword(req));
        verify(userRepository, never()).save(any());
    }

    @Test
    void resetPasswordShouldThrowWhenUserNotFoundDespiteValidOtp() {
        when(passwordResetOtpRepository.findTopByEmailOrderByIdDesc("unknown@example.com"))
                .thenReturn(Optional.of(validOtpFor("unknown@example.com", "123456")));
        when(userRepository.findByEmail("unknown@example.com")).thenReturn(Optional.empty());

        ResetPasswordRequest req = new ResetPasswordRequest();
        req.setEmail("unknown@example.com");
        req.setOtpCode("123456");
        req.setNewPassword("NewPass123!");

        assertThrows(UsernameNotFoundException.class, () -> authService.resetPassword(req));
    }

    @Test
    void resetPasswordShouldRejectNewPasswordEqualToCurrentPassword() {
        User user = activeVerifiedUser("known@example.com", "ACTIVE");
        when(passwordResetOtpRepository.findTopByEmailOrderByIdDesc("known@example.com"))
                .thenReturn(Optional.of(validOtpFor("known@example.com", "123456")));
        when(userRepository.findByEmail("known@example.com")).thenReturn(Optional.of(user));
        when(encoder.matches("SamePass123!", "hashed")).thenReturn(true);

        ResetPasswordRequest req = new ResetPasswordRequest();
        req.setEmail("known@example.com");
        req.setOtpCode("123456");
        req.setNewPassword("SamePass123!");

        ApiException ex = assertApiException(HttpStatus.BAD_REQUEST, () -> authService.resetPassword(req));
        assertTrue(ex.getMessage().contains("different"));
        verify(userRepository, never()).save(any());
    }

    @Test
    void resetPasswordShouldEncodeNewPasswordConsumeOtpAndRevokeRefreshTokensOnSuccess() {
        User user = activeVerifiedUser("known@example.com", "ACTIVE");
        when(passwordResetOtpRepository.findTopByEmailOrderByIdDesc("known@example.com"))
                .thenReturn(Optional.of(validOtpFor("known@example.com", "123456")));
        when(userRepository.findByEmail("known@example.com")).thenReturn(Optional.of(user));
        when(encoder.matches("NewPass123!", "hashed")).thenReturn(false);
        when(encoder.encode("NewPass123!")).thenReturn("NEW_ENCODED_HASH");

        ResetPasswordRequest req = new ResetPasswordRequest();
        req.setEmail("known@example.com");
        req.setOtpCode("123456");
        req.setNewPassword("NewPass123!");
        authService.resetPassword(req);

        assertEquals("NEW_ENCODED_HASH", user.getPasswordHash());
        verify(userRepository).save(user);
        verify(passwordResetOtpRepository).deleteByEmail("known@example.com");
        verify(refreshTokenRepository).deleteByUser(user);
    }

    // =================================================================
    // verifyAccountByToken
    // =================================================================
    @Test
    void verifyAccountByTokenShouldRejectUnknownToken() {
        when(userRepository.findByVerificationToken("bad-token")).thenReturn(Optional.empty());

        assertApiException(HttpStatus.BAD_REQUEST, () -> authService.verifyAccountByToken("bad-token"));
    }

    @Test
    void verifyAccountByTokenShouldRejectAlreadyVerifiedAccount() {
        User user = activeVerifiedUser("pending@example.com", "ACTIVE");
        user.setIsVerified(true);
        user.setVerificationToken("token-1");
        when(userRepository.findByVerificationToken("token-1")).thenReturn(Optional.of(user));

        assertApiException(HttpStatus.BAD_REQUEST, () -> authService.verifyAccountByToken("token-1"));
    }

    @Test
    void verifyAccountByTokenShouldRejectExpiredToken() {
        User user = activeVerifiedUser("pending@example.com", "ACTIVE");
        user.setIsVerified(false);
        user.setVerificationToken("token-1");
        user.setVerificationTokenExpiry(LocalDateTime.now().minusHours(1));
        when(userRepository.findByVerificationToken("token-1")).thenReturn(Optional.of(user));

        ApiException ex = assertApiException(HttpStatus.BAD_REQUEST, () -> authService.verifyAccountByToken("token-1"));
        assertTrue(ex.getMessage().contains("expired"));
    }

    @Test
    void verifyAccountByTokenShouldMarkUserVerifiedAndClearToken() {
        User user = activeVerifiedUser("pending@example.com", "ACTIVE");
        user.setIsVerified(false);
        user.setVerificationToken("token-1");
        user.setVerificationTokenExpiry(LocalDateTime.now().plusHours(1));
        when(userRepository.findByVerificationToken("token-1")).thenReturn(Optional.of(user));

        authService.verifyAccountByToken("token-1");

        assertTrue(user.getIsVerified());
        assertNull(user.getVerificationToken());
        assertNull(user.getVerificationTokenExpiry());
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
        User user = activeVerifiedUser("verified@example.com", "ACTIVE");
        user.setIsVerified(true);
        when(userRepository.findByEmail("verified@example.com")).thenReturn(Optional.of(user));

        ApiException ex = assertApiException(HttpStatus.BAD_REQUEST,
                () -> authService.resendVerificationEmail("verified@example.com"));
        assertTrue(ex.getMessage().contains("already verified"));
    }

    @Test
    void resendVerificationEmailShouldRotateTokenAndDispatchEmailForUnverifiedAccount() {
        User user = activeVerifiedUser("pending2@example.com", "ACTIVE");
        user.setIsVerified(false);
        when(userRepository.findByEmail("pending2@example.com")).thenReturn(Optional.of(user));

        assertDoesNotThrow(() -> authService.resendVerificationEmail("pending2@example.com"));
        verify(emailService).sendVerificationEmail(eq("pending2@example.com"), anyString());
        assertNotNull(user.getVerificationToken());
    }

    @Test
    void resendVerificationEmailShouldInvalidateThePreviouslyIssuedLink() {
        User user = activeVerifiedUser("pending5@example.com", "ACTIVE");
        user.setIsVerified(false);
        user.setVerificationToken("old-token");
        // Issued 5 minutes ago (encoded as expiry - 12h): past the 60s resend cooldown.
        user.setVerificationTokenExpiry(LocalDateTime.now().plusHours(12).minusMinutes(5));
        when(userRepository.findByEmail("pending5@example.com")).thenReturn(Optional.of(user));

        authService.resendVerificationEmail("pending5@example.com");

        assertNotEquals("old-token", user.getVerificationToken());

        // The stale link is now unresolvable by the repository lookup that
        // verifyAccountByToken relies on -- clicking it must show an error page,
        // not silently re-verify or crash.
        when(userRepository.findByVerificationToken("old-token")).thenReturn(Optional.empty());
        assertApiException(HttpStatus.BAD_REQUEST, () -> authService.verifyAccountByToken("old-token"));
    }

    @Test
    void resendVerificationEmailShouldRejectWhenCooldownStillActive() {
        User user = activeVerifiedUser("pending4@example.com", "ACTIVE");
        user.setIsVerified(false);
        user.setVerificationTokenExpiry(LocalDateTime.now().plusHours(12).minusSeconds(5));
        when(userRepository.findByEmail("pending4@example.com")).thenReturn(Optional.of(user));

        assertApiException(HttpStatus.TOO_MANY_REQUESTS,
                () -> authService.resendVerificationEmail("pending4@example.com"));
        verify(emailService, never()).sendVerificationEmail(anyString(), anyString());
    }

    @Test
    void resendVerificationEmailShouldRethrowWhenEmailDispatchFails() {
        User user = activeVerifiedUser("pending3@example.com", "ACTIVE");
        user.setIsVerified(false);
        when(userRepository.findByEmail("pending3@example.com")).thenReturn(Optional.of(user));
        doThrow(new RuntimeException("SMTP down")).when(emailService).sendVerificationEmail(eq("pending3@example.com"), anyString());

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
        User user = activeVerifiedUser("verified@example.com", "ACTIVE");
        user.setIsVerified(true);
        when(userRepository.findByEmail("verified@example.com")).thenReturn(Optional.of(user));
        assertTrue(authService.isAccountVerified("verified@example.com"));
    }

    @Test
    void isAccountVerifiedShouldReturnFalseWhenFlagIsNull() {
        User user = activeVerifiedUser("nullflag@example.com", "ACTIVE");
        user.setIsVerified(null);
        when(userRepository.findByEmail("nullflag@example.com")).thenReturn(Optional.of(user));
        assertFalse(authService.isAccountVerified("nullflag@example.com"));
    }

    // =================================================================
    // refreshAccessToken
    // =================================================================
    @Test
    void refreshAccessTokenShouldRejectUnknownToken() {
        when(jwtUtils.hashToken("raw-token")).thenReturn("hashed-token");
        when(refreshTokenRepository.findByTokenHash("hashed-token")).thenReturn(Optional.empty());

        assertApiException(HttpStatus.UNAUTHORIZED, () -> authService.refreshAccessToken("raw-token"));
    }

    @Test
    void refreshAccessTokenShouldRejectRevokedToken() {
        User user = activeVerifiedUser("known@example.com", "ACTIVE");
        RefreshToken stored = RefreshToken.builder().id(1L).user(user).tokenHash("hashed-token")
                .expiresAt(LocalDateTime.now().plusDays(1)).revoked(true).build();
        when(jwtUtils.hashToken("raw-token")).thenReturn("hashed-token");
        when(refreshTokenRepository.findByTokenHash("hashed-token")).thenReturn(Optional.of(stored));

        assertApiException(HttpStatus.UNAUTHORIZED, () -> authService.refreshAccessToken("raw-token"));
    }

    @Test
    void refreshAccessTokenShouldRejectExpiredToken() {
        User user = activeVerifiedUser("known@example.com", "ACTIVE");
        RefreshToken stored = RefreshToken.builder().id(1L).user(user).tokenHash("hashed-token")
                .expiresAt(LocalDateTime.now().minusMinutes(1)).revoked(false).build();
        when(jwtUtils.hashToken("raw-token")).thenReturn("hashed-token");
        when(refreshTokenRepository.findByTokenHash("hashed-token")).thenReturn(Optional.of(stored));

        assertApiException(HttpStatus.UNAUTHORIZED, () -> authService.refreshAccessToken("raw-token"));
    }

    @Test
    void refreshAccessTokenShouldRejectWhenAccountNoLongerEligible() {
        User user = activeVerifiedUser("known@example.com", "INACTIVE");
        RefreshToken stored = RefreshToken.builder().id(1L).user(user).tokenHash("hashed-token")
                .expiresAt(LocalDateTime.now().plusDays(1)).revoked(false).build();
        when(jwtUtils.hashToken("raw-token")).thenReturn("hashed-token");
        when(refreshTokenRepository.findByTokenHash("hashed-token")).thenReturn(Optional.of(stored));

        assertApiException(HttpStatus.FORBIDDEN, () -> authService.refreshAccessToken("raw-token"));
    }

    @Test
    void refreshAccessTokenShouldRotateTokenAndIssueNewAccessTokenOnSuccess() {
        User user = activeVerifiedUser("known@example.com", "ACTIVE");
        RefreshToken stored = RefreshToken.builder().id(1L).user(user).tokenHash("old-hash")
                .expiresAt(LocalDateTime.now().plusDays(1)).revoked(false).build();
        when(jwtUtils.hashToken("old-raw-token")).thenReturn("old-hash");
        when(refreshTokenRepository.findByTokenHash("old-hash")).thenReturn(Optional.of(stored));
        when(jwtUtils.generateJwtTokenFromUsername("known@example.com")).thenReturn("new-jwt");
        when(jwtUtils.generateOpaqueRefreshToken()).thenReturn("new-raw-token");
        when(jwtUtils.hashToken("new-raw-token")).thenReturn("new-hash");
        when(jwtUtils.getRefreshExpirationMs()).thenReturn(2_592_000_000L);

        TokenRefreshResponse response = authService.refreshAccessToken("old-raw-token");

        assertEquals("new-jwt", response.getToken());
        assertEquals("new-raw-token", response.getRefreshToken());
        assertTrue(response.getRoles() != null && !response.getRoles().isEmpty());
        assertTrue(stored.getRevoked());
        verify(refreshTokenRepository).save(stored);
        verify(refreshTokenRepository, times(2)).save(any(RefreshToken.class));
    }

    // =================================================================
    // logout
    // =================================================================
    @Test
    void logoutShouldNoOpWhenTokenIsBlank() {
        assertDoesNotThrow(() -> authService.logout(""));
        assertDoesNotThrow(() -> authService.logout(null));
        verify(refreshTokenRepository, never()).findByTokenHash(anyString());
    }

    @Test
    void logoutShouldNoOpWhenTokenIsUnknown() {
        when(jwtUtils.hashToken("raw-token")).thenReturn("hashed-token");
        when(refreshTokenRepository.findByTokenHash("hashed-token")).thenReturn(Optional.empty());

        assertDoesNotThrow(() -> authService.logout("raw-token"));
        verify(refreshTokenRepository, never()).save(any());
    }

    @Test
    void logoutShouldRevokeMatchingRefreshToken() {
        RefreshToken stored = RefreshToken.builder().id(1L).tokenHash("hashed-token")
                .expiresAt(LocalDateTime.now().plusDays(1)).revoked(false).build();
        when(jwtUtils.hashToken("raw-token")).thenReturn("hashed-token");
        when(refreshTokenRepository.findByTokenHash("hashed-token")).thenReturn(Optional.of(stored));

        authService.logout("raw-token");

        assertTrue(stored.getRevoked());
        verify(refreshTokenRepository).save(stored);
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
        User user = activeVerifiedUser("known@example.com", "ACTIVE");
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
        User user = activeVerifiedUser("known@example.com", "ACTIVE");
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
        User user = activeVerifiedUser("known@example.com", "ACTIVE");
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
        User user = activeVerifiedUser("known@example.com", "ACTIVE");
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
        User user = activeVerifiedUser("known@example.com", "ACTIVE");
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
        User user = activeVerifiedUser("known@example.com", "ACTIVE");
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
        User user = activeVerifiedUser("known@example.com", "ACTIVE");
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
        User user = activeVerifiedUser("known@example.com", "ACTIVE");
        when(userRepository.findByEmail("known@example.com")).thenReturn(Optional.of(user));
        when(encoder.matches("wrongCurrent", "hashed")).thenReturn(false);

        ChangePasswordRequest req = new ChangePasswordRequest();
        req.setCurrentPassword("wrongCurrent");
        req.setNewPassword("NewPass123!");

        ApiException ex = assertApiException(HttpStatus.BAD_REQUEST,
                () -> authService.changePassword("known@example.com", req));
        assertTrue(ex.getMessage().contains("Incorrect current password"));
        verify(userRepository, never()).save(any());
    }

    @Test
    void changePasswordShouldRejectNewPasswordEqualToCurrentPassword() {
        User user = activeVerifiedUser("known@example.com", "ACTIVE");
        when(userRepository.findByEmail("known@example.com")).thenReturn(Optional.of(user));
        when(encoder.matches("SamePass123!", "hashed")).thenReturn(true);

        ChangePasswordRequest req = new ChangePasswordRequest();
        req.setCurrentPassword("SamePass123!");
        req.setNewPassword("SamePass123!");

        ApiException ex = assertApiException(HttpStatus.BAD_REQUEST,
                () -> authService.changePassword("known@example.com", req));
        assertTrue(ex.getMessage().contains("different"));
        verify(userRepository, never()).save(any());
    }

    @Test
    void changePasswordShouldEncodeSaveAndRevokeRefreshTokensWhenCurrentPasswordMatches() {
        User user = activeVerifiedUser("known@example.com", "ACTIVE");
        when(userRepository.findByEmail("known@example.com")).thenReturn(Optional.of(user));
        when(encoder.matches("correctCurrent", "hashed")).thenReturn(true);
        when(encoder.encode("NewPass123!")).thenReturn("NEW_ENCODED_HASH");

        ChangePasswordRequest req = new ChangePasswordRequest();
        req.setCurrentPassword("correctCurrent");
        req.setNewPassword("NewPass123!");
        authService.changePassword("known@example.com", req);

        assertEquals("NEW_ENCODED_HASH", user.getPasswordHash());
        verify(userRepository).save(user);
        verify(refreshTokenRepository).deleteByUser(user);
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
        User user = activeVerifiedUser("known@example.com", "ACTIVE");
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
        User user = activeVerifiedUser("known@example.com", "ACTIVE");
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
        User user = activeVerifiedUser("known@example.com", "ACTIVE");
        when(userRepository.findByEmail("known@example.com")).thenReturn(Optional.of(user));
        MultipartFile file = validAvatarFile();
        when(cloudinaryService.uploadImage(file)).thenThrow(new java.io.IOException("Cloudinary unreachable"));

        assertThrows(java.io.IOException.class, () -> authService.updateAvatar("known@example.com", file));
        verify(userRepository, never()).save(any());
    }

    @Test
    void updateAvatarShouldRejectFileLargerThan2MB() {
        User user = activeVerifiedUser("known@example.com", "ACTIVE");
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
        User user = activeVerifiedUser("known@example.com", "ACTIVE");
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
