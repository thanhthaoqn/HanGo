package com.hango.hango_backend.dto;

import com.hango.hango_backend.util.PasswordPolicy;
import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;
import lombok.Data;
import java.time.LocalDate;

@Data
public class RegisterRequest {
    @NotBlank
    @Email
    @Size(max = 254)
    private String email;

    @NotBlank
    @Pattern(regexp = PasswordPolicy.PATTERN, message = PasswordPolicy.MESSAGE)
    private String password;

    // Not @NotBlank: only self-service registerUser() enforces this (matched against
    // password); createUserByAdmin() ignores it so the admin-create-user endpoint's
    // contract stays unchanged.
    private String confirmPassword;

    @NotBlank
    @Size(max = 150)
    private String fullName;

    @Size(max = 20)
    private String phoneNumber;
    private String gender;
    private String role;
    private LocalDate dateOfBirth;
}
