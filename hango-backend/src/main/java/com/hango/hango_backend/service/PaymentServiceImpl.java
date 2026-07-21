package com.hango.hango_backend.service;

import com.hango.hango_backend.dto.PaymentResponseDTO;
import com.hango.hango_backend.dto.PaymentStatusDTO;
import com.hango.hango_backend.entity.Course;
import com.hango.hango_backend.entity.Enrollment;
import com.hango.hango_backend.entity.Payment;
import com.hango.hango_backend.entity.User;
import com.hango.hango_backend.repository.CourseRepository;
import com.hango.hango_backend.repository.EnrollmentRepository;
import com.hango.hango_backend.repository.PaymentRepository;
import com.hango.hango_backend.repository.UserRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpEntity;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.client.RestTemplate;

import javax.crypto.Mac;
import javax.crypto.spec.SecretKeySpec;
import java.math.BigDecimal;
import java.nio.charset.StandardCharsets;
import java.time.LocalDateTime;
import java.util.HashMap;
import java.util.Map;
import java.util.TreeMap;

@Slf4j
@Service
@RequiredArgsConstructor
public class PaymentServiceImpl implements PaymentService {

    private final PaymentRepository paymentRepository;
    private final CourseRepository courseRepository;
    private final UserRepository userRepository;
    private final EnrollmentRepository enrollmentRepository;

    @Value("${payos.client-id}")
    private String clientId;

    @Value("${payos.api-key}")
    private String apiKey;

    @Value("${payos.checksum-key}")
    private String checksumKey;

    @Override
    @Transactional
    public PaymentResponseDTO createPayment(Long courseId, Long userId, String ipAddress, String origin) {
        Course course = courseRepository.findById(courseId)
                .orElseThrow(() -> new RuntimeException("Course not found"));
        User user = userRepository.findById(userId)
                .orElseThrow(() -> new RuntimeException("User not found"));

        // Giá mặc định 50,000 VND nếu chưa có price trên course
        BigDecimal amount = (course.getPrice() != null && course.getPrice().compareTo(BigDecimal.ZERO) > 0)
                ? course.getPrice()
                : new BigDecimal("50000");

        // 1. Tạo payment PENDING để lấy ID làm orderCode duy nhất
        Payment payment = Payment.builder()
                .user(user)
                .course(course)
                .amount(amount)
                .status("PENDING")
                .txnRef("") // Sẽ cập nhật bằng ID sau
                .build();
        payment = paymentRepository.save(payment);

        long orderCode = payment.getId();
        String txnRef = String.valueOf(orderCode);
        payment.setTxnRef(txnRef);
        paymentRepository.save(payment);

        // 2. Chuẩn bị request cho PayOS
        String description = "Hango " + orderCode;
        String frontendBaseUrl = (origin != null && !origin.isEmpty()) ? origin : "https://hangog92.online";
        if (frontendBaseUrl.endsWith("/")) {
            frontendBaseUrl = frontendBaseUrl.substring(0, frontendBaseUrl.length() - 1);
        }
        String cancelUrl = frontendBaseUrl + "/#/payment-failed";
        String returnUrl = frontendBaseUrl + "/#/payment-success";

        // Tạo chữ ký cho PayOS: amount, cancelUrl, description, orderCode, returnUrl sorted alphabetically
        String signatureData = "amount=" + amount.longValue() +
                "&cancelUrl=" + cancelUrl +
                "&description=" + description +
                "&orderCode=" + orderCode +
                "&returnUrl=" + returnUrl;

        String signature = hmacSHA256(checksumKey, signatureData);

        // Build request body
        Map<String, Object> requestBody = new HashMap<>();
        requestBody.put("orderCode", orderCode);
        requestBody.put("amount", amount.longValue());
        requestBody.put("description", description);
        requestBody.put("cancelUrl", cancelUrl);
        requestBody.put("returnUrl", returnUrl);
        requestBody.put("signature", signature);

        // Gọi PayOS API tạo link thanh toán
        Map<String, String> payOSResponse = createPayOSPaymentLink(requestBody);
        String checkoutUrl = payOSResponse.get("checkoutUrl");
        String qrCode = payOSResponse.get("qrCode");

        return PaymentResponseDTO.builder()
                .paymentUrl(checkoutUrl)
                .qrCode(qrCode)
                .txnRef(txnRef)
                .amount(amount)
                .courseTitle(course.getTitle())
                .build();
    }

    private Map<String, String> createPayOSPaymentLink(Map<String, Object> requestBody) {
        try {
            RestTemplate restTemplate = new RestTemplate();
            HttpHeaders headers = new HttpHeaders();
            headers.setContentType(MediaType.APPLICATION_JSON);
            headers.set("x-client-id", clientId);
            headers.set("x-api-key", apiKey);

            HttpEntity<Map<String, Object>> entity = new HttpEntity<>(requestBody, headers);
            String url = "https://api-merchant.payos.vn/v2/payment-requests";

            log.info("Sending request to PayOS: {}", requestBody);
            Map<String, Object> response = restTemplate.postForObject(url, entity, Map.class);
            log.info("Received response from PayOS: {}", response);

            if (response != null && "00".equals(response.get("code"))) {
                Map<String, Object> data = (Map<String, Object>) response.get("data");
                if (data != null) {
                    Map<String, String> res = new HashMap<>();
                    res.put("checkoutUrl", (String) data.get("checkoutUrl"));
                    res.put("qrCode", (String) data.get("qrCode"));
                    return res;
                }
            }
            throw new RuntimeException("PayOS API error: " + (response != null ? response.get("desc") : "No response"));
        } catch (Exception e) {
            log.error("Error creating payment link via PayOS", e);
            throw new RuntimeException("Failed to generate payment link: " + e.getMessage());
        }
    }

    @Override
    @Transactional
    public void handlePayOSWebhook(Map<String, Object> payload) {
        log.info("PayOS Webhook received: {}", payload);

        // 1. Kiểm tra chữ ký webhook
        String signature = (String) payload.get("signature");
        Map<String, Object> data = (Map<String, Object>) payload.get("data");

        if (data == null || signature == null) {
            log.warn("Invalid PayOS webhook payload: data or signature is null");
            return;
        }

        // Sắp xếp các trường của data và build hash data
        Map<String, Object> sortedData = new TreeMap<>(data);
        StringBuilder sb = new StringBuilder();
        for (Map.Entry<String, Object> entry : sortedData.entrySet()) {
            if (sb.length() > 0) {
                sb.append("&");
            }
            sb.append(entry.getKey()).append("=").append(formatValue(entry.getValue()));
        }

        String calculatedSignature = hmacSHA256(checksumKey, sb.toString());
        if (!calculatedSignature.equalsIgnoreCase(signature)) {
            log.warn("PayOS webhook verification failed! Expected: {}, calculated: {}", signature, calculatedSignature);
            throw new RuntimeException("Invalid webhook signature");
        }

        // 2. Cập nhật trạng thái Payment và Enroll khóa học
        String code = (String) payload.get("code");
        
        // Bỏ qua nếu là request test/xác nhận từ PayOS
        if ("confirm".equals(payload.get("desc")) || data.get("orderCode") == null) {
            log.info("PayOS webhook confirm / test request received. Signature validated successfully.");
            return;
        }

        long orderCode = Long.parseLong(formatValue(data.get("orderCode")));
        String txnRef = String.valueOf(orderCode);

        paymentRepository.findByTxnRef(txnRef).ifPresent(payment -> {
            if ("00".equals(code)) {
                payment.setStatus("SUCCESS");
                payment.setVnpayTxnNo((String) data.get("reference"));
                payment.setBankCode("VietQR");
                payment.setPaidAt(LocalDateTime.now());
                paymentRepository.save(payment);

                // Auto enroll
                boolean alreadyEnrolled = enrollmentRepository
                        .existsByUserIdAndCourseId(payment.getUser().getId(), payment.getCourse().getId());
                if (!alreadyEnrolled) {
                    Enrollment enrollment = Enrollment.builder()
                            .user(payment.getUser())
                            .course(payment.getCourse())
                            .status("ENROLLED")
                            .build();
                    enrollmentRepository.save(enrollment);
                    log.info("Auto-enrolled userId={} into courseId={} after PayOS payment",
                            payment.getUser().getId(), payment.getCourse().getId());
                }
            } else {
                payment.setStatus("FAILED");
                paymentRepository.save(payment);
                log.info("PayOS payment failed for txnRef={}", txnRef);
            }
        });
    }

    @Override
    public PaymentStatusDTO getPaymentStatus(String txnRef, Long userId) {
        Payment payment = paymentRepository.findByTxnRef(txnRef)
                .orElseThrow(() -> new RuntimeException("Payment not found"));

        // Bảo mật: chỉ cho xem payment của chính mình
        if (!payment.getUser().getId().equals(userId)) {
            throw new RuntimeException("Unauthorized");
        }

        return PaymentStatusDTO.builder()
                .txnRef(payment.getTxnRef())
                .status(payment.getStatus())
                .courseId(payment.getCourse().getId())
                .courseTitle(payment.getCourse().getTitle())
                .paidAt(payment.getPaidAt())
                .build();
    }

    private String formatValue(Object value) {
        if (value == null) {
            return "";
        }
        if (value instanceof Number) {
            double doubleVal = ((Number) value).doubleValue();
            if (doubleVal == Math.floor(doubleVal) && !Double.isInfinite(doubleVal)) {
                return String.valueOf(((Number) value).longValue());
            }
        }
        return value.toString();
    }

    private String hmacSHA256(String key, String data) {
        try {
            Mac mac = Mac.getInstance("HmacSHA256");
            SecretKeySpec secretKey = new SecretKeySpec(key.getBytes(StandardCharsets.UTF_8), "HmacSHA256");
            mac.init(secretKey);
            byte[] hash = mac.doFinal(data.getBytes(StandardCharsets.UTF_8));
            StringBuilder sb = new StringBuilder();
            for (byte b : hash) {
                sb.append(String.format("%02x", b));
            }
            return sb.toString();
        } catch (Exception e) {
            throw new RuntimeException("Error generating HMAC-SHA256", e);
        }
    }
}
