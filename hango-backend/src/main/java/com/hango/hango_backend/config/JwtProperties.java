package com.hango.hango_backend.config;

import org.springframework.boot.context.properties.ConfigurationProperties;
import lombok.Getter;
import lombok.Setter;

@Getter
@Setter
@ConfigurationProperties(prefix = "hango.jwt")
public class JwtProperties {
    private String secret;
    private long expirationMs;
}