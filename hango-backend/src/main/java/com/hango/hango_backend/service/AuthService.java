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

    public LoginResponse authenticateUser(LoginRequest loginRequest) {
        Authentication authentication = authenticationManager.authenticate(
                new UsernamePasswordAuthenticationToken(loginRequest.getEmail(), loginRequest.getPassword()));

        SecurityContextHolder.getContext().setAuthentication(authentication);
        String jwt = jwtUtils.generateJwtToken(authentication);

        UserDetailsImpl userDetails = (UserDetailsImpl) authentication.getPrincipal();
        List<String> roles = userDetails.getAuthorities().stream()
                .map(GrantedAuthority::getAuthority)
                .collect(Collectors.toList());

        // Update last login timestamp
        userRepository.findByEmail(userDetails.getUsername()).ifPresent(user -> {
            user.setLastLoginAt(LocalDateTime.now());
            userRepository.save(user);
        });

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
        String email = googleLoginRequest.getEmail();
        
        User user = userRepository.findByEmail(email)
                .orElseGet(() -> {
                    Role userRole = roleRepository.findByRoleName("LEARNER")
                            .orElseGet(() -> {
                                Role newRole = Role.builder().roleName("LEARNER").build();
                                return roleRepository.save(newRole);
                            });

                    User newUser = User.builder()
                            .email(email)
                            .passwordHash(encoder.encode(java.util.UUID.randomUUID().toString()))
                            .fullName(googleLoginRequest.getFullName())
                            .avatarUrl(googleLoginRequest.getAvatarUrl())
                            .roles(new HashSet<>(Collections.singletonList(userRole)))
                            .build();
                    
                    return userRepository.save(newUser);
                });

        if ((user.getAvatarUrl() == null || user.getAvatarUrl().isEmpty()) && googleLoginRequest.getAvatarUrl() != null) {
            user.setAvatarUrl(googleLoginRequest.getAvatarUrl());
        }

        user.setLastLoginAt(LocalDateTime.now());
        User savedUser = userRepository.save(user);

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
