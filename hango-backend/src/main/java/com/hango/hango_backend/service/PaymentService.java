package com.hango.hango_backend.service;

import com.hango.hango_backend.dto.PaymentHistoryDTO;
import com.hango.hango_backend.dto.PaymentResponseDTO;
import com.hango.hango_backend.dto.PaymentStatusDTO;
import org.springframework.data.domain.Page;

import java.util.List;
import java.util.Map;

public interface PaymentService {
    PaymentResponseDTO createPayment(Long courseId, Long userId, String ipAddress, String origin);
    PaymentResponseDTO createPayment(com.hango.hango_backend.dto.PaymentRequestDTO request, Long userId, String ipAddress, String origin);
    void handlePayOSWebhook(Map<String, Object> payload);
    PaymentStatusDTO getPaymentStatus(String txnRef, Long userId);
    List<PaymentHistoryDTO> getMyPaymentHistory(Long userId);
    Page<PaymentHistoryDTO> getMyPaymentHistory(Long userId, String status, int page, int size);
    Page<com.hango.hango_backend.dto.ManagerPaymentDTO> getAllPaymentsForManager(String status, String settlementStatus, String search, int page, int size);
    byte[] exportPaymentsToExcel(String status, String settlementStatus, String search);
}

