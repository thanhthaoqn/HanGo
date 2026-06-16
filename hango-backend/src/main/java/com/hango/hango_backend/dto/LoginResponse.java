package com.hango.hango_backend.dto;

import lombok.AllArgsConstructor;
import lombok.Data;
import java.util.List;

@Data
@AllArgsConstructor
public class LoginResponse {
    private String token;
    private Long id;
    private String email;
    private String fullName;
    private List<String> roles;
}
