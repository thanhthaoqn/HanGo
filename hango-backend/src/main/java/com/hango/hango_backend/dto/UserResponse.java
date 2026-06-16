package com.hango.hango_backend.dto;

import lombok.Builder;
import lombok.Data;
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
    private List<String> roles;
}
