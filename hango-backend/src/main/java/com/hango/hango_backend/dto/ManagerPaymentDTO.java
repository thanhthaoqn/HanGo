package com.hango.hango_backend.dto;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.math.BigDecimal;
import java.time.LocalDateTime;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class ManagerPaymentDTO {
    private Long id;
    private String txnRef;
    private Long learnerId;
    private String learnerName;
    private String learnerEmail;
    private Long courseId;
    private String courseTitle;
    private Long trainerId;
    private String trainerName;
    private BigDecimal amount;
    private BigDecimal platformFee;
    private BigDecimal trainerEarnings;
    private String status;
    private String settlementStatus;
    private Long statementId;
    private String bankCode;
    private String vnpayTxnNo;
    private LocalDateTime paidAt;
    private LocalDateTime createdAt;
}
