package com.hango.hango_backend.entity;

import jakarta.persistence.*;
import lombok.*;
import java.math.BigDecimal;
import java.time.LocalDateTime;

@Entity
@Table(name = "monthly_statements")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class MonthlyStatement {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "statement_code", nullable = false, unique = true, length = 50)
    private String statementCode;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "trainer_id", nullable = false)
    private User trainer;

    @Column(name = "period_month", nullable = false, length = 10)
    private String periodMonth; // e.g. "2026-07"

    @Builder.Default
    @Column(name = "total_orders")
    private Integer totalOrders = 0;

    @Builder.Default
    @Column(name = "total_gross_amount", precision = 12, scale = 2)
    private BigDecimal totalGrossAmount = BigDecimal.ZERO;

    @Builder.Default
    @Column(name = "total_platform_fee", precision = 12, scale = 2)
    private BigDecimal totalPlatformFee = BigDecimal.ZERO;

    @Builder.Default
    @Column(name = "total_trainer_gross", precision = 12, scale = 2)
    private BigDecimal totalTrainerGross = BigDecimal.ZERO;

    @Builder.Default
    @Column(name = "pit_tax_amount", precision = 12, scale = 2)
    private BigDecimal pitTaxAmount = BigDecimal.ZERO;

    @Builder.Default
    @Column(name = "net_payout_amount", precision = 12, scale = 2)
    private BigDecimal netPayoutAmount = BigDecimal.ZERO;

    @Column(name = "bank_name", length = 100)
    private String bankName;

    @Column(name = "bank_account", length = 50)
    private String bankAccount;

    @Column(name = "bank_account_name", length = 100)
    private String bankAccountName;

    @Builder.Default
    @Column(name = "status", length = 30)
    private String status = "PENDING_TRAINER_CONFIRM"; // DRAFT, PENDING_TRAINER_CONFIRM, TRAINER_CONFIRMED, PAID

    @Column(name = "trainer_confirmed_at")
    private LocalDateTime trainerConfirmedAt;

    @Column(name = "paid_at")
    private LocalDateTime paidAt;

    @Column(name = "bank_txn_ref", length = 100)
    private String bankTxnRef;

    @Column(name = "admin_notes", columnDefinition = "TEXT")
    private String adminNotes;

    @Column(name = "payout_receipt_url", length = 500)
    private String payoutReceiptUrl;

    @Column(name = "created_at", insertable = false, updatable = false)
    private LocalDateTime createdAt;

}
