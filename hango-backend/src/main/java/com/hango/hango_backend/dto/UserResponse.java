package com.hango.hango_backend.dto;

import lombok.Builder;
import lombok.Data;
import java.time.LocalDate;
import java.util.List;

@Data
@Builder
public class UserResponse {
    private Long id;
    private String email;
    private String fullName;
    private String phoneNumber;
    private String gender;
    private String avatarUrl;
    private String username;
    private String address;
    private List<String> roles;
    private LocalDate dateOfBirth;
    private String status;
    private java.time.LocalDateTime createdAt;
    private java.time.LocalDateTime updatedAt;
}
