package com.hango.hango_backend.dto;

import lombok.Data;
import java.time.LocalDate;
import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Pattern;

@Data
public class ProfileUpdateRequest {
    @NotBlank(message = "Full name cannot be blank")
    private String fullName;

    @NotBlank(message = "Email cannot be blank")
    @Email(message = "Email is not valid")
    private String email;

    private String gender;

    @Pattern(regexp = "^(0[3|5|7|8|9])+([0-9]{8})$", message = "Please enter a valid 10-digit Vietnamese phone number")
    private String phoneNumber;

    private String avatarUrl;

    @NotBlank(message = "Username cannot be blank")
    private String username;

    private String address;
    private LocalDate dateOfBirth;
}
