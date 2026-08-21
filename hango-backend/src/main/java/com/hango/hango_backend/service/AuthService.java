package com.hango.hango_backend.service;

import java.io.IOException;
import java.security.SecureRandom;
import java.time.LocalDateTime;
import java.util.Collections;
import java.util.HashSet;
import java.util.List;
import java.util.Locale;
import java.util.Set;
import java.util.UUID;
import java.util.stream.Collectors;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.HttpStatus;
import org.springframework.security.authentication.AuthenticationManager;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.AuthenticationException;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.security.core.userdetails.UsernameNotFoundException;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
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
import com.hango.hango_backend.security.UserDetailsImpl;
import com.hango.hango_backend.repository.RoleRepository;
import com.hango.hango_backend.repository.UserRepository;
import com.hango.hango_backend.util.JwtUtils;

@Service
public class AuthService {


    private static final int MAX_FAILED_LOGIN_ATTEMPTS = 5;
    private static final long LOGIN_LOCK_MINUTES = 15;
    private static final int MAX_OTP_ATTEMPTS = 5;
    private static final long OTP_RESEND_COOLDOWN_SECONDS = 60;
    private static final long VERIFICATION_TOKEN_VALIDITY_HOURS = 12;
    private static final SecureRandom SECURE_RANDOM = new SecureRandom();

    @Autowired
    private AuthenticationManager authenticationManager;

    @Autowired
    private UserRepository userRepository;

    @Autowired
    private RoleRepository roleRepository;

    @Autowired
    private PasswordEncoder encoder;

    @Autowired
    private JwtUtils jwtUtils;

    @Autowired
    private CloudinaryService cloudinaryService;

    @Autowired
    private PasswordResetOtpRepository passwordResetOtpRepository;

    @Autowired
    private EmailService emailService;

    @Autowired
    private GoogleIdTokenVerifier googleIdTokenVerifier;

    @Autowired
    private RefreshTokenRepository refreshTokenRepository;

    @Autowired
    private AuditLogService auditLogService;

    private static String normalizeEmail(String email) {
        return email == null ? null : email.trim().toLowerCase(Locale.ROOT);
    }

    private void logAudit(User actor, String actionType, Long targetUserId, String details) {
        // Delegates to a REQUIRES_NEW-transactional service so an audit-write
        // failure can never mark this method's own transaction rollback-only.
        //
        // The try/catch has to live HERE, not only inside AuditLogService.log():
        // that inner try/catch only guards the save() call itself. If the save
        // fails, Hibernate already flags the REQUIRES_NEW transaction for
        // rollback before the exception reaches that catch block; swallowing it
        // there just means Spring's transactional proxy then tries to COMMIT a
        // transaction already marked rollback-only when log() returns, which
        // throws UnexpectedRollbackException from this call site instead --
        // silently replacing whatever real error (e.g. "invalid email or
        // password") the caller was about to throw next.
        try {
            auditLogService.log(actor, actionType, targetUserId, details);
        } catch (Exception e) {
            System.err.println("[AUDIT] Failed to write audit log: " + e.getMessage());
        }
    }

    private String issueRefreshToken(User user) {
        String raw = jwtUtils.generateOpaqueRefreshToken();
        RefreshToken tokenEntity = RefreshToken.builder()
                .user(user)
                .tokenHash(jwtUtils.hashToken(raw))
                .expiresAt(LocalDateTime.now().plusSeconds(jwtUtils.getRefreshExpirationMs() / 1000))
                .revoked(false)
                .build();
        refreshTokenRepository.save(tokenEntity);
        return raw;
    }

    // =================================================================
    // authenticateUser
    // =================================================================

    @org.springframework.transaction.annotation.Transactional
    public LoginResponse authenticateUser(LoginRequest loginRequest) {
        String email = normalizeEmail(loginRequest.getEmail());

        User user = userRepository.findByEmail(email).orElse(null);
        if (user == null) {
            logAudit(null, "LOGIN_FAILURE", null, "Unknown email: " + email);
            throw new ApiException("Invalid email or password.", HttpStatus.UNAUTHORIZED);
        }

        if (user.getLockedUntil() != null && user.getLockedUntil().isAfter(LocalDateTime.now())) {
            logAudit(user, "LOGIN_FAILURE", user.getId(), "Account locked until " + user.getLockedUntil());
            throw new ApiException(
                    "Account temporarily locked due to too many failed login attempts. Please try again later.",
                    HttpStatus.LOCKED);
        }

        try {
            Authentication authentication = authenticationManager.authenticate(
                    new UsernamePasswordAuthenticationToken(email, loginRequest.getPassword()));
            SecurityContextHolder.getContext().setAuthentication(authentication);
        } catch (AuthenticationException ex) {
            registerFailedLoginAttempt(user);
            logAudit(user, "LOGIN_FAILURE", user.getId(), "Bad credentials");
            throw new ApiException("Invalid email or password.", HttpStatus.UNAUTHORIZED);
        }

        // Checked before the generic "not active" status: a freshly registered
        // account is INACTIVE until its email is verified, so this gives the
        // more actionable message instead of a generic "contact support".
        if (!Boolean.TRUE.equals(user.getIsVerified())) {
            logAudit(user, "LOGIN_FAILURE", user.getId(), "Email not verified");
            throw new ApiException("Please verify your email address before logging in.", HttpStatus.FORBIDDEN);
        }

        if (!"ACTIVE".equalsIgnoreCase(user.getStatus())) {
            logAudit(user, "LOGIN_FAILURE", user.getId(), "Account status: " + user.getStatus());
            throw new ApiException("Your account is not active. Please contact support.", HttpStatus.FORBIDDEN);
        }

        user.setFailedLoginAttempts(0);
        user.setLockedUntil(null);
        user.setLastLoginAt(LocalDateTime.now());
        userRepository.save(user);

        List<String> roles = new java.util.ArrayList<>();
        for (org.springframework.security.core.GrantedAuthority authority : UserDetailsImpl.build(user)
                .getAuthorities()) {
            roles.add(authority.getAuthority());
        }
        String jwt = jwtUtils.generateJwtTokenFromUsername(user.getEmail());
        String refreshToken = issueRefreshToken(user);

        logAudit(user, "LOGIN_SUCCESS", user.getId(), null);

        return new LoginResponse(jwt, refreshToken, user.getId(), user.getEmail(), user.getFullName(), roles,
                user.getAvatarUrl());
    }

    private void registerFailedLoginAttempt(User user) {
        int attempts = (user.getFailedLoginAttempts() == null ? 0 : user.getFailedLoginAttempts()) + 1;
        if (attempts >= MAX_FAILED_LOGIN_ATTEMPTS) {
            user.setFailedLoginAttempts(0);
            user.setLockedUntil(LocalDateTime.now().plusMinutes(LOGIN_LOCK_MINUTES));
        } else {
            user.setFailedLoginAttempts(attempts);
        }
        userRepository.save(user);
    }



    // =================================================================
    // registerUser
    // =================================================================

    @org.springframework.transaction.annotation.Transactional
    public UserResponse registerUser(RegisterRequest registerRequest) {
        String email = normalizeEmail(registerRequest.getEmail());
        String fullName = registerRequest.getFullName() == null ? null : registerRequest.getFullName().trim();
        String phoneNumber = registerRequest.getPhoneNumber() == null ? null : registerRequest.getPhoneNumber().trim();

        if (registerRequest.getConfirmPassword() == null
                || !registerRequest.getConfirmPassword().equals(registerRequest.getPassword())) {
            throw new ApiException("Password and confirm password do not match.", HttpStatus.BAD_REQUEST);
        }

        if (userRepository.existsByEmail(email)) {
            throw new ApiException("Email is already in use.", HttpStatus.CONFLICT);
        }

        String targetRoleName = registerRequest.getRole();
        if (targetRoleName == null || targetRoleName.trim().isEmpty()) {
            targetRoleName = "LEARNER";
        } else {
            targetRoleName = targetRoleName.trim().toUpperCase();
        }

        if (!targetRoleName.equals("LEARNER") && !targetRoleName.equals("TRAINER")) {
            throw new ApiException("Invalid registration role.", HttpStatus.BAD_REQUEST);
        }

        final String finalRoleName = targetRoleName;
        Role userRole = roleRepository.findByRoleName(finalRoleName)
                .orElseGet(() -> {
                    Role newRole = Role.builder().roleName(finalRoleName).build();
                    return roleRepository.save(newRole);
                });

        String verificationToken = UUID.randomUUID().toString();

        User user = User.builder()
                .email(email)
                .passwordHash(encoder.encode(registerRequest.getPassword()))
                .fullName(fullName)
                .phoneNumber(phoneNumber)
                .gender(registerRequest.getGender())
                .roles(new HashSet<>(Collections.singletonList(userRole)))
                .isVerified(false)
                // Stays INACTIVE (blocked from login/auth actions) until the
                // verification link is clicked -- see verifyAccountByToken().
                .status("INACTIVE")
                .verificationToken(verificationToken)
                .verificationTokenExpiry(LocalDateTime.now().plusHours(VERIFICATION_TOKEN_VALIDITY_HOURS))
                .build();

        User savedUser = userRepository.save(user);

        try {
            emailService.sendVerificationEmail(savedUser.getEmail(), verificationToken);
        } catch (Exception e) {
            System.err.println("Failed to send verification email: " + e.getMessage());
        }

        return mapToUserResponse(savedUser);
    }

    private static final Set<String> ADMIN_CREATABLE_ROLES = Set.of("LEARNER", "TRAINER", "COURSE_MANAGER",
            "ADMINISTRATOR");

    public UserResponse createUserByAdmin(RegisterRequest registerRequest) {
        if (userRepository.existsByEmail(registerRequest.getEmail())) {
            throw new IllegalArgumentException("Error: Email is already in use!");
        }

        // Get requested role, default to TRAINER
        String targetRole = registerRequest.getRole();
        if (targetRole == null || targetRole.trim().isEmpty()) {
            targetRole = "TRAINER";
        } else {
            targetRole = targetRole.trim().toUpperCase();
            if (targetRole.equals("ADMIN")) {
                targetRole = "ADMINISTRATOR";
            }
        }

        if (!ADMIN_CREATABLE_ROLES.contains(targetRole)) {
            throw new IllegalArgumentException("Error: Invalid role! Must be one of " + ADMIN_CREATABLE_ROLES);
        }

        final String roleName = targetRole;
        Role userRole = roleRepository.findByRoleName(roleName)
                .orElseGet(() -> {
                    Role newRole = Role.builder().roleName(roleName).build();
                    return roleRepository.save(newRole);
                });

        User user = User.builder()
                .email(registerRequest.getEmail())
                .passwordHash(encoder.encode(registerRequest.getPassword()))
                .fullName(registerRequest.getFullName())
                .phoneNumber(registerRequest.getPhoneNumber())
                .gender(registerRequest.getGender())
                .dateOfBirth(registerRequest.getDateOfBirth())
                .roles(new java.util.HashSet<>(java.util.Collections.singletonList(userRole)))
                .isVerified(true) // Admin created accounts are verified by default
                .status("ACTIVE") // Default status ACTIVE
                .build();

        User savedUser = userRepository.save(user);
        return mapToUserResponse(savedUser);
    }

    private static final long MAX_AVATAR_SIZE_BYTES = 2L * 1024 * 1024;
    private static final Set<String> ALLOWED_AVATAR_CONTENT_TYPES = Set.of("image/jpeg", "image/png", "image/jpg");

    public UserResponse updateAvatar(String email, MultipartFile file) throws IOException {
        User user = userRepository.findByEmail(email)
                .orElseThrow(() -> new UsernameNotFoundException("User not found with email: " + email));

        validateAvatarFile(file);

        String imageUrl = cloudinaryService.uploadImage(file);
        user.setAvatarUrl(imageUrl);
        User updatedUser = userRepository.save(user);

        return mapToUserResponse(updatedUser);
    }

    private void validateAvatarFile(MultipartFile file) {
        if (file == null || file.isEmpty()) {
            throw new IllegalArgumentException("Error: Avatar file is required.");
        }
        if (file.getSize() > MAX_AVATAR_SIZE_BYTES) {
            throw new IllegalArgumentException("Error: Avatar file must not exceed 2MB.");
        }
        String contentType = file.getContentType();
        if (contentType == null || !ALLOWED_AVATAR_CONTENT_TYPES.contains(contentType.toLowerCase())) {
            throw new IllegalArgumentException("Error: Avatar must be a .jpg, .jpeg, or .png image.");
        }
    }

    // =================================================================
    // googleLogin
    // =================================================================

    @org.springframework.transaction.annotation.Transactional
    public LoginResponse googleLogin(GoogleLoginRequest googleLoginRequest) {
        GoogleIdToken idToken;
        try {
            idToken = googleIdTokenVerifier.verify(googleLoginRequest.getIdToken());
        } catch (Exception e) {
            throw new ApiException("Google authentication failed: invalid token.", HttpStatus.UNAUTHORIZED);
        }

        // NOTE: previously there was a fallback branch that parsed the token without
        // verifying its signature when verify() returned null. That accepted any
        // self-crafted "Google" token and let an attacker log in as anyone -- removed.
        if (idToken == null) {
            throw new ApiException("Google authentication failed: invalid token.", HttpStatus.UNAUTHORIZED);
        }

        GoogleIdToken.Payload payload = idToken.getPayload();
        if (payload == null || payload.getEmail() == null) {
            throw new ApiException("Google authentication failed: token has no email.", HttpStatus.UNAUTHORIZED);
        }

        final String email = normalizeEmail(payload.getEmail());
        String name = (String) payload.get("name");
        String pictureUrl = (String) payload.get("picture");

        User user = userRepository.findByEmail(email)
                .orElseGet(() -> {
                    Role userRole = roleRepository.findByRoleName("LEARNER")
                            .orElseGet(() -> {
                                Role newRole = Role.builder().roleName("LEARNER").build();
                                return roleRepository.save(newRole);
                            });

                    User newUser = User.builder()
                            .email(email)
                            .passwordHash(encoder.encode(UUID.randomUUID().toString()))
                            .fullName(name != null ? name : "Google User")
                            .avatarUrl(pictureUrl)
                            .roles(new HashSet<>(Collections.singletonList(userRole)))
                            .status("ACTIVE")
                            .isVerified(true)
                            .build();

                    return userRepository.save(newUser);
                });

        if (!"ACTIVE".equalsIgnoreCase(user.getStatus())) {
            logAudit(user, "LOGIN_FAILURE", user.getId(),
                    "Google login on non-active account, status=" + user.getStatus());
            throw new ApiException("Your account is not active. Please contact support.", HttpStatus.FORBIDDEN);
        }

        user.setLastLoginAt(LocalDateTime.now());
        User savedUser = userRepository.save(user);

        String jwt = jwtUtils.generateJwtTokenFromUsername(savedUser.getEmail());
        String refreshToken = issueRefreshToken(savedUser);

        List<String> userRoles = new java.util.ArrayList<>();
        for (org.springframework.security.core.GrantedAuthority authority : UserDetailsImpl.build(savedUser)
                .getAuthorities()) {
            userRoles.add(authority.getAuthority());
        }

        logAudit(savedUser, "LOGIN_SUCCESS", savedUser.getId(), "via Google");

        return new LoginResponse(jwt, refreshToken, savedUser.getId(), savedUser.getEmail(), savedUser.getFullName(),
                userRoles, savedUser.getAvatarUrl());
    }

    // =================================================================
    // forgotPassword / verifyOtp / resetPassword
    // =================================================================

    @org.springframework.transaction.annotation.Transactional
    public void forgotPassword(ForgotPasswordRequest request) {
        String email = normalizeEmail(request.getEmail());
        User user = userRepository.findByEmail(email).orElse(null);
        // Deliberately silent in both cases below: never reveal whether an email
        // is registered, and an unverified account has no active session/password
        // to "reset" anyway -- it must go through email verification first.
        if (user == null) {
            return;
        }
        if (!Boolean.TRUE.equals(user.getIsVerified()) || !"ACTIVE".equalsIgnoreCase(user.getStatus())) {
            return;
        }

        PasswordResetOtp existing = passwordResetOtpRepository.findTopByEmailOrderByIdDesc(email).orElse(null);
        if (existing != null && existing.getLastSentAt() != null
                && existing.getLastSentAt().isAfter(LocalDateTime.now().minusSeconds(OTP_RESEND_COOLDOWN_SECONDS))) {
            // Cooldown still active: no-op instead of spamming a new OTP/email.
            return;
        }

        passwordResetOtpRepository.deleteByEmail(email);

        String otpCode = String.format("%06d", SECURE_RANDOM.nextInt(1000000));

        PasswordResetOtp otp = PasswordResetOtp.builder()
                .email(email)
                .otpCode(otpCode)
                .expiryTime(LocalDateTime.now().plusMinutes(5))
                .lastSentAt(LocalDateTime.now())
                .build();

        passwordResetOtpRepository.save(otp);
        emailService.sendOtpEmail(email, otpCode);
        logAudit(user, "PASSWORD_RESET_REQUESTED", user.getId(), null);
    }

    public void verifyOtp(VerifyOtpRequest request) {
        String email = normalizeEmail(request.getEmail());
        PasswordResetOtp otp = passwordResetOtpRepository.findTopByEmailOrderByIdDesc(email)
                .orElseThrow(() -> new ApiException("Invalid OTP code.", HttpStatus.BAD_REQUEST));

        if (Boolean.TRUE.equals(otp.getConsumed())) {
            throw new ApiException("This OTP code has already been used.", HttpStatus.BAD_REQUEST);
        }

        if (otp.getExpiryTime().isBefore(LocalDateTime.now())) {
            passwordResetOtpRepository.delete(otp);
            throw new ApiException("OTP code has expired. Please request a new one.", HttpStatus.BAD_REQUEST);
        }

        if (!otp.getOtpCode().equals(request.getOtpCode())) {
            int attempts = (otp.getAttemptCount() == null ? 0 : otp.getAttemptCount()) + 1;
            if (attempts >= MAX_OTP_ATTEMPTS) {
                passwordResetOtpRepository.delete(otp);
                throw new ApiException("Too many incorrect attempts. Please request a new OTP.",
                        HttpStatus.BAD_REQUEST);
            }
            otp.setAttemptCount(attempts);
            passwordResetOtpRepository.save(otp);

            throw new ApiException("Invalid OTP code.", HttpStatus.BAD_REQUEST);
        }
    }

    @org.springframework.transaction.annotation.Transactional
    public void resetPassword(ResetPasswordRequest request) {
        String email = normalizeEmail(request.getEmail());

        PasswordResetOtp otp = passwordResetOtpRepository.findTopByEmailOrderByIdDesc(email)
                .orElseThrow(() -> new ApiException("Invalid or expired OTP code.", HttpStatus.BAD_REQUEST));

        if (Boolean.TRUE.equals(otp.getConsumed())) {
            throw new ApiException("Invalid or expired OTP code.", HttpStatus.BAD_REQUEST);
        }
        if (otp.getExpiryTime().isBefore(LocalDateTime.now())) {
            passwordResetOtpRepository.delete(otp);
            throw new ApiException("OTP code has expired. Please request a new one.", HttpStatus.BAD_REQUEST);
        }
        if (!otp.getOtpCode().equals(request.getOtpCode())) {
            throw new ApiException("Invalid or expired OTP code.", HttpStatus.BAD_REQUEST);
        }

        User user = userRepository.findByEmail(email)
                .orElseThrow(() -> new UsernameNotFoundException("User not found with email: " + email));

        if (encoder.matches(request.getNewPassword(), user.getPasswordHash())) {
            throw new ApiException("New password must be different from the current password.", HttpStatus.BAD_REQUEST);
        }

        user.setPasswordHash(encoder.encode(request.getNewPassword()));
        user.setFailedLoginAttempts(0);
        user.setLockedUntil(null);
        userRepository.save(user);

        // Single-use: this OTP (and any stray rows for the email) can never be
        // replayed.
        passwordResetOtpRepository.deleteByEmail(email);

        // Force re-login everywhere else too.
        //
        refreshTokenRepository.deleteByUser(user);

        logAudit(user, "PASSWORD_RESET", user.getId(), null);
    }

    // =================================================================
    // verifyAccount / resendVerificationEmail
    // =================================================================

    @org.springframework.transaction.annotation.Transactional
    public void verifyAccountByToken(String token) {
        User user = userRepository.findByVerificationToken(token)
                .orElseThrow(() -> new ApiException("Invalid verification link.", HttpStatus.BAD_REQUEST));

        if (Boolean.TRUE.equals(user.getIsVerified())) {
            throw new ApiException("This account has already been verified.", HttpStatus.BAD_REQUEST);
        }

        if (user.getVerificationTokenExpiry() == null
                || user.getVerificationTokenExpiry().isBefore(LocalDateTime.now())) {
            throw new ApiException("This verification link has expired. Please request a new one.",
                    HttpStatus.BAD_REQUEST);
        }

        user.setIsVerified(true);
        user.setStatus("ACTIVE");
        user.setVerificationToken(null);
        user.setVerificationTokenExpiry(null);
        userRepository.save(user);

        logAudit(user, "EMAIL_VERIFIED", user.getId(), null);
    }

    public void resendVerificationEmail(String email) {
        String normalizedEmail = normalizeEmail(email);
        User user = userRepository.findByEmail(normalizedEmail)
                .orElseThrow(() -> new UsernameNotFoundException("User not found with email: " + normalizedEmail));

        if (Boolean.TRUE.equals(user.getIsVerified())) {
            throw new ApiException("Account is already verified.", HttpStatus.BAD_REQUEST);
        }

        if (user.getVerificationTokenExpiry() != null) {
            LocalDateTime issuedAt = user.getVerificationTokenExpiry().minusHours(VERIFICATION_TOKEN_VALIDITY_HOURS);
            if (issuedAt.isAfter(LocalDateTime.now().minusSeconds(OTP_RESEND_COOLDOWN_SECONDS))) {
                throw new ApiException("Please wait before requesting another verification email.",
                        HttpStatus.TOO_MANY_REQUESTS);
            }
        }

        String newToken = UUID.randomUUID().toString();
        user.setVerificationToken(newToken);
        user.setVerificationTokenExpiry(LocalDateTime.now().plusHours(VERIFICATION_TOKEN_VALIDITY_HOURS));
        userRepository.save(user);

        try {
            emailService.sendVerificationEmail(normalizedEmail, newToken);
        } catch (Exception e) {
            throw new RuntimeException("Failed to send verification email: " + e.getMessage());
        }
    }

    public boolean isAccountVerified(String email) {
        return userRepository.findByEmail(normalizeEmail(email))
                .map(User::getIsVerified)
                .orElse(false);
    }

    // =================================================================
    // refreshAccessToken / logout
    // =================================================================

    @org.springframework.transaction.annotation.Transactional
    public TokenRefreshResponse refreshAccessToken(String rawRefreshToken) {
        String hash = jwtUtils.hashToken(rawRefreshToken);
        RefreshToken stored = refreshTokenRepository.findByTokenHash(hash)
                .orElseThrow(() -> new ApiException("Invalid refresh token.", HttpStatus.UNAUTHORIZED));

        if (Boolean.TRUE.equals(stored.getRevoked()) || stored.getExpiresAt().isBefore(LocalDateTime.now())) {
            throw new ApiException("Refresh token expired or revoked. Please log in again.", HttpStatus.UNAUTHORIZED);
        }

        User user = stored.getUser();
        if (!"ACTIVE".equalsIgnoreCase(user.getStatus()) || !Boolean.TRUE.equals(user.getIsVerified())) {
            throw new ApiException("Account is not eligible to refresh a session.", HttpStatus.FORBIDDEN);
        }

        // Rotate: revoke the presented token so it can't be replayed.
        stored.setRevoked(true);
        refreshTokenRepository.save(stored);

        String newAccessToken = jwtUtils.generateJwtTokenFromUsername(user.getEmail());
        String newRefreshToken = issueRefreshToken(user);

        List<String> roles = new java.util.ArrayList<>();
        for (org.springframework.security.core.GrantedAuthority authority : UserDetailsImpl.build(user)
                .getAuthorities()) {
            roles.add(authority.getAuthority());
        }

        return new TokenRefreshResponse(newAccessToken, newRefreshToken, roles);
    }

    @org.springframework.transaction.annotation.Transactional
    public void logout(String rawRefreshToken) {
        if (rawRefreshToken == null || rawRefreshToken.isBlank()) {
            return;
        }
        String hash = jwtUtils.hashToken(rawRefreshToken);
        refreshTokenRepository.findByTokenHash(hash).ifPresent(token -> {
            token.setRevoked(true);
            refreshTokenRepository.save(token);
        });
    }

    // =================================================================
    // profile
    // =================================================================

    public UserResponse getUserById(Long id) {
        User user = userRepository.findById(id)
                .orElseThrow(() -> new org.springframework.security.core.userdetails.UsernameNotFoundException(
                        "User not found with id: " + id));
        return mapToUserResponse(user);
    }

    public UserResponse getUserProfile(String email) {
        User user = userRepository.findByEmail(email)
                .orElseThrow(() -> new org.springframework.security.core.userdetails.UsernameNotFoundException(
                        "User not found with email: " + email));
        return mapToUserResponse(user);
    }

    @org.springframework.transaction.annotation.Transactional
    public UserResponse updateProfile(String email, ProfileUpdateRequest request) {
        User user = userRepository.findByEmail(email)
                .orElseThrow(() -> new org.springframework.security.core.userdetails.UsernameNotFoundException(
                        "User not found with email: " + email));

        if (request.getFullName() != null) {
            user.setFullName(request.getFullName());

        }
        if (request.getPhoneNumber() != null) {
            user.setPhoneNumber(request.getPhoneNumber());
        }
        if (request.getGender() != null) {
            user.setGender(request.getGender());
        }
        if (request.getDateOfBirth() != null) {
            user.setDateOfBirth(request.getDateOfBirth());
        }
        if (request.getAvatarUrl() != null) {
            user.setAvatarUrl(request.getAvatarUrl());
        }
        if (request.getUsername() != null && !request.getUsername().equalsIgnoreCase(user.getUsername())) {
            if (userRepository.existsByUsername(request.getUsername())) {
                throw new IllegalArgumentException("Error: Username is already in use!");
            }
            user.setUsername(request.getUsername());
        }
        if (request.getAddress() != null) {
            user.setAddress(request.getAddress());
        }

        if (request.getEmail() != null && !request.getEmail().equalsIgnoreCase(user.getEmail())) {
            if (userRepository.existsByEmail(request.getEmail())) {
                throw new IllegalArgumentException("Error: Email is already in use!");
            }
            user.setEmail(request.getEmail());
            user.setIsVerified(false);
        }

        User updatedUser = userRepository.save(user);
        return mapToUserResponse(updatedUser);
    }

    private UserResponse mapToUserResponse(User user) {
        List<String> roles = user.getRoles().stream()
                .map(Role::getRoleName)
                .collect(Collectors.toList());

        return UserResponse.builder()
                .id(user.getId())
                .email(user.getEmail())
                .fullName(user.getFullName())
                .phoneNumber(user.getPhoneNumber())
                .gender(user.getGender())
                .avatarUrl(user.getAvatarUrl())
                .username(user.getUsername())
                .address(user.getAddress())
                .roles(roles)
                .dateOfBirth(user.getDateOfBirth())
                .status(user.getStatus())
                .createdAt(user.getCreatedAt())
                .updatedAt(user.getUpdatedAt())
                .build();
    }

    @org.springframework.transaction.annotation.Transactional
    public void changePassword(String email, ChangePasswordRequest request) {
        String normalizedEmail = normalizeEmail(email);
        User user = userRepository.findByEmail(normalizedEmail)
                .orElseThrow(() -> new org.springframework.security.core.userdetails.UsernameNotFoundException(
                        "User not found with email: " + normalizedEmail));

        if (!encoder.matches(request.getCurrentPassword(), user.getPasswordHash())) {
            throw new ApiException("Incorrect current password.", HttpStatus.BAD_REQUEST);

        }

        if (encoder.matches(request.getNewPassword(), user.getPasswordHash())) {
            throw new ApiException("New password must be different from the current password.", HttpStatus.BAD_REQUEST);
        }

        user.setPasswordHash(encoder.encode(request.getNewPassword()));
        userRepository.save(user);

        refreshTokenRepository.deleteByUser(user);

        logAudit(user, "PASSWORD_CHANGED", user.getId(), null);
    }
}
