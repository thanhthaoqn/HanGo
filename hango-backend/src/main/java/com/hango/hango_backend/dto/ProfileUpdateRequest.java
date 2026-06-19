package com.hango.hango_backend.dto;

import lombok.Data;
import java.time.LocalDate;

@Data
public class ProfileUpdateRequest {
    private String fullName;
    private String email;
    private String gender;
    private String phoneNumber;
    private String avatarUrl;
    private LocalDate dateOfBirth;
}
