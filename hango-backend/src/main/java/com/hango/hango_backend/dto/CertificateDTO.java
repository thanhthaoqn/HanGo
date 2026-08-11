package com.hango.hango_backend.dto;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.LocalDateTime;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class CertificateDTO {
    private String credentialId;
    private String learnerName;
    private String courseTitle;
    private String trainerName;
    private String trainerSignatureUrl;
    private LocalDateTime issuedAt;
}
