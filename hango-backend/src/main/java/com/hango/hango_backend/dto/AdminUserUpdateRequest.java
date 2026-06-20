package com.hango.hango_backend.dto;

import lombok.Data;
import java.time.LocalDate;

@Data
public class AdminUserUpdateRequest {
    private String fullName;
    private String email;
    private String gender;
    private String phoneNumber;
    private String role;
    private LocalDate dateOfBirth;
    private String status;
}
