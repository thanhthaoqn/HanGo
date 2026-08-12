package com.hango.hango_backend.dto;

import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.util.List;

@Data
@NoArgsConstructor
@AllArgsConstructor
public class TokenRefreshResponse {
    private String token;
    private String refreshToken;
    private List<String> roles;
}
