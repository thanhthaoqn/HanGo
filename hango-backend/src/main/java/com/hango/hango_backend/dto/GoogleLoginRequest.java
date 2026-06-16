package com.hango.hango_backend.dto;

import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;
import lombok.Data;

@Data
public class GoogleLoginRequest {
    @NotBlank
    @Email
    private String email;

    @NotBlank
    private String fullName;

    private String avatarUrl;
    private String googleId;
}
