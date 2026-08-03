package com.hango.hango_backend.dto;

import lombok.AllArgsConstructor;
import lombok.Data;
import java.util.List;

@Data
@AllArgsConstructor
public class LoginResponse {
    private String token;
    private String refreshToken;
    private Long id;
    private String email;
    private String fullName;
    private List<String> roles;
    private String avatarUrl;

    // Pre-refresh-token call sites (outside the auth module) keep compiling against
    // this shape; they simply won't carry a refresh token.
    public LoginResponse(String token, Long id, String email, String fullName, List<String> roles, String avatarUrl) {
        this(token, null, id, email, fullName, roles, avatarUrl);
    }
}
