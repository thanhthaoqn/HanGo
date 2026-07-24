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
public class PaymentHistoryDTO {
    private Long id;
    private String txnRef;
    private Long courseId;
    private String courseTitle;
    private String courseThumbnail;
    private BigDecimal amount;
    private String status;
    private String bankCode;
    private String vnpayTxnNo;
    private LocalDateTime paidAt;
    private LocalDateTime createdAt;
}
