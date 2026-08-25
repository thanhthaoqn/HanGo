package com.hango.hango_backend.dto;

import com.fasterxml.jackson.annotation.JsonIgnoreProperties;
import jakarta.validation.Valid;
import jakarta.validation.constraints.Size;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.List;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
@JsonIgnoreProperties(ignoreUnknown = true)
public class TrainerProfileDTO {
    private Long userId;
    private String trainerType; // PROFESSIONAL | PEER_TUTOR
    private Double revenueShare;
    @Size(max = 5000)
    private String bio;

    // documents
    private String scoreReportUrl;
    private String pedagogicalDegreeUrl;
    private String cvUrl;
    @Valid
    @Size(max = 10)
    private List<TrainerDocumentDTO> certificates;

    // payout
    private String bankName;
    private String bankAccount;
    private String bankAccountName;
    private String taxCode;
    private String citizenId;

    // status & agreement
    private Boolean agreementSigned;
    private String agreementVersion;
    private LocalDateTime agreementAcceptedAt;
    private String status;
    private LocalDateTime submittedAt;
    private LocalDateTime reviewedAt;
    private String adminNotes;

    // User info
    private String fullName;
    private String email;
    private String phoneNumber;
    private String gender;
    private String avatarUrl;
    private String username;
    private LocalDate dateOfBirth;
    private String address;
}
