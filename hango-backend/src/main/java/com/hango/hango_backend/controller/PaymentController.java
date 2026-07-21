package com.hango.hango_backend.controller;

import com.hango.hango_backend.dto.PaymentRequestDTO;
import com.hango.hango_backend.dto.PaymentResponseDTO;
import com.hango.hango_backend.dto.PaymentStatusDTO;
import com.hango.hango_backend.sercurity.UserDetailsImpl;
import com.hango.hango_backend.service.PaymentService;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

import java.io.IOException;
import java.util.HashMap;
import java.util.Map;

@Slf4j
@RestController
@RequestMapping("/api/v1/payment")
@RequiredArgsConstructor
public class PaymentController {

    private final PaymentService paymentService;

    /**
     * Tạo URL thanh toán VNPay cho khóa học
     * POST /api/v1/payment/create
     */
    @PostMapping("/create")
    public ResponseEntity<?> createPayment(
            @RequestBody PaymentRequestDTO request,
            @AuthenticationPrincipal UserDetailsImpl currentUser,
            HttpServletRequest httpRequest) {
        try {
            if (currentUser == null) {
                return ResponseEntity.status(401).body(Map.of("error", "Unauthorized"));
            }

            String ipAddress = getClientIpAddress(httpRequest);
            String origin = httpRequest.getHeader("Origin");
            PaymentResponseDTO response = paymentService.createPayment(
                    request.getCourseId(),
                    currentUser.getId(),
                    ipAddress,
                    origin);

            return ResponseEntity.ok(response);
        } catch (Exception e) {
            log.error("Error creating payment", e);
            return ResponseEntity.status(500).body(Map.of("error", e.getMessage()));
        }
    }

    /**
     * PayOS webhook endpoint
     * POST /api/v1/payment/payos-webhook
     */
    @PostMapping("/payos-webhook")
    public ResponseEntity<?> handlePayOSWebhook(@RequestBody Map<String, Object> payload) {
        log.info("PayOS Webhook callback received: {}", payload);
        try {
            paymentService.handlePayOSWebhook(payload);
            return ResponseEntity.ok(Map.of("success", true));
        } catch (Exception e) {
            log.error("Error handling PayOS webhook", e);
            return ResponseEntity.status(400).body(Map.of("error", e.getMessage()));
        }
    }

    /**
     * Kiểm tra trạng thái giao dịch (Frontend polling)
     * GET /api/v1/payment/status/{txnRef}
     */
    @GetMapping("/status/{txnRef}")
    public ResponseEntity<?> getPaymentStatus(
            @PathVariable String txnRef,
            @AuthenticationPrincipal UserDetailsImpl currentUser) {
        try {
            if (currentUser == null) {
                return ResponseEntity.status(401).body(Map.of("error", "Unauthorized"));
            }

            PaymentStatusDTO status = paymentService.getPaymentStatus(txnRef, currentUser.getId());
            return ResponseEntity.ok(status);
        } catch (Exception e) {
            log.error("Error getting payment status for txnRef={}", txnRef, e);
            return ResponseEntity.status(404).body(Map.of("error", e.getMessage()));
        }
    }

    private String getClientIpAddress(HttpServletRequest request) {
        String xForwardedFor = request.getHeader("X-Forwarded-For");
        if (xForwardedFor != null && !xForwardedFor.isEmpty()) {
            return xForwardedFor.split(",")[0].trim();
        }
        String remoteAddr = request.getRemoteAddr();
        // VNPay không chấp nhận IPv6 loopback
        if ("0:0:0:0:0:0:0:1".equals(remoteAddr) || "::1".equals(remoteAddr)) {
            return "127.0.0.1";
        }
        return remoteAddr;
    }
}
