package com.hango.hango_backend.service;

import com.hango.hango_backend.dto.LoginRequest;
import com.hango.hango_backend.dto.LoginResponse;
import com.hango.hango_backend.dto.RegisterRequest;
import com.hango.hango_backend.dto.UserResponse;
import com.hango.hango_backend.entity.Role;
import com.hango.hango_backend.entity.User;
import com.hango.hango_backend.repository.RoleRepository;
import com.hango.hango_backend.repository.UserRepository;
import com.hango.hango_backend.sercurity.UserDetailsImpl;
import com.hango.hango_backend.util.JwtUtils;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.security.authentication.AuthenticationManager;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.GrantedAuthority;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.security.core.userdetails.UsernameNotFoundException;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.web.multipart.MultipartFile;
import org.springframework.beans.factory.annotation.Value;
import com.google.api.client.googleapis.auth.oauth2.GoogleIdToken;
import com.google.api.client.googleapis.auth.oauth2.GoogleIdTokenVerifier;
import com.google.api.client.http.javanet.NetHttpTransport;
import com.google.api.client.json.gson.GsonFactory;

import com.hango.hango_backend.dto.ForgotPasswordRequest;
import com.hango.hango_backend.dto.VerifyOtpRequest;
import com.hango.hango_backend.dto.ResetPasswordRequest;
import com.hango.hango_backend.entity.PasswordResetOtp;
import com.hango.hango_backend.repository.PasswordResetOtpRepository;
import java.io.IOException;
import java.time.LocalDateTime;
import java.util.Collections;
import java.util.HashSet;
import java.util.List;
import java.util.stream.Collectors;

@Service
public class AuthService {

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

    @Value("${google.client-id}")
    private String googleClientId;

    public LoginResponse authenticateUser(LoginRequest loginRequest) {
        Authentication authentication = authenticationManager.authenticate(
                new UsernamePasswordAuthenticationToken(loginRequest.getEmail(), loginRequest.getPassword()));

        UserDetailsImpl userDetails = (UserDetailsImpl) authentication.getPrincipal();
        
        // Fetch user from database to check their status
        User user = userRepository.findByEmail(userDetails.getUsername())
                .orElseThrow(() -> new UsernameNotFoundException("User not found with email: " + userDetails.getUsername()));

        if ("INACTIVE".equalsIgnoreCase(user.getStatus())) {
            throw new IllegalArgumentException("Your account is deactivated. Please contact support.");
        }

        SecurityContextHolder.getContext().setAuthentication(authentication);
        String jwt = jwtUtils.generateJwtToken(authentication);

        List<String> roles = userDetails.getAuthorities().stream()
                .map(GrantedAuthority::getAuthority)
                .collect(Collectors.toList());

        // Update last login timestamp
        user.setLastLoginAt(LocalDateTime.now());
        userRepository.save(user);

        return new LoginResponse(
                jwt,
                userDetails.getId(),
                userDetails.getUsername(),
                userDetails.getFullName(),
                roles
        );
    }

    public UserResponse registerUser(RegisterRequest registerRequest) {
        if (userRepository.existsByEmail(registerRequest.getEmail())) {
            throw new IllegalArgumentException("Error: Email is already in use!");
        }

        // Default role: LEARNER
        Role userRole = roleRepository.findByRoleName("LEARNER")
                .orElseGet(() -> {
                    Role newRole = Role.builder().roleName("LEARNER").build();
                    return roleRepository.save(newRole);
                });

        User user = User.builder()
                .email(registerRequest.getEmail())
                .passwordHash(encoder.encode(registerRequest.getPassword()))
                .fullName(registerRequest.getFullName())
                .phoneNumber(registerRequest.getPhoneNumber())
                .gender(registerRequest.getGender())
                .roles(new HashSet<>(Collections.singletonList(userRole)))
                .build();

        User savedUser = userRepository.save(user);

        try {
            emailService.sendVerificationEmail(savedUser.getEmail());
        } catch (Exception e) {
            System.err.println("Failed to send verification email: " + e.getMessage());
        }

        return mapToUserResponse(savedUser);
    }

    public UserResponse createUserByAdmin(RegisterRequest registerRequest) {
        if (userRepository.existsByEmail(registerRequest.getEmail())) {
            throw new IllegalArgumentException("Error: Email is already in use!");
        }

        // Admin-created role is: TRAINER
        Role userRole = roleRepository.findByRoleName("TRAINER")
                .orElseGet(() -> {
                    Role newRole = Role.builder().roleName("TRAINER").build();
                    return roleRepository.save(newRole);
                });

        User user = User.builder()
                .email(registerRequest.getEmail())
                .passwordHash(encoder.encode(registerRequest.getPassword()))
                .fullName(registerRequest.getFullName())
                .phoneNumber(registerRequest.getPhoneNumber())
                .gender(registerRequest.getGender())
                .roles(new java.util.HashSet<>(java.util.Collections.singletonList(userRole)))
                .isVerified(true) // Admin created accounts are verified by default
                .status("ACTIVE") // Default status ACTIVE
                .build();

        User savedUser = userRepository.save(user);
        return mapToUserResponse(savedUser);
    }


    public UserResponse updateAvatar(String email, MultipartFile file) throws IOException {
        User user = userRepository.findByEmail(email)
                .orElseThrow(() -> new UsernameNotFoundException("User not found with email: " + email));

        String imageUrl = cloudinaryService.uploadImage(file);
        user.setAvatarUrl(imageUrl);
        User updatedUser = userRepository.save(user);

        return mapToUserResponse(updatedUser);
    }

    @org.springframework.transaction.annotation.Transactional
    public LoginResponse googleLogin(com.hango.hango_backend.dto.GoogleLoginRequest googleLoginRequest) {
        String idTokenString = googleLoginRequest.getIdToken();
        try {
            GoogleIdTokenVerifier verifier = new GoogleIdTokenVerifier.Builder(
                    new NetHttpTransport(),
                    new GsonFactory())
                    .setAudience(Collections.singletonList(googleClientId))
                    .build();

            GoogleIdToken idToken = verifier.verify(idTokenString);
            if (idToken != null) {
                GoogleIdToken.Payload payload = idToken.getPayload();

                // Get profile information from payload
                String email = payload.getEmail();
                String name = (String) payload.get("name");
                String pictureUrl = (String) payload.get("picture");

                // Find or JIT-provision user
                User user = userRepository.findByEmail(email)
                        .orElseGet(() -> {
                            // Find or create ROLE_USER role
                            Role userRole = roleRepository.findByRoleName("ROLE_USER")
                                    .orElseGet(() -> {
                                        Role newRole = Role.builder().roleName("ROLE_USER").build();
                                        return roleRepository.save(newRole);
                                    });

                            User newUser = User.builder()
                                    .email(email)
                                    .passwordHash(encoder.encode(java.util.UUID.randomUUID().toString()))
                                    .fullName(name != null ? name : "Google User")
                                    .avatarUrl(pictureUrl)
                                    .roles(new HashSet<>(Collections.singletonList(userRole)))
                                    .status("ACTIVE")
                                    .isVerified(true)
                                    .build();
                            
                            return userRepository.save(newUser);
                        });

                if ("INACTIVE".equalsIgnoreCase(user.getStatus())) {
                    throw new IllegalArgumentException("Your account is deactivated. Please contact support.");
                }

                user.setLastLoginAt(LocalDateTime.now());
                User savedUser = userRepository.save(user);

                // Generate internal JWT token from the user's email
                String jwt = jwtUtils.generateJwtTokenFromUsername(savedUser.getEmail());

                List<String> roles = savedUser.getRoles().stream()
                        .map(Role::getRoleName)
                        .collect(Collectors.toList());

                return new LoginResponse(
                        jwt,
                        savedUser.getId(),
                        savedUser.getEmail(),
                        savedUser.getFullName(),
                        roles
                );
            } else {
                throw new IllegalArgumentException("Invalid ID Token");
            }
        } catch (Exception e) {
            throw new IllegalArgumentException("Google authentication failed: " + e.getMessage());
        }
    }

    @org.springframework.transaction.annotation.Transactional
    public void forgotPassword(ForgotPasswordRequest request) {
        String email = request.getEmail();
        if (!userRepository.existsByEmail(email)) {
            throw new IllegalArgumentException("Email is not registered in the system.");
        }

        // Delete any existing OTPs for this email
        passwordResetOtpRepository.deleteByEmail(email);

        // Generate 6 digit OTP
        String otpCode = String.format("%06d", new java.util.Random().nextInt(1000000));

        PasswordResetOtp otp = PasswordResetOtp.builder()
                .email(email)
                .otpCode(otpCode)
                .expiryTime(LocalDateTime.now().plusMinutes(5))
                .build();

        passwordResetOtpRepository.save(otp);

        // Send Email
        emailService.sendOtpEmail(email, otpCode);
    }

    public void verifyOtp(VerifyOtpRequest request) {
        PasswordResetOtp otp = passwordResetOtpRepository.findByEmailAndOtpCode(request.getEmail(), request.getOtpCode())
                .orElseThrow(() -> new IllegalArgumentException("Invalid OTP code."));

        if (otp.getExpiryTime().isBefore(LocalDateTime.now())) {
            passwordResetOtpRepository.delete(otp);
            throw new IllegalArgumentException("OTP code has expired. Please request a new one.");
        }
    }

    @org.springframework.transaction.annotation.Transactional
    public void resetPassword(ResetPasswordRequest request) {
        User user = userRepository.findByEmail(request.getEmail())
                .orElseThrow(() -> new UsernameNotFoundException("User not found with email: " + request.getEmail()));

        // Encode and set new password
        user.setPasswordHash(encoder.encode(request.getNewPassword()));
        userRepository.save(user);

        // Clean up OTPs
        passwordResetOtpRepository.deleteByEmail(request.getEmail());
    }

    @org.springframework.transaction.annotation.Transactional
    public void verifyAccount(String email) {
        User user = userRepository.findByEmail(email)
                .orElseThrow(() -> new org.springframework.security.core.userdetails.UsernameNotFoundException("User not found with email: " + email));
        user.setIsVerified(true);
        userRepository.save(user);
    }

    public void resendVerificationEmail(String email) {
        User user = userRepository.findByEmail(email)
                .orElseThrow(() -> new org.springframework.security.core.userdetails.UsernameNotFoundException("User not found with email: " + email));

        if (Boolean.TRUE.equals(user.getIsVerified())) {
            throw new IllegalArgumentException("Account is already verified.");
        }

        try {
            emailService.sendVerificationEmail(email);
        } catch (Exception e) {
            throw new RuntimeException("Failed to send verification email: " + e.getMessage());
        }
    }


    public boolean isAccountVerified(String email) {
        return userRepository.findByEmail(email)
                .map(User::getIsVerified)
                .orElse(false);
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
                .roles(roles)
                .build();
    }
}
