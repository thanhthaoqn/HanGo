package com.hango.hango_backend.service;

import com.hango.hango_backend.dto.PaymentHistoryDTO;
import com.hango.hango_backend.dto.PaymentStatusDTO;
import com.hango.hango_backend.entity.Course;
import com.hango.hango_backend.entity.Payment;
import com.hango.hango_backend.entity.TrainerProfile;
import com.hango.hango_backend.entity.User;
import com.hango.hango_backend.repository.CartItemRepository;
import com.hango.hango_backend.repository.CourseRepository;
import com.hango.hango_backend.repository.EnrollmentRepository;
import com.hango.hango_backend.repository.PaymentRepository;
import com.hango.hango_backend.repository.TrainerProfileRepository;
import com.hango.hango_backend.repository.UserRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageImpl;
import org.springframework.data.domain.PageRequest;
import org.springframework.test.util.ReflectionTestUtils;

import javax.crypto.Mac;
import javax.crypto.spec.SecretKeySpec;
import java.math.BigDecimal;
import java.nio.charset.StandardCharsets;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.TreeMap;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class PaymentServiceImplTest {

    private static final String CHECKSUM_KEY = "test-checksum-key";

    @Mock
    private PaymentRepository paymentRepository;
    @Mock
    private CourseRepository courseRepository;
    @Mock
    private UserRepository userRepository;
    @Mock
    private EnrollmentRepository enrollmentRepository;
    @Mock
    private TrainerProfileRepository trainerProfileRepository;
    @Mock
    private CartItemRepository cartItemRepository;
    @Mock
    private EmailService emailService;
    @Mock
    private NotificationService notificationService;

    @InjectMocks
    private PaymentServiceImpl paymentService;

    @BeforeEach
    void setChecksumKey() {
        ReflectionTestUtils.setField(paymentService, "checksumKey", CHECKSUM_KEY);
    }

    private User user(Long id, String fullName) {
        return User.builder().id(id).fullName(fullName).email(fullName.toLowerCase() + "@example.com").build();
    }

    private Course course(Long id, String title, BigDecimal price, User creator) {
        return Course.builder().id(id).title(title).price(price).creator(creator).build();
    }

    /** Mirrors PaymentServiceImpl's private formatValue/hmacSHA256 so tests can build a valid signature. */
    private String formatValue(Object value) {
        if (value == null) return "";
        if (value instanceof Number) {
            double d = ((Number) value).doubleValue();
            if (d == Math.floor(d) && !Double.isInfinite(d)) {
                return String.valueOf(((Number) value).longValue());
            }
        }
        return value.toString();
    }

    private String hmacSHA256(String key, String data) {
        try {
            Mac mac = Mac.getInstance("HmacSHA256");
            mac.init(new SecretKeySpec(key.getBytes(StandardCharsets.UTF_8), "HmacSHA256"));
            byte[] hash = mac.doFinal(data.getBytes(StandardCharsets.UTF_8));
            StringBuilder sb = new StringBuilder();
            for (byte b : hash) sb.append(String.format("%02x", b));
            return sb.toString();
        } catch (Exception e) {
            throw new RuntimeException(e);
        }
    }

    private String signOf(Map<String, Object> data) {
        Map<String, Object> sorted = new TreeMap<>(data);
        StringBuilder sb = new StringBuilder();
        for (Map.Entry<String, Object> e : sorted.entrySet()) {
            if (sb.length() > 0) sb.append("&");
            sb.append(e.getKey()).append("=").append(formatValue(e.getValue()));
        }
        return hmacSHA256(CHECKSUM_KEY, sb.toString());
    }

    private Map<String, Object> webhookPayload(String code, String desc, Map<String, Object> data) {
        Map<String, Object> payload = new HashMap<>();
        payload.put("code", code);
        payload.put("desc", desc);
        payload.put("data", data);
        payload.put("signature", signOf(data));
        return payload;
    }

    // =================================================================
    // createPayment
    // =================================================================

    @Test
    void createPaymentShouldThrowWhenUserNotFound() {
        when(userRepository.findById(999L)).thenReturn(Optional.empty());

        assertThrows(RuntimeException.class,
                () -> paymentService.createPayment(1L, 999L, "127.0.0.1", "http://localhost"));
        verify(paymentRepository, never()).save(any());
    }

    @Test
    void createPaymentShouldThrowWhenNoCourseInfoProvided() {
        when(userRepository.findById(10L)).thenReturn(Optional.of(user(10L, "Alice")));
        com.hango.hango_backend.dto.PaymentRequestDTO request = new com.hango.hango_backend.dto.PaymentRequestDTO();

        assertThrows(RuntimeException.class,
                () -> paymentService.createPayment(request, 10L, "127.0.0.1", "http://localhost"));
        verify(paymentRepository, never()).save(any());
    }

    @Test
    void createPaymentShouldThrowWhenCoursesNotFound() {
        when(userRepository.findById(10L)).thenReturn(Optional.of(user(10L, "Alice")));
        com.hango.hango_backend.dto.PaymentRequestDTO request = new com.hango.hango_backend.dto.PaymentRequestDTO();
        request.setCourseId(5L);
        when(courseRepository.findAllById(any())).thenReturn(List.of());

        assertThrows(RuntimeException.class,
                () -> paymentService.createPayment(request, 10L, "127.0.0.1", "http://localhost"));
        verify(paymentRepository, never()).save(any());
    }

    @Test
    void createPaymentShouldAutoEnrollAndSendFreeConfirmationEmailWhenTotalPriceIsZero() {
        User buyer = user(10L, "Alice");
        User creator = user(2L, "Trainer Bob");
        Course freeCourse = course(5L, "Free Course", BigDecimal.ZERO, creator);
        when(userRepository.findById(10L)).thenReturn(Optional.of(buyer));
        com.hango.hango_backend.dto.PaymentRequestDTO request = new com.hango.hango_backend.dto.PaymentRequestDTO();
        request.setCourseId(5L);
        when(courseRepository.findAllById(any())).thenReturn(List.of(freeCourse));
        when(enrollmentRepository.existsByUserIdAndCourseId(10L, 5L)).thenReturn(false);

        com.hango.hango_backend.dto.PaymentResponseDTO response =
                paymentService.createPayment(request, 10L, "127.0.0.1", "http://localhost");

        assertEquals("FREE_SUCCESS", response.getPaymentUrl());
        verify(enrollmentRepository).save(any());
        verify(cartItemRepository).deleteByUserIdAndCourseId(10L, 5L);
        verify(notificationService).notifyUser(eq(creator), eq(NotificationService.TYPE_NEW_ENROLLMENT), any(), any(), eq(freeCourse));
        verify(emailService).sendEnrollmentSuccessEmail(buyer.getEmail(), buyer.getFullName(), "Free Course", "Free", null);
    }

    @Test
    void createPaymentShouldStillReturnFreeSuccessWhenConfirmationEmailFails() {
        User buyer = user(10L, "Alice");
        Course freeCourse = course(5L, "Free Course", BigDecimal.ZERO, null);
        when(userRepository.findById(10L)).thenReturn(Optional.of(buyer));
        com.hango.hango_backend.dto.PaymentRequestDTO request = new com.hango.hango_backend.dto.PaymentRequestDTO();
        request.setCourseId(5L);
        when(courseRepository.findAllById(any())).thenReturn(List.of(freeCourse));
        when(enrollmentRepository.existsByUserIdAndCourseId(10L, 5L)).thenReturn(false);
        org.mockito.Mockito.doThrow(new RuntimeException("SMTP down"))
                .when(emailService).sendEnrollmentSuccessEmail(any(), any(), any(), any(), any());

        com.hango.hango_backend.dto.PaymentResponseDTO response =
                paymentService.createPayment(request, 10L, "127.0.0.1", "http://localhost");

        assertEquals("FREE_SUCCESS", response.getPaymentUrl());
        verify(enrollmentRepository).save(any());
    }

    // =================================================================
    // handlePayOSWebhook
    // =================================================================

    @Test
    void handlePayOSWebhookShouldRejectInvalidSignature() {
        Map<String, Object> data = new HashMap<>();
        data.put("orderCode", 100L);
        Map<String, Object> payload = new HashMap<>();
        payload.put("code", "00");
        payload.put("data", data);
        payload.put("signature", "not-the-real-signature");

        assertThrows(RuntimeException.class, () -> paymentService.handlePayOSWebhook(payload));
        verify(paymentRepository, never()).findByTxnRefWithLock(any());
    }

    @Test
    void handlePayOSWebhookShouldIgnoreConfirmTestRequestWithoutProcessing() {
        Map<String, Object> data = new HashMap<>();
        Map<String, Object> payload = webhookPayload("00", "confirm", data);

        paymentService.handlePayOSWebhook(payload);

        verify(paymentRepository, never()).findByTxnRefWithLock(any());
    }

    @Test
    void handlePayOSWebhookShouldMarkSuccessSplitRevenueEnrollAndNotifyForProfessionalTrainer() {
        User buyer = user(1L, "Alice");
        User creator = user(2L, "Trainer Bob");
        Course course = course(10L, "Course A", new BigDecimal("100000"), creator);
        Payment payment = Payment.builder().id(50L).user(buyer).course(course).courseIds("10")
                .amount(new BigDecimal("100000")).status("PENDING").txnRef("50").build();

        Map<String, Object> data = new HashMap<>();
        data.put("orderCode", 50L);
        data.put("reference", "REF-1");
        Map<String, Object> payload = webhookPayload("00", "success", data);

        when(paymentRepository.findByTxnRefWithLock("50")).thenReturn(Optional.of(payment));
        when(trainerProfileRepository.findById(2L)).thenReturn(Optional.of(
                TrainerProfile.builder().userId(2L).trainerType("PROFESSIONAL").build()));
        when(enrollmentRepository.existsByUserIdAndCourseId(1L, 10L)).thenReturn(false);
        when(courseRepository.findById(10L)).thenReturn(Optional.of(course));

        paymentService.handlePayOSWebhook(payload);

        assertEquals("SUCCESS", payment.getStatus());
        assertEquals(new BigDecimal("30000.00"), payment.getPlatformFee());
        assertEquals(new BigDecimal("70000.00"), payment.getTrainerEarnings());
        verify(enrollmentRepository).save(any());
        verify(cartItemRepository).deleteByUserIdAndCourseId(1L, 10L);
        verify(notificationService).notifyUser(eq(buyer), eq(NotificationService.TYPE_PURCHASE_SUCCESS), any(), any(), any());
        verify(notificationService).notifyUser(eq(creator), eq(NotificationService.TYPE_NEW_ENROLLMENT), any(), any(), eq(course));
    }

    @Test
    void handlePayOSWebhookShouldApply60_40SplitForPeerTutor() {
        User buyer = user(1L, "Alice");
        User creator = user(2L, "Peer Bob");
        Course course = course(10L, "Course A", new BigDecimal("100000"), creator);
        Payment payment = Payment.builder().id(51L).user(buyer).course(course).courseIds("10")
                .amount(new BigDecimal("100000")).status("PENDING").txnRef("51").build();

        Map<String, Object> data = new HashMap<>();
        data.put("orderCode", 51L);
        Map<String, Object> payload = webhookPayload("00", "success", data);

        when(paymentRepository.findByTxnRefWithLock("51")).thenReturn(Optional.of(payment));
        when(trainerProfileRepository.findById(2L)).thenReturn(Optional.of(
                TrainerProfile.builder().userId(2L).trainerType("PEER_TUTOR").build()));
        when(enrollmentRepository.existsByUserIdAndCourseId(1L, 10L)).thenReturn(false);
        when(courseRepository.findById(10L)).thenReturn(Optional.of(course));

        paymentService.handlePayOSWebhook(payload);

        assertEquals(new BigDecimal("40000.00"), payment.getPlatformFee());
        assertEquals(new BigDecimal("60000.00"), payment.getTrainerEarnings());
    }

    @Test
    void handlePayOSWebhookShouldBeIdempotentWhenPaymentAlreadySuccess() {
        Payment payment = Payment.builder().id(52L).status("SUCCESS").txnRef("52").amount(BigDecimal.TEN).build();
        Map<String, Object> data = new HashMap<>();
        data.put("orderCode", 52L);
        Map<String, Object> payload = webhookPayload("00", "success", data);
        when(paymentRepository.findByTxnRefWithLock("52")).thenReturn(Optional.of(payment));

        paymentService.handlePayOSWebhook(payload);

        verify(paymentRepository, never()).save(any());
        verify(enrollmentRepository, never()).save(any());
    }

    @Test
    void handlePayOSWebhookShouldMarkFailedWhenCodeIsNotSuccess() {
        Payment payment = Payment.builder().id(53L).status("PENDING").txnRef("53").amount(BigDecimal.TEN).build();
        Map<String, Object> data = new HashMap<>();
        data.put("orderCode", 53L);
        Map<String, Object> payload = webhookPayload("01", "failed", data);
        when(paymentRepository.findByTxnRefWithLock("53")).thenReturn(Optional.of(payment));

        paymentService.handlePayOSWebhook(payload);

        assertEquals("FAILED", payment.getStatus());
        verify(enrollmentRepository, never()).save(any());
    }

    @Test
    void handlePayOSWebhookShouldSkipEnrollmentButStillClearCartWhenAlreadyEnrolled() {
        User buyer = user(1L, "Alice");
        User creator = user(2L, "Trainer Bob");
        Course course = course(10L, "Course A", new BigDecimal("100000"), creator);
        Payment payment = Payment.builder().id(54L).user(buyer).course(course).courseIds("10")
                .amount(new BigDecimal("100000")).status("PENDING").txnRef("54").build();
        Map<String, Object> data = new HashMap<>();
        data.put("orderCode", 54L);
        Map<String, Object> payload = webhookPayload("00", "success", data);

        when(paymentRepository.findByTxnRefWithLock("54")).thenReturn(Optional.of(payment));
        when(trainerProfileRepository.findById(2L)).thenReturn(Optional.of(
                TrainerProfile.builder().userId(2L).trainerType("PROFESSIONAL").build()));
        when(enrollmentRepository.existsByUserIdAndCourseId(1L, 10L)).thenReturn(true);

        paymentService.handlePayOSWebhook(payload);

        verify(enrollmentRepository, never()).save(any());
        verify(cartItemRepository).deleteByUserIdAndCourseId(1L, 10L);
        verify(notificationService, never()).notifyUser(any(), eq(NotificationService.TYPE_NEW_ENROLLMENT), any(), any(), any());
    }

    @Test
    void handlePayOSWebhookShouldReturnSilentlyWhenDataIsMissing() {
        Map<String, Object> payload = new HashMap<>();
        payload.put("code", "00");
        payload.put("signature", "some-signature");

        paymentService.handlePayOSWebhook(payload);

        verify(paymentRepository, never()).findByTxnRefWithLock(any());
    }

    @Test
    void handlePayOSWebhookShouldFallBackToPaymentCourseWhenCourseIdsStringIsBlank() {
        User buyer = user(1L, "Alice");
        User creator = user(2L, "Trainer Bob");
        Course course = course(10L, "Course A", new BigDecimal("100000"), creator);
        Payment payment = Payment.builder().id(56L).user(buyer).course(course).courseIds("")
                .amount(new BigDecimal("100000")).status("PENDING").txnRef("56").build();
        Map<String, Object> data = new HashMap<>();
        data.put("orderCode", 56L);
        Map<String, Object> payload = webhookPayload("00", "success", data);

        when(paymentRepository.findByTxnRefWithLock("56")).thenReturn(Optional.of(payment));
        when(trainerProfileRepository.findById(2L)).thenReturn(Optional.of(
                TrainerProfile.builder().userId(2L).trainerType("PROFESSIONAL").build()));
        when(enrollmentRepository.existsByUserIdAndCourseId(1L, 10L)).thenReturn(false);
        when(courseRepository.findById(10L)).thenReturn(Optional.of(course));

        paymentService.handlePayOSWebhook(payload);

        verify(courseRepository).findById(10L);
        verify(enrollmentRepository).save(any());
    }

    // =================================================================
    // getPaymentStatus
    // =================================================================

    @Test
    void getPaymentStatusShouldReturnStatusWhenOwnedByCaller() {
        User buyer = user(1L, "Alice");
        Course course = course(10L, "Course A", BigDecimal.TEN, null);
        Payment payment = Payment.builder().txnRef("55").status("SUCCESS").user(buyer).course(course).build();
        when(paymentRepository.findByTxnRef("55")).thenReturn(Optional.of(payment));

        PaymentStatusDTO result = paymentService.getPaymentStatus("55", 1L);

        assertEquals("SUCCESS", result.getStatus());
        assertEquals(10L, result.getCourseId());
    }

    @Test
    void getPaymentStatusShouldThrowWhenNotOwnedByCaller() {
        User buyer = user(1L, "Alice");
        Payment payment = Payment.builder().txnRef("55").status("SUCCESS").user(buyer).build();
        when(paymentRepository.findByTxnRef("55")).thenReturn(Optional.of(payment));

        assertThrows(RuntimeException.class, () -> paymentService.getPaymentStatus("55", 999L));
    }

    @Test
    void getPaymentStatusShouldThrowWhenPaymentNotFound() {
        when(paymentRepository.findByTxnRef("missing")).thenReturn(Optional.empty());

        assertThrows(RuntimeException.class, () -> paymentService.getPaymentStatus("missing", 1L));
    }

    @Test
    void getPaymentStatusShouldDefaultCourseTitleWhenPaymentHasNoCourse() {
        User buyer = user(1L, "Alice");
        Payment payment = Payment.builder().txnRef("57").status("PENDING").user(buyer).course(null).build();
        when(paymentRepository.findByTxnRef("57")).thenReturn(Optional.of(payment));

        PaymentStatusDTO result = paymentService.getPaymentStatus("57", 1L);

        assertEquals("Course", result.getCourseTitle());
        assertEquals(null, result.getCourseId());
    }

    // =================================================================
    // getMyPaymentHistory
    // =================================================================

    @Test
    void getMyPaymentHistoryShouldLabelMultiCourseCheckoutDistinctly() {
        Payment payment = Payment.builder().id(1L).txnRef("60").status("SUCCESS")
                .courseIds("10,11").amount(new BigDecimal("150000")).build();
        when(paymentRepository.findByUserIdOrderByCreatedAtDesc(1L)).thenReturn(List.of(payment));

        List<PaymentHistoryDTO> result = paymentService.getMyPaymentHistory(1L);

        assertEquals("Payment for 2 courses in cart", result.get(0).getCourseTitle());
    }

    @Test
    void getMyPaymentHistoryShouldUseCourseTitleForSingleCourseCheckout() {
        Course course = course(10L, "Course A", new BigDecimal("100000"), null);
        Payment payment = Payment.builder().id(2L).txnRef("61").status("SUCCESS")
                .courseIds("10").course(course).amount(new BigDecimal("100000")).build();
        when(paymentRepository.findByUserIdOrderByCreatedAtDesc(1L)).thenReturn(List.of(payment));

        List<PaymentHistoryDTO> result = paymentService.getMyPaymentHistory(1L);

        assertEquals("Course A", result.get(0).getCourseTitle());
    }

    @Test
    void getMyPaymentHistoryShouldFallBackToDefaultTitleWhenNoCourseOrCourseIds() {
        Payment payment = Payment.builder().id(3L).txnRef("62").status("SUCCESS")
                .amount(new BigDecimal("50000")).build();
        when(paymentRepository.findByUserIdOrderByCreatedAtDesc(1L)).thenReturn(List.of(payment));

        List<PaymentHistoryDTO> result = paymentService.getMyPaymentHistory(1L);

        assertEquals("HanGo Course", result.get(0).getCourseTitle());
    }

    @Test
    void getMyPaymentHistoryPaginatedShouldUseStatusFilterWhenNotAll() {
        Page<Payment> page = new PageImpl<>(List.of(), PageRequest.of(0, 10), 0);
        when(paymentRepository.findByUserIdAndStatusOrderByCreatedAtDesc(eq(1L), eq("SUCCESS"), any())).thenReturn(page);

        paymentService.getMyPaymentHistory(1L, "success", 0, 10);

        verify(paymentRepository).findByUserIdAndStatusOrderByCreatedAtDesc(eq(1L), eq("SUCCESS"), any());
        verify(paymentRepository, never()).findByUserIdOrderByCreatedAtDesc(eq(1L), any());
    }

    @Test
    void getMyPaymentHistoryPaginatedShouldIgnoreAllStatusFilter() {
        Page<Payment> page = new PageImpl<>(List.of(), PageRequest.of(0, 10), 0);
        when(paymentRepository.findByUserIdOrderByCreatedAtDesc(eq(1L), any())).thenReturn(page);

        paymentService.getMyPaymentHistory(1L, "ALL", 0, 10);

        verify(paymentRepository).findByUserIdOrderByCreatedAtDesc(eq(1L), any());
    }

    // =================================================================
    // getAllPaymentsForManager
    // =================================================================

    @Test
    void getAllPaymentsForManagerShouldSyncSettlementStatusesAndMapResultsToDTO() {
        User buyer = user(1L, "Alice");
        User creator = user(2L, "Trainer Bob");
        Course course = course(10L, "Course A", new BigDecimal("100000"), creator);
        Payment payment = Payment.builder().id(70L).user(buyer).course(course).txnRef("70")
                .amount(new BigDecimal("100000")).status("SUCCESS").settlementStatus("PENDING").build();
        Page<Payment> page = new PageImpl<>(List.of(payment), PageRequest.of(0, 10), 1);
        when(paymentRepository.findAllForManager(eq(""), eq(""), eq(""), any())).thenReturn(page);

        Page<com.hango.hango_backend.dto.ManagerPaymentDTO> result =
                paymentService.getAllPaymentsForManager(null, null, null, 0, 10);

        verify(paymentRepository).syncSettledPaymentsForPaidStatements();
        assertEquals(1, result.getTotalElements());
        assertEquals("Alice", result.getContent().get(0).getLearnerName());
        assertEquals("Trainer Bob", result.getContent().get(0).getTrainerName());
    }

    @Test
    void getAllPaymentsForManagerShouldNormalizeAllFilterAndLowercaseSearch() {
        Page<Payment> page = new PageImpl<>(List.of(), PageRequest.of(0, 10), 0);
        when(paymentRepository.findAllForManager(eq(""), eq(""), eq("%bob%"), any())).thenReturn(page);

        paymentService.getAllPaymentsForManager("ALL", "ALL", "Bob", 0, 10);

        verify(paymentRepository).findAllForManager(eq(""), eq(""), eq("%bob%"), any());
    }

    @Test
    void getAllPaymentsForManagerShouldFallBackToDefaultTitleAndTrainerWhenCourseMissing() {
        User buyer = user(1L, "Alice");
        Payment payment = Payment.builder().id(71L).user(buyer).course(null).txnRef("71")
                .amount(new BigDecimal("50000")).status("SUCCESS").build();
        Page<Payment> page = new PageImpl<>(List.of(payment), PageRequest.of(0, 10), 1);
        when(paymentRepository.findAllForManager(eq(""), eq(""), eq(""), any())).thenReturn(page);

        Page<com.hango.hango_backend.dto.ManagerPaymentDTO> result =
                paymentService.getAllPaymentsForManager(null, null, null, 0, 10);

        assertEquals("HanGo Course", result.getContent().get(0).getCourseTitle());
        assertEquals("N/A", result.getContent().get(0).getTrainerName());
    }

    // =================================================================
    // exportPaymentsToExcel
    // =================================================================

    @Test
    void exportPaymentsToExcelShouldSyncSettlementStatusesAndReturnNonEmptyWorkbook() {
        User buyer = user(1L, "Alice");
        User creator = user(2L, "Trainer Bob");
        Course course = course(10L, "Course A", new BigDecimal("100000"), creator);
        Payment payment = Payment.builder().id(72L).user(buyer).course(course).txnRef("72")
                .amount(new BigDecimal("100000")).status("SUCCESS").settlementStatus("PENDING").build();
        when(paymentRepository.findAllForManagerList(eq(""), eq(""), eq(""))).thenReturn(List.of(payment));

        byte[] result = paymentService.exportPaymentsToExcel(null, null, null);

        verify(paymentRepository).syncSettledPaymentsForPaidStatements();
        assertEquals(true, result.length > 0);
    }

    @Test
    void exportPaymentsToExcelShouldReturnValidWorkbookWhenNoPaymentsMatch() {
        when(paymentRepository.findAllForManagerList(eq("SUCCESS"), eq(""), eq(""))).thenReturn(List.of());

        byte[] result = paymentService.exportPaymentsToExcel("SUCCESS", null, null);

        assertEquals(true, result.length > 0);
    }
}
