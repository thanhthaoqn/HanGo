package com.hango.hango_backend.entity;

import jakarta.persistence.*;
import lombok.*;
import java.time.LocalDateTime;

@Entity
@Table(name = "trainer_profiles")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class TrainerProfile {

    @Id
    @Column(name = "user_id")
    private Long userId;

    @OneToOne(fetch = FetchType.LAZY)
    @MapsId
    @JoinColumn(name = "user_id")
    private User user;

    @Column(name = "trainer_type", length = 50)
    private String trainerType; // PROFESSIONAL | PEER_TUTOR

    @Column(name = "revenue_share")
    private Double revenueShare;

    @Column(columnDefinition = "TEXT")
    private String bio;

    @Column(name = "workplace", length = 255)
    private String workplace;

    // certifications (Cloudinary urls & JSON arrays)
    @Column(name = "score_report_url", columnDefinition = "LONGTEXT")
    private String scoreReportUrl;

    @Column(name = "pedagogical_degree_url", columnDefinition = "LONGTEXT")
    private String pedagogicalDegreeUrl;

    @Column(name = "cv_url", columnDefinition = "LONGTEXT")
    private String cvUrl;

    // payout settings
    @Column(name = "bank_name", length = 100)
    private String bankName;

    @Column(name = "bank_account", length = 50)
    private String bankAccount;

    @Column(name = "bank_account_name", length = 100)
    private String bankAccountName;

    @Column(name = "tax_code", length = 50)
    private String taxCode;

    @Column(name = "citizen_id", length = 50)
    private String citizenId;

    @Column(name = "agreement_signed")
    @Builder.Default
    private Boolean agreementSigned = false;

    @Column(length = 50)
    @Builder.Default
    private String status = "PENDING_VERIFICATION"; // PENDING_VERIFICATION | AWAITING_APPROVAL | VERIFIED | SUSPENDED

    @Column(name = "submitted_at")
    private LocalDateTime submittedAt;

    @Column(name = "reviewed_at")
    private LocalDateTime reviewedAt;

    @Column(name = "admin_notes", columnDefinition = "TEXT")
    private String adminNotes;
}
