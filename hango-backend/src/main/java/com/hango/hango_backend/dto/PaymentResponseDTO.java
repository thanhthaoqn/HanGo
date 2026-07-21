package com.hango.hango_backend.dto;

import lombok.Builder;
import lombok.Data;

import java.math.BigDecimal;

@Data
@Builder
public class PaymentResponseDTO {
    private String paymentUrl;
    private String qrCode;
    private String txnRef;
    private BigDecimal amount;
    private String courseTitle;
}
