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
public class TrainerProfileDTO {
    private Long userId;
    private String trainerType; // PROFESSIONAL | PEER_TUTOR
    private Double revenueShare;
    private String slogan;
    private String bio;
    private String workplace;

    // targets
    private Boolean targetLowRange;
    private Boolean targetMidRange;
    private Boolean targetHighRange;

    // formats
    private Boolean formatExamPrep;
    private Boolean formatGrammarVocab;
    private Boolean formatReading;
    private Boolean formatLastMinute;

    // documents
    private String degreeUrl;
    private String ieltsUrl;
    private String scoreReportUrl;

    // payout
    private String bankName;
    private String bankAccount;
    private String bankAccountName;
    private String taxCode;
    private String citizenId;

    // status & agreement
    private Boolean agreementSigned;
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
}
