package com.hango.hango_backend.service;

import com.hango.hango_backend.dto.PaymentResponseDTO;
import com.hango.hango_backend.dto.PaymentStatusDTO;

import java.util.Map;

public interface PaymentService {
    PaymentResponseDTO createPayment(Long courseId, Long userId, String ipAddress, String origin);
    void handlePayOSWebhook(Map<String, Object> payload);
    PaymentStatusDTO getPaymentStatus(String txnRef, Long userId);
}
