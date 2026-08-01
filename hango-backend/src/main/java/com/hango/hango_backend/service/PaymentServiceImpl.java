package com.hango.hango_backend.service;

import com.hango.hango_backend.dto.PaymentHistoryDTO;
import com.hango.hango_backend.dto.PaymentResponseDTO;
import com.hango.hango_backend.dto.PaymentStatusDTO;
import com.hango.hango_backend.entity.Course;
import com.hango.hango_backend.entity.Enrollment;
import com.hango.hango_backend.entity.Payment;
import com.hango.hango_backend.entity.User;
import com.hango.hango_backend.entity.TrainerProfile;
import com.hango.hango_backend.repository.CartItemRepository;
import com.hango.hango_backend.repository.CourseRepository;
import com.hango.hango_backend.repository.EnrollmentRepository;
import com.hango.hango_backend.repository.PaymentRepository;
import com.hango.hango_backend.repository.TrainerProfileRepository;
import com.hango.hango_backend.repository.UserRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Pageable;
import org.springframework.http.HttpEntity;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.client.RestTemplate;

import javax.crypto.Mac;
import javax.crypto.spec.SecretKeySpec;
import java.math.BigDecimal;
import java.math.RoundingMode;
import java.nio.charset.StandardCharsets;
import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.TreeMap;
import java.util.stream.Collectors;

@Slf4j
@Service
@RequiredArgsConstructor
public class PaymentServiceImpl implements PaymentService {

    private final PaymentRepository paymentRepository;
    private final CourseRepository courseRepository;
    private final UserRepository userRepository;
    private final EnrollmentRepository enrollmentRepository;
    private final TrainerProfileRepository trainerProfileRepository;
    private final CartItemRepository cartItemRepository;
    private final EmailService emailService;
    private final NotificationService notificationService;

    @Value("${payos.client-id}")
    private String clientId;

    @Value("${payos.api-key}")
    private String apiKey;

    @Value("${payos.checksum-key}")
    private String checksumKey;

    @Override
    @Transactional
    public PaymentResponseDTO createPayment(Long courseId, Long userId, String ipAddress, String origin) {
        com.hango.hango_backend.dto.PaymentRequestDTO dto = new com.hango.hango_backend.dto.PaymentRequestDTO();
        dto.setCourseId(courseId);
        return createPayment(dto, userId, ipAddress, origin);
    }

    @Override
    @Transactional
    public PaymentResponseDTO createPayment(com.hango.hango_backend.dto.PaymentRequestDTO request, Long userId, String ipAddress, String origin) {
        User user = userRepository.findById(userId)
                .orElseThrow(() -> new RuntimeException("User not found"));

        List<Long> targetCourseIds = new ArrayList<>();
        if (request.getCourseIds() != null && !request.getCourseIds().isEmpty()) {
            targetCourseIds.addAll(request.getCourseIds());
        } else if (request.getCourseId() != null) {
            targetCourseIds.add(request.getCourseId());
        } else {
            throw new RuntimeException("Không tìm thấy thông tin khóa học thanh toán.");
        }

        List<Course> courses = courseRepository.findAllById(targetCourseIds);
        if (courses.isEmpty()) {
            throw new RuntimeException("Course not found");
        }

        Course primaryCourse = courses.get(0);
        BigDecimal totalAmount = BigDecimal.ZERO;
        List<String> validIds = new ArrayList<>();

        for (Course c : courses) {
            validIds.add(c.getId().toString());
            BigDecimal p = (c.getPrice() != null && c.getPrice().compareTo(BigDecimal.ZERO) > 0)
                    ? c.getPrice()
                    : new BigDecimal("50000");
            totalAmount = totalAmount.add(p);
        }

        if (totalAmount.compareTo(BigDecimal.ZERO) <= 0) {
            totalAmount = new BigDecimal("50000");
        }

        String courseIdsStr = String.join(",", validIds);

        // 1. Tạo payment PENDING để lấy ID làm orderCode duy nhất
        Payment payment = Payment.builder()
                .user(user)
                .course(primaryCourse)
                .courseIds(courseIdsStr)
                .amount(totalAmount)
                .status("PENDING")
                .txnRef("")
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
        String signatureData = "amount=" + totalAmount.longValue() +
                "&cancelUrl=" + cancelUrl +
                "&description=" + description +
                "&orderCode=" + orderCode +
                "&returnUrl=" + returnUrl;

        String signature = hmacSHA256(checksumKey, signatureData);

        // Build request body
        Map<String, Object> requestBody = new HashMap<>();
        requestBody.put("orderCode", orderCode);
        requestBody.put("amount", totalAmount.longValue());
        requestBody.put("description", description);
        requestBody.put("cancelUrl", cancelUrl);
        requestBody.put("returnUrl", returnUrl);
        requestBody.put("signature", signature);

        // Gọi PayOS API tạo link thanh toán
        Map<String, String> payOSResponse = createPayOSPaymentLink(requestBody);
        String checkoutUrl = payOSResponse.get("checkoutUrl");
        String qrCode = payOSResponse.get("qrCode");

        String displayTitle = courses.size() > 1
                ? ("Thanh toán " + courses.size() + " khóa học trong giỏ hàng")
                : primaryCourse.getTitle();

        return PaymentResponseDTO.builder()
                .paymentUrl(checkoutUrl)
                .qrCode(qrCode)
                .txnRef(txnRef)
                .amount(totalAmount)
                .courseTitle(displayTitle)
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

        // Pessimistic Locking to avoid race conditions during concurrent webhooks
        paymentRepository.findByTxnRefWithLock(txnRef).ifPresent(payment -> {
            // Idempotency Check: Nếu đã SUCCESS rồi thì bỏ qua
            if ("SUCCESS".equalsIgnoreCase(payment.getStatus())) {
                log.info("Payment txnRef={} is already SUCCESS. Skipping duplicate webhook processing.", txnRef);
                return;
            }

            if ("00".equals(code)) {
                payment.setStatus("SUCCESS");
                payment.setVnpayTxnNo((String) data.get("reference"));
                payment.setBankCode("VietQR");
                payment.setPaidAt(LocalDateTime.now());

                // Calculate Revenue Split (70/30 for PROFESSIONAL, 60/40 for PEER_TUTOR)
                BigDecimal amount = payment.getAmount();
                if (amount != null && amount.compareTo(BigDecimal.ZERO) > 0) {
                    double platformRate = 0.30;
                    if (payment.getCourse() != null && payment.getCourse().getCreator() != null) {
                        Long creatorId = payment.getCourse().getCreator().getId();
                        TrainerProfile profile = trainerProfileRepository.findById(creatorId).orElse(null);
                        if (profile != null && "PEER_TUTOR".equalsIgnoreCase(profile.getTrainerType())) {
                            platformRate = 0.40;
                        }
                    }
                    BigDecimal platformFee = amount.multiply(BigDecimal.valueOf(platformRate)).setScale(2, RoundingMode.HALF_UP);
                    BigDecimal trainerEarnings = amount.subtract(platformFee);

                    payment.setPlatformFee(platformFee);
                    payment.setTrainerEarnings(trainerEarnings);
                    payment.setSettlementStatus("PENDING");
                }

                paymentRepository.save(payment);

                notificationService.notifyUser(payment.getUser(), NotificationService.TYPE_PURCHASE_SUCCESS,
                        "Payment successful",
                        "Your payment of " + amount + " VND was successful. Enjoy your course(s)!",
                        payment.getCourse());

                // Auto enroll into all courses in payment
                List<Long> targetIds = new ArrayList<>();
                if (payment.getCourseIds() != null && !payment.getCourseIds().trim().isEmpty()) {
                    for (String idStr : payment.getCourseIds().split(",")) {
                        try {
                            targetIds.add(Long.parseLong(idStr.trim()));
                        } catch (Exception ignored) {}
                    }
                }
                if (targetIds.isEmpty() && payment.getCourse() != null) {
                    targetIds.add(payment.getCourse().getId());
                }

                for (Long cId : targetIds) {
                    boolean alreadyEnrolled = enrollmentRepository.existsByUserIdAndCourseId(payment.getUser().getId(), cId);
                    if (!alreadyEnrolled) {
                        Course c = courseRepository.findById(cId).orElse(null);
                        if (c != null) {
                            Enrollment enrollment = Enrollment.builder()
                                    .user(payment.getUser())
                                    .course(c)
                                    .status("ENROLLED")
                                    .build();
                            enrollmentRepository.save(enrollment);
                            log.info("Auto-enrolled userId={} into courseId={} after PayOS payment",
                                    payment.getUser().getId(), cId);

                            notificationService.notifyUser(c.getCreator(), NotificationService.TYPE_NEW_ENROLLMENT,
                                    "New enrollment",
                                    payment.getUser().getFullName() + " enrolled in your course \"" + c.getTitle() + "\".",
                                    c);

                            // Clear paid items from DB cart
                            cartItemRepository.deleteByUserIdAndCourseId(payment.getUser().getId(), cId);

                            // Send email confirmation
                            try {
                                String priceText = (c.getPrice() != null && c.getPrice().compareTo(BigDecimal.ZERO) > 0)
                                        ? String.format("%,.0fđ", c.getPrice())
                                        : "Miễn phí";
                                emailService.sendEnrollmentSuccessEmail(
                                        payment.getUser().getEmail(),
                                        payment.getUser().getFullName(),
                                        c.getTitle(),
                                        priceText);
                            } catch (Exception e) {
                                log.warn("Failed to send enrollment email to {}: {}", payment.getUser().getEmail(), e.getMessage());
                            }
                        }
                    } else {
                        // Still ensure cart item is removed if user was somehow already enrolled
                        cartItemRepository.deleteByUserIdAndCourseId(payment.getUser().getId(), cId);
                    }
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
                .courseId(payment.getCourse() != null ? payment.getCourse().getId() : null)
                .courseTitle(payment.getCourse() != null ? payment.getCourse().getTitle() : "Khóa học")
                .paidAt(payment.getPaidAt())
                .build();
    }

    @Override
    public List<PaymentHistoryDTO> getMyPaymentHistory(Long userId) {
        List<Payment> payments = paymentRepository.findByUserIdOrderByCreatedAtDesc(userId);
        return mapPaymentsToDTO(payments);
    }

    @Override
    public Page<PaymentHistoryDTO> getMyPaymentHistory(Long userId, String status, int page, int size) {
        Pageable pageable = PageRequest.of(page, size);
        Page<Payment> paymentPage;
        if (status == null || status.trim().isEmpty() || "ALL".equalsIgnoreCase(status)) {
            paymentPage = paymentRepository.findByUserIdOrderByCreatedAtDesc(userId, pageable);
        } else {
            paymentPage = paymentRepository.findByUserIdAndStatusOrderByCreatedAtDesc(userId, status.toUpperCase(), pageable);
        }
        return paymentPage.map(this::mapPaymentToDTO);
    }

    private List<PaymentHistoryDTO> mapPaymentsToDTO(List<Payment> payments) {
        return payments.stream().map(this::mapPaymentToDTO).collect(Collectors.toList());
    }

    private PaymentHistoryDTO mapPaymentToDTO(Payment payment) {
        String title = null;
        if (payment.getCourseIds() != null && !payment.getCourseIds().trim().isEmpty()) {
            String[] ids = payment.getCourseIds().split(",");
            if (ids.length > 1) {
                title = "Thanh toán " + ids.length + " khóa học trong giỏ hàng";
            }
        }
        if (title == null && payment.getCourse() != null) {
            title = payment.getCourse().getTitle();
        }
        if (title == null) {
            title = "Khóa học HanGo";
        }

        return PaymentHistoryDTO.builder()
                .id(payment.getId())
                .txnRef(payment.getTxnRef())
                .courseId(payment.getCourse() != null ? payment.getCourse().getId() : null)
                .courseTitle(title)
                .courseThumbnail(payment.getCourse() != null ? payment.getCourse().getThumbnailUrl() : null)
                .amount(payment.getAmount())
                .status(payment.getStatus())
                .bankCode(payment.getBankCode())
                .vnpayTxnNo(payment.getVnpayTxnNo())
                .paidAt(payment.getPaidAt())
                .createdAt(payment.getCreatedAt())
                .build();
    }

    @Override
    @Transactional(readOnly = true)
    public Page<com.hango.hango_backend.dto.ManagerPaymentDTO> getAllPaymentsForManager(
            String status, String settlementStatus, String search, int page, int size) {
        Pageable pageable = PageRequest.of(page, size);
        Page<Payment> paymentPage = paymentRepository.findAllForManager(status, settlementStatus, search, pageable);
        return paymentPage.map(this::mapToManagerDTO);
    }

    @Override
    @Transactional(readOnly = true)
    public byte[] exportPaymentsToExcel(String status, String settlementStatus, String search) {
        List<Payment> payments = paymentRepository.findAllForManagerList(status, settlementStatus, search);
        List<com.hango.hango_backend.dto.ManagerPaymentDTO> dtos = payments.stream()
                .map(this::mapToManagerDTO)
                .collect(Collectors.toList());

        try (org.apache.poi.ss.usermodel.Workbook workbook = new org.apache.poi.xssf.usermodel.XSSFWorkbook();
             java.io.ByteArrayOutputStream out = new java.io.ByteArrayOutputStream()) {

            org.apache.poi.ss.usermodel.Sheet sheet = workbook.createSheet("Payment Transactions");

            org.apache.poi.ss.usermodel.CellStyle headerStyle = workbook.createCellStyle();
            org.apache.poi.ss.usermodel.Font headerFont = workbook.createFont();
            headerFont.setBold(true);
            headerFont.setColor(org.apache.poi.ss.usermodel.IndexedColors.WHITE.getIndex());
            headerStyle.setFont(headerFont);
            headerStyle.setFillForegroundColor(org.apache.poi.ss.usermodel.IndexedColors.TEAL.getIndex());
            headerStyle.setFillPattern(org.apache.poi.ss.usermodel.FillPatternType.SOLID_FOREGROUND);
            headerStyle.setAlignment(org.apache.poi.ss.usermodel.HorizontalAlignment.CENTER);

            String[] columns = {
                    "STT", "Txn Ref", "Learner Name", "Learner Email", "Course Title",
                    "Trainer Name", "Gross Amount (VND)", "Platform Fee (VND)",
                    "Trainer Earnings (VND)", "Payment Status", "Settlement Status",
                    "Statement ID", "Bank Code", "Paid At", "Created At"
            };

            org.apache.poi.ss.usermodel.Row headerRow = sheet.createRow(0);
            for (int i = 0; i < columns.length; i++) {
                org.apache.poi.ss.usermodel.Cell cell = headerRow.createCell(i);
                cell.setCellValue(columns[i]);
                cell.setCellStyle(headerStyle);
            }

            int rowIdx = 1;
            for (com.hango.hango_backend.dto.ManagerPaymentDTO dto : dtos) {
                org.apache.poi.ss.usermodel.Row row = sheet.createRow(rowIdx++);
                row.createCell(0).setCellValue(rowIdx - 1);
                row.createCell(1).setCellValue(dto.getTxnRef() != null ? dto.getTxnRef() : "");
                row.createCell(2).setCellValue(dto.getLearnerName() != null ? dto.getLearnerName() : "");
                row.createCell(3).setCellValue(dto.getLearnerEmail() != null ? dto.getLearnerEmail() : "");
                row.createCell(4).setCellValue(dto.getCourseTitle() != null ? dto.getCourseTitle() : "");
                row.createCell(5).setCellValue(dto.getTrainerName() != null ? dto.getTrainerName() : "");
                row.createCell(6).setCellValue(dto.getAmount() != null ? dto.getAmount().doubleValue() : 0);
                row.createCell(7).setCellValue(dto.getPlatformFee() != null ? dto.getPlatformFee().doubleValue() : 0);
                row.createCell(8).setCellValue(dto.getTrainerEarnings() != null ? dto.getTrainerEarnings().doubleValue() : 0);
                row.createCell(9).setCellValue(dto.getStatus() != null ? dto.getStatus() : "");
                row.createCell(10).setCellValue(dto.getSettlementStatus() != null ? dto.getSettlementStatus() : "");
                row.createCell(11).setCellValue(dto.getStatementId() != null ? dto.getStatementId().toString() : "");
                row.createCell(12).setCellValue(dto.getBankCode() != null ? dto.getBankCode() : "");
                row.createCell(13).setCellValue(dto.getPaidAt() != null ? dto.getPaidAt().toString() : "");
                row.createCell(14).setCellValue(dto.getCreatedAt() != null ? dto.getCreatedAt().toString() : "");
            }

            for (int i = 0; i < columns.length; i++) {
                sheet.autoSizeColumn(i);
            }

            workbook.write(out);
            return out.toByteArray();
        } catch (Exception e) {
            log.error("Error exporting payment transactions to excel", e);
            throw new RuntimeException("Failed to export payment transactions to Excel: " + e.getMessage());
        }
    }

    private com.hango.hango_backend.dto.ManagerPaymentDTO mapToManagerDTO(Payment p) {
        String title = null;
        if (p.getCourseIds() != null && !p.getCourseIds().trim().isEmpty()) {
            String[] ids = p.getCourseIds().split(",");
            if (ids.length > 1) {
                title = "Cart Payment (" + ids.length + " courses)";
            }
        }
        if (title == null && p.getCourse() != null) {
            title = p.getCourse().getTitle();
        }
        if (title == null) {
            title = "HanGo Course";
        }

        String trainerName = "N/A";
        Long trainerId = null;
        if (p.getCourse() != null && p.getCourse().getCreator() != null) {
            trainerName = p.getCourse().getCreator().getFullName();
            trainerId = p.getCourse().getCreator().getId();
        }

        return com.hango.hango_backend.dto.ManagerPaymentDTO.builder()
                .id(p.getId())
                .txnRef(p.getTxnRef())
                .learnerId(p.getUser() != null ? p.getUser().getId() : null)
                .learnerName(p.getUser() != null ? p.getUser().getFullName() : "N/A")
                .learnerEmail(p.getUser() != null ? p.getUser().getEmail() : "N/A")
                .courseId(p.getCourse() != null ? p.getCourse().getId() : null)
                .courseTitle(title)
                .trainerId(trainerId)
                .trainerName(trainerName)
                .amount(p.getAmount())
                .platformFee(p.getPlatformFee())
                .trainerEarnings(p.getTrainerEarnings())
                .status(p.getStatus())
                .settlementStatus(p.getSettlementStatus() != null ? p.getSettlementStatus() : "PENDING")
                .statementId(p.getStatementId())
                .bankCode(p.getBankCode())
                .vnpayTxnNo(p.getVnpayTxnNo())
                .paidAt(p.getPaidAt())
                .createdAt(p.getCreatedAt())
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
