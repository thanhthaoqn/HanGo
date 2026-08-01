package com.hango.hango_backend.dto;

import lombok.*;
import java.math.BigDecimal;
import java.time.LocalDateTime;

@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class MonthlyStatementDTO {
    private Long id;
    private String statementCode;
    private Long trainerId;
    private String trainerName;
    private String trainerEmail;
    private String trainerType; // PROFESSIONAL | PEER_TUTOR
    private String periodMonth;
    private Integer totalOrders;
    private BigDecimal totalGrossAmount;
    private BigDecimal totalPlatformFee;
    private BigDecimal totalTrainerGross;
    private BigDecimal pitTaxAmount;
    private BigDecimal netPayoutAmount;
    private String bankName;
    private String bankAccount;
    private String bankAccountName;
    private String status;
    private LocalDateTime trainerConfirmedAt;
    private LocalDateTime paidAt;
    private String bankTxnRef;
    private String adminNotes;
    private String payoutReceiptUrl;
    private LocalDateTime createdAt;

}
