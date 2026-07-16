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

    private String slogan;

    @Column(columnDefinition = "TEXT")
    private String bio;

    @Column(name = "workplace", length = 255)
    private String workplace;

    // target ranges
    @Column(name = "target_low_range")
    @Builder.Default
    private Boolean targetLowRange = false;

    @Column(name = "target_mid_range")
    @Builder.Default
    private Boolean targetMidRange = false;

    @Column(name = "target_high_range")
    @Builder.Default
    private Boolean targetHighRange = false;

    // course formats
    @Column(name = "format_exam_prep")
    @Builder.Default
    private Boolean formatExamPrep = false;

    @Column(name = "format_grammar_vocab")
    @Builder.Default
    private Boolean formatGrammarVocab = false;

    @Column(name = "format_reading")
    @Builder.Default
    private Boolean formatReading = false;

    @Column(name = "format_last_minute")
    @Builder.Default
    private Boolean formatLastMinute = false;

    // certifications (Cloudinary urls)
    @Column(name = "degree_url", length = 500)
    private String degreeUrl;

    @Column(name = "ielts_url", length = 500)
    private String ieltsUrl;

    @Column(name = "score_report_url", length = 500)
    private String scoreReportUrl;

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
