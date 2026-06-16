package com.hango.hango_backend.dto;

import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;
import lombok.Data;

@Data
public class RegisterRequest {
    @NotBlank
    @Email
    private String email;

    @NotBlank
    @Size(min = 8, max = 32)
    private String password;

    @NotBlank
    private String fullName;

    private String phoneNumber;
    private String gender;
}
