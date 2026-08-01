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
                    request,
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
     * Lấy danh sách lịch sử giao dịch của Learner (có phân trang & lọc trạng thái)
     * GET /api/v1/payment/my-history?page=0&size=10&status=ALL
     */
    @GetMapping("/my-history")
    public ResponseEntity<?> getMyPaymentHistory(
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "10") int size,
            @RequestParam(defaultValue = "ALL") String status,
            @AuthenticationPrincipal UserDetailsImpl currentUser) {
        try {
            if (currentUser == null) {
                return ResponseEntity.status(401).body(Map.of("error", "Unauthorized"));
            }

            return ResponseEntity.ok(paymentService.getMyPaymentHistory(currentUser.getId(), status, page, size));
        } catch (Exception e) {
            log.error("Error fetching payment history for userId={}", currentUser != null ? currentUser.getId() : null, e);
            return ResponseEntity.status(500).body(Map.of("error", e.getMessage()));
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

    /**
     * Lấy danh sách toàn bộ giao dịch mua khóa học cho Course Manager
     * GET /api/v1/payment/manager/all
     */
    @GetMapping("/manager/all")
    @org.springframework.security.access.prepost.PreAuthorize("hasAnyAuthority('TRAINER_LEAD', 'COURSE_MANAGER', 'ADMINISTRATOR', 'ROLE_TRAINER_LEAD', 'ROLE_COURSE_MANAGER', 'ROLE_ADMINISTRATOR')")
    public ResponseEntity<?> getAllPaymentsForManager(
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "20") int size,
            @RequestParam(required = false) String status,
            @RequestParam(required = false) String settlementStatus,
            @RequestParam(required = false) String search) {
        try {
            return ResponseEntity.ok(paymentService.getAllPaymentsForManager(status, settlementStatus, search, page, size));
        } catch (Exception e) {
            log.error("Error fetching all payments for manager", e);
            return ResponseEntity.status(500).body(Map.of("error", e.getMessage()));
        }
    }

    /**
     * Xuất danh sách toàn bộ giao dịch mua khóa học ra file Excel (.xlsx)
     * GET /api/v1/payment/manager/export-excel
     */
    @GetMapping("/manager/export-excel")
    @org.springframework.security.access.prepost.PreAuthorize("hasAnyAuthority('TRAINER_LEAD', 'COURSE_MANAGER', 'ADMINISTRATOR', 'ROLE_TRAINER_LEAD', 'ROLE_COURSE_MANAGER', 'ROLE_ADMINISTRATOR')")
    public ResponseEntity<byte[]> exportPaymentsToExcel(
            @RequestParam(required = false) String status,
            @RequestParam(required = false) String settlementStatus,
            @RequestParam(required = false) String search) {
        byte[] excelBytes = paymentService.exportPaymentsToExcel(status, settlementStatus, search);
        String filename = "HanGo_Payment_Transactions.xlsx";
        return ResponseEntity.ok()
                .header(org.springframework.http.HttpHeaders.CONTENT_DISPOSITION, "attachment; filename=\"" + filename + "\"")
                .header(org.springframework.http.HttpHeaders.CONTENT_TYPE, "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet")
                .body(excelBytes);
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
