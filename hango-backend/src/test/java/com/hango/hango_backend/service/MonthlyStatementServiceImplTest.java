package com.hango.hango_backend.service;

import com.hango.hango_backend.dto.MonthlyStatementDTO;
import com.hango.hango_backend.dto.TrainerRevenueSummaryDTO;
import com.hango.hango_backend.entity.Course;
import com.hango.hango_backend.entity.MonthlyStatement;
import com.hango.hango_backend.entity.Payment;
import com.hango.hango_backend.entity.TrainerProfile;
import com.hango.hango_backend.entity.User;
import com.hango.hango_backend.repository.CourseRepository;
import com.hango.hango_backend.repository.MonthlyStatementRepository;
import com.hango.hango_backend.repository.PaymentRepository;
import com.hango.hango_backend.repository.SystemParameterRepository;
import com.hango.hango_backend.repository.TrainerProfileRepository;
import com.hango.hango_backend.repository.UserRepository;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.time.format.DateTimeFormatter;
import java.util.List;
import java.util.Optional;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.times;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class MonthlyStatementServiceImplTest {

    @Mock
    private MonthlyStatementRepository statementRepository;
    @Mock
    private PaymentRepository paymentRepository;
    @Mock
    private TrainerProfileRepository trainerProfileRepository;
    @Mock
    private UserRepository userRepository;
    @Mock
    private CourseRepository courseRepository;
    @Mock
    private SystemParameterRepository systemParameterRepository;
    @Mock
    private EmailService emailService;
    @Mock
    private NotificationService notificationService;

    @InjectMocks
    private MonthlyStatementServiceImpl statementService;

    private User trainer(Long id, String email) {
        return User.builder().id(id).email(email).fullName("Trainer " + id).build();
    }

    private Payment payment(User creator, BigDecimal amount, String settlementStatus, LocalDateTime createdAt) {
        Course course = Course.builder().id(1L).title("Course A").creator(creator).build();
        return Payment.builder().amount(amount).status("SUCCESS").settlementStatus(settlementStatus)
                .course(course).createdAt(createdAt).build();
    }

    // =================================================================
    // getTrainerRevenueSummary
    // =================================================================

    @Test
    void getTrainerRevenueSummaryShouldThrowWhenTrainerNotFound() {
        when(userRepository.findById(1L)).thenReturn(Optional.empty());

        assertThrows(RuntimeException.class, () -> statementService.getTrainerRevenueSummary(1L));
    }

    @Test
    void getTrainerRevenueSummaryShouldSplitPendingHoldFromAvailableBySevenDayThreshold() {
        User trainer = trainer(1L, "trainer@example.com");
        when(userRepository.findById(1L)).thenReturn(Optional.of(trainer));
        when(trainerProfileRepository.findById(1L)).thenReturn(Optional.of(
                TrainerProfile.builder().userId(1L).trainerType("PROFESSIONAL").build()));

        Object[] recentRow = new Object[]{new BigDecimal("70000"), new BigDecimal("100000"), "PENDING", java.sql.Timestamp.valueOf(LocalDateTime.now().minusDays(2))};
        Object[] oldRow = new Object[]{new BigDecimal("140000"), new BigDecimal("200000"), "PENDING", java.sql.Timestamp.valueOf(LocalDateTime.now().minusDays(10))};
        when(paymentRepository.findRevenueDataByTrainerId(1L)).thenReturn(List.of(recentRow, oldRow));
        when(statementRepository.findByTrainerIdOrderByPeriodMonthDesc(1L)).thenReturn(List.of());

        TrainerRevenueSummaryDTO result = statementService.getTrainerRevenueSummary(1L);

        assertEquals(new BigDecimal("70000"), result.getPendingHoldBalance());
        assertEquals(new BigDecimal("140000"), result.getAvailableBalance());
    }

    @Test
    void getTrainerRevenueSummaryShouldFallBackToRateBasedCalculationWhenEarningsNotCached() {
        User trainer = trainer(1L, "trainer@example.com");
        when(userRepository.findById(1L)).thenReturn(Optional.of(trainer));
        when(trainerProfileRepository.findById(1L)).thenReturn(Optional.of(
                TrainerProfile.builder().userId(1L).trainerType("PEER_TUTOR").build()));
        Object[] noEarningsRow = new Object[]{null, new BigDecimal("100000"), "PENDING", java.sql.Timestamp.valueOf(LocalDateTime.now().minusDays(10))};
        when(paymentRepository.findRevenueDataByTrainerId(1L)).thenReturn(List.<Object[]>of(noEarningsRow));
        when(statementRepository.findByTrainerIdOrderByPeriodMonthDesc(1L)).thenReturn(List.of());

        TrainerRevenueSummaryDTO result = statementService.getTrainerRevenueSummary(1L);

        // PEER_TUTOR => 40% platform fee => 60% trainer earnings of 100000 = 60000
        assertEquals(new BigDecimal("60000.00"), result.getAvailableBalance());
    }

    @Test
    void getTrainerRevenueSummaryShouldSumOnlyPaidStatementsAsTotalPaid() {
        User trainer = trainer(1L, "trainer@example.com");
        when(userRepository.findById(1L)).thenReturn(Optional.of(trainer));
        when(trainerProfileRepository.findById(1L)).thenReturn(Optional.of(
                TrainerProfile.builder().userId(1L).trainerType("PROFESSIONAL").build()));
        when(paymentRepository.findRevenueDataByTrainerId(1L)).thenReturn(List.of());
        MonthlyStatement paid = MonthlyStatement.builder().id(1L).trainer(trainer).periodMonth("2026-06")
                .status("PAID").netPayoutAmount(new BigDecimal("500000")).build();
        MonthlyStatement unpaid = MonthlyStatement.builder().id(2L).trainer(trainer).periodMonth("2026-07")
                .status("PENDING_TRAINER_CONFIRM").netPayoutAmount(new BigDecimal("300000")).build();
        when(statementRepository.findByTrainerIdOrderByPeriodMonthDesc(1L)).thenReturn(List.of(paid, unpaid));

        TrainerRevenueSummaryDTO result = statementService.getTrainerRevenueSummary(1L);

        assertEquals(new BigDecimal("500000"), result.getTotalPaid());
    }

    @Test
    void getTrainerRevenueSummaryShouldExcludeAlreadySettledPaymentsFromBalances() {
        User trainer = trainer(1L, "trainer@example.com");
        when(userRepository.findById(1L)).thenReturn(Optional.of(trainer));
        when(trainerProfileRepository.findById(1L)).thenReturn(Optional.of(
                TrainerProfile.builder().userId(1L).trainerType("PROFESSIONAL").build()));
        Object[] settledRow = new Object[]{new BigDecimal("70000"), new BigDecimal("100000"), "IN_STATEMENT", java.sql.Timestamp.valueOf(LocalDateTime.now().minusDays(2))};
        when(paymentRepository.findRevenueDataByTrainerId(1L)).thenReturn(List.<Object[]>of(settledRow));
        when(statementRepository.findByTrainerIdOrderByPeriodMonthDesc(1L)).thenReturn(List.of());

        TrainerRevenueSummaryDTO result = statementService.getTrainerRevenueSummary(1L);

        assertEquals(BigDecimal.ZERO, result.getPendingHoldBalance());
        assertEquals(BigDecimal.ZERO, result.getAvailableBalance());
    }

    @Test
    void getTrainerRevenueSummaryShouldDefaultTrainerTypeToProfessionalWhenNoProfile() {
        User trainer = trainer(1L, "trainer@example.com");
        when(userRepository.findById(1L)).thenReturn(Optional.of(trainer));
        when(trainerProfileRepository.findById(1L)).thenReturn(Optional.empty());
        when(paymentRepository.findRevenueDataByTrainerId(1L)).thenReturn(List.of());
        when(statementRepository.findByTrainerIdOrderByPeriodMonthDesc(1L)).thenReturn(List.of());

        TrainerRevenueSummaryDTO result = statementService.getTrainerRevenueSummary(1L);

        assertEquals("PROFESSIONAL", result.getTrainerType());
    }

    // =================================================================
    // confirmTrainerStatement
    // =================================================================

    @Test
    void confirmTrainerStatementShouldThrowWhenStatementNotFound() {
        when(statementRepository.findById(1L)).thenReturn(Optional.empty());

        assertThrows(RuntimeException.class, () -> statementService.confirmTrainerStatement(1L, 5L));
    }

    @Test
    void confirmTrainerStatementShouldThrowWhenNotOwnedByCallingTrainer() {
        User owner = trainer(1L, "owner@example.com");
        MonthlyStatement statement = MonthlyStatement.builder().id(1L).trainer(owner).periodMonth("2026-07").build();
        when(statementRepository.findById(1L)).thenReturn(Optional.of(statement));

        assertThrows(RuntimeException.class, () -> statementService.confirmTrainerStatement(1L, 999L));
    }

    @Test
    void confirmTrainerStatementShouldSetStatusConfirmedAndTimestamp() {
        User owner = trainer(1L, "owner@example.com");
        MonthlyStatement statement = MonthlyStatement.builder().id(1L).trainer(owner).periodMonth("2026-07").build();
        when(statementRepository.findById(1L)).thenReturn(Optional.of(statement));
        when(statementRepository.save(any())).thenAnswer(inv -> inv.getArgument(0));
        when(trainerProfileRepository.findById(1L)).thenReturn(Optional.empty());

        MonthlyStatementDTO result = statementService.confirmTrainerStatement(1L, 1L);

        assertEquals("TRAINER_CONFIRMED", result.getStatus());
        assertEquals(true, statement.getTrainerConfirmedAt() != null);
    }

    // =================================================================
    // getCourseManagerStatements
    // =================================================================

    @Test
    void getCourseManagerStatementsShouldFilterByPeriodAndStatusWhenBothProvided() {
        when(statementRepository.findByPeriodMonthAndStatus("2026-07", "PAID")).thenReturn(List.of());

        statementService.getCourseManagerStatements("2026-07", "PAID");

        verify(statementRepository).findByPeriodMonthAndStatus("2026-07", "PAID");
        verify(statementRepository, never()).findAll();
    }

    @Test
    void getCourseManagerStatementsShouldFilterByPeriodOnlyWhenStatusMissing() {
        when(statementRepository.findByPeriodMonth("2026-07")).thenReturn(List.of());

        statementService.getCourseManagerStatements("2026-07", null);

        verify(statementRepository).findByPeriodMonth("2026-07");
    }

    @Test
    void getCourseManagerStatementsShouldReturnAllWhenNeitherFilterProvided() {
        when(statementRepository.findAll()).thenReturn(List.of());

        statementService.getCourseManagerStatements(null, null);

        verify(statementRepository).findAll();
    }

    // =================================================================
    // generateMonthlyCutoff
    // =================================================================

    @Test
    void generateMonthlyCutoffShouldGroupPendingPaymentsByTrainerComputeTaxAndNotify() {
        // Amounts must reach trainer gross >= 2,000,000 VND: per Circular 111/2013/TT-BTC
        // (see MonthlyStatementServiceImpl#generateMonthlyCutoff), PIT is only withheld once
        // total income for the period is 2,000,000 VND or more.
        User creator = trainer(2L, "trainer@example.com");
        Payment p1 = payment(creator, new BigDecimal("10000000"), "PENDING", LocalDateTime.now());
        p1.setPlatformFee(new BigDecimal("3000000"));
        p1.setTrainerEarnings(new BigDecimal("7000000"));
        Payment p2 = payment(creator, new BigDecimal("5000000"), null, LocalDateTime.now());
        when(paymentRepository.findAll()).thenReturn(List.of(p1, p2));
        when(trainerProfileRepository.findById(2L)).thenReturn(Optional.of(
                TrainerProfile.builder().userId(2L).trainerType("PROFESSIONAL").build()));
        when(statementRepository.findByTrainerIdAndPeriodMonth(eq(2L), any())).thenReturn(Optional.empty());
        when(statementRepository.save(any())).thenAnswer(inv -> {
            MonthlyStatement s = inv.getArgument(0);
            s.setId(100L);
            return s;
        });

        List<MonthlyStatementDTO> result = statementService.generateMonthlyCutoff("2026-07");

        assertEquals(1, result.size());
        MonthlyStatementDTO dto = result.get(0);
        assertEquals(2, dto.getTotalOrders());
        // p1 gross 7000000 + p2 fallback gross (5000000 * 0.70 = 3500000) = 10500000 trainer gross
        assertEquals(new BigDecimal("10500000.00"), dto.getTotalTrainerGross());
        // trainer gross >= 2,000,000 -> PIT tax = 10% of trainer gross = 1050000; net payout = 9450000
        assertEquals(new BigDecimal("1050000.00"), dto.getPitTaxAmount());
        assertEquals(new BigDecimal("9450000.00"), dto.getNetPayoutAmount());

        verify(notificationService).notifyUser(eq(creator), eq(NotificationService.TYPE_STATEMENT_READY), any(), any(), any());
        verify(paymentRepository, times(2)).save(any());
    }

    @Test
    void generateMonthlyCutoffShouldMarkProcessedPaymentsAsInStatementAndLinkStatementId() {
        User creator = trainer(2L, "trainer@example.com");
        Payment p1 = payment(creator, new BigDecimal("100000"), "PENDING", LocalDateTime.now());
        when(paymentRepository.findAll()).thenReturn(List.of(p1));
        when(trainerProfileRepository.findById(2L)).thenReturn(Optional.of(
                TrainerProfile.builder().userId(2L).trainerType("PROFESSIONAL").build()));
        when(statementRepository.findByTrainerIdAndPeriodMonth(eq(2L), any())).thenReturn(Optional.empty());
        when(statementRepository.save(any())).thenAnswer(inv -> {
            MonthlyStatement s = inv.getArgument(0);
            s.setId(200L);
            return s;
        });

        statementService.generateMonthlyCutoff("2026-07");

        ArgumentCaptor<Payment> captor = ArgumentCaptor.forClass(Payment.class);
        verify(paymentRepository).save(captor.capture());
        assertEquals("IN_STATEMENT", captor.getValue().getSettlementStatus());
        assertEquals(200L, captor.getValue().getStatementId());
    }

    @Test
    void generateMonthlyCutoffShouldIgnorePaymentsNotSuccessOrAlreadySettled() {
        User creator = trainer(2L, "trainer@example.com");
        Payment notSuccess = payment(creator, new BigDecimal("100000"), "PENDING", LocalDateTime.now());
        notSuccess.setStatus("FAILED");
        Payment alreadySettled = payment(creator, new BigDecimal("100000"), "SETTLED", LocalDateTime.now());
        when(paymentRepository.findAll()).thenReturn(List.of(notSuccess, alreadySettled));

        List<MonthlyStatementDTO> result = statementService.generateMonthlyCutoff("2026-07");

        assertEquals(0, result.size());
        verify(notificationService, never()).notifyUser(any(), any(), any(), any(), any());
    }

    @Test
    void generateMonthlyCutoffShouldReuseExistingStatementAndPreserveNonDraftStatus() {
        User creator = trainer(2L, "trainer@example.com");
        Payment p1 = payment(creator, new BigDecimal("100000"), "PENDING", LocalDateTime.now());
        p1.setPlatformFee(new BigDecimal("30000"));
        p1.setTrainerEarnings(new BigDecimal("70000"));
        when(paymentRepository.findAll()).thenReturn(List.of(p1));
        when(trainerProfileRepository.findById(2L)).thenReturn(Optional.of(
                TrainerProfile.builder().userId(2L).trainerType("PROFESSIONAL").build()));
        MonthlyStatement existing = MonthlyStatement.builder().id(99L).trainer(creator).periodMonth("2026-07")
                .status("TRAINER_CONFIRMED").build();
        when(statementRepository.findByTrainerIdAndPeriodMonth(2L, "2026-07")).thenReturn(Optional.of(existing));
        when(statementRepository.save(any())).thenAnswer(inv -> inv.getArgument(0));

        List<MonthlyStatementDTO> result = statementService.generateMonthlyCutoff("2026-07");

        assertEquals(1, result.size());
        assertEquals(99L, result.get(0).getId());
        assertEquals("TRAINER_CONFIRMED", result.get(0).getStatus());
    }

    @Test
    void generateMonthlyCutoffShouldDefaultPeriodMonthToCurrentMonthWhenNotProvided() {
        User creator = trainer(2L, "trainer@example.com");
        Payment p1 = payment(creator, new BigDecimal("100000"), "PENDING", LocalDateTime.now());
        when(paymentRepository.findAll()).thenReturn(List.of(p1));
        when(trainerProfileRepository.findById(2L)).thenReturn(Optional.of(
                TrainerProfile.builder().userId(2L).trainerType("PROFESSIONAL").build()));
        when(statementRepository.findByTrainerIdAndPeriodMonth(eq(2L), any())).thenReturn(Optional.empty());
        when(statementRepository.save(any())).thenAnswer(inv -> {
            MonthlyStatement s = inv.getArgument(0);
            s.setId(300L);
            return s;
        });

        List<MonthlyStatementDTO> result = statementService.generateMonthlyCutoff(null);

        String expectedPeriod = LocalDateTime.now().format(DateTimeFormatter.ofPattern("yyyy-MM"));
        assertEquals(expectedPeriod, result.get(0).getPeriodMonth());
    }

    // =================================================================
    // confirmTrainerStatement (continued) / rejectTrainerStatement
    // =================================================================

    @Test
    void rejectTrainerStatementShouldThrowWhenStatementNotFound() {
        when(statementRepository.findById(1L)).thenReturn(Optional.empty());

        assertThrows(RuntimeException.class, () -> statementService.rejectTrainerStatement(1L, 5L, "reason"));
    }

    @Test
    void rejectTrainerStatementShouldThrowWhenNotOwnedByCallingTrainer() {
        User owner = trainer(1L, "owner@example.com");
        MonthlyStatement statement = MonthlyStatement.builder().id(1L).trainer(owner).periodMonth("2026-07").build();
        when(statementRepository.findById(1L)).thenReturn(Optional.of(statement));

        assertThrows(RuntimeException.class, () -> statementService.rejectTrainerStatement(1L, 999L, "reason"));
    }

    @Test
    void rejectTrainerStatementShouldSetStatusRejectedAndAppendReasonToAdminNotes() {
        User owner = trainer(1L, "owner@example.com");
        MonthlyStatement statement = MonthlyStatement.builder().id(1L).trainer(owner).periodMonth("2026-07")
                .adminNotes("Existing note").build();
        when(statementRepository.findById(1L)).thenReturn(Optional.of(statement));
        when(statementRepository.save(any())).thenAnswer(inv -> inv.getArgument(0));
        when(trainerProfileRepository.findById(1L)).thenReturn(Optional.empty());

        MonthlyStatementDTO result = statementService.rejectTrainerStatement(1L, 1L, "Amount looks wrong");

        assertEquals("REJECTED", result.getStatus());
        assertTrue(statement.getAdminNotes().contains("Existing note"));
        assertTrue(statement.getAdminNotes().contains("Rejected by Trainer: Amount looks wrong"));
    }

    @Test
    void rejectTrainerStatementShouldSkipAppendingNoteWhenReasonBlank() {
        User owner = trainer(1L, "owner@example.com");
        MonthlyStatement statement = MonthlyStatement.builder().id(1L).trainer(owner).periodMonth("2026-07").build();
        when(statementRepository.findById(1L)).thenReturn(Optional.of(statement));
        when(statementRepository.save(any())).thenAnswer(inv -> inv.getArgument(0));
        when(trainerProfileRepository.findById(1L)).thenReturn(Optional.empty());

        statementService.rejectTrainerStatement(1L, 1L, "   ");

        assertEquals(null, statement.getAdminNotes());
    }

    // =================================================================
    // cancelStatement
    // =================================================================

    @Test
    void cancelStatementShouldThrowWhenStatementNotFound() {
        when(statementRepository.findById(1L)).thenReturn(Optional.empty());

        assertThrows(RuntimeException.class, () -> statementService.cancelStatement(1L));
    }

    @Test
    void cancelStatementShouldSetCancelledAndReleaseLinkedPaymentsToPending() {
        User owner = trainer(1L, "owner@example.com");
        MonthlyStatement statement = MonthlyStatement.builder().id(1L).trainer(owner).periodMonth("2026-07")
                .status("PENDING_TRAINER_CONFIRM").build();
        Payment linked = payment(owner, new BigDecimal("100000"), "IN_STATEMENT", LocalDateTime.now());
        linked.setStatementId(1L);
        when(statementRepository.findById(1L)).thenReturn(Optional.of(statement));
        when(statementRepository.save(any())).thenAnswer(inv -> inv.getArgument(0));
        when(paymentRepository.findByStatementId(1L)).thenReturn(List.of(linked));
        when(trainerProfileRepository.findById(1L)).thenReturn(Optional.empty());

        MonthlyStatementDTO result = statementService.cancelStatement(1L);

        assertEquals("CANCELLED", result.getStatus());
        assertEquals(null, linked.getStatementId());
        assertEquals("PENDING", linked.getSettlementStatus());
        verify(paymentRepository).save(linked);
    }

    // =================================================================
    // regenerateStatement
    // =================================================================

    @Test
    void regenerateStatementShouldThrowWhenStatementNotFound() {
        when(statementRepository.findById(1L)).thenReturn(Optional.empty());

        assertThrows(RuntimeException.class, () -> statementService.regenerateStatement(1L));
    }

    @Test
    void regenerateStatementShouldThrowWhenStatusNotRejectedOrCancelled() {
        User owner = trainer(1L, "owner@example.com");
        MonthlyStatement statement = MonthlyStatement.builder().id(1L).trainer(owner).periodMonth("2026-07")
                .status("PENDING_TRAINER_CONFIRM").build();
        when(statementRepository.findById(1L)).thenReturn(Optional.of(statement));

        assertThrows(IllegalStateException.class, () -> statementService.regenerateStatement(1L));
    }

    @Test
    void regenerateStatementShouldRecalculateFromLinkedPaymentsAndNotifyTrainer() {
        User owner = trainer(1L, "owner@example.com");
        MonthlyStatement statement = MonthlyStatement.builder().id(1L).trainer(owner).periodMonth("2026-07")
                .status("REJECTED").build();
        Payment linked = payment(owner, new BigDecimal("100000"), "IN_STATEMENT", LocalDateTime.now());
        when(statementRepository.findById(1L)).thenReturn(Optional.of(statement));
        when(statementRepository.save(any())).thenAnswer(inv -> inv.getArgument(0));
        when(paymentRepository.findByStatementId(1L)).thenReturn(List.of(linked));
        when(trainerProfileRepository.findById(1L)).thenReturn(Optional.of(
                TrainerProfile.builder().userId(1L).trainerType("PROFESSIONAL").build()));

        MonthlyStatementDTO result = statementService.regenerateStatement(1L);

        assertEquals("PENDING_TRAINER_CONFIRM", result.getStatus());
        assertEquals(1, result.getTotalOrders());
        assertEquals(new BigDecimal("70000.00"), result.getTotalTrainerGross());
        verify(notificationService).notifyUser(eq(owner), eq(NotificationService.TYPE_STATEMENT_READY), any(), any(), any());
    }

    @Test
    void regenerateStatementShouldFallBackToTrainersPendingPaymentsWhenNoneLinked() {
        User owner = trainer(1L, "owner@example.com");
        MonthlyStatement statement = MonthlyStatement.builder().id(1L).trainer(owner).periodMonth("2026-07")
                .status("CANCELLED").build();
        Payment fallback = payment(owner, new BigDecimal("100000"), "PENDING", LocalDateTime.now());
        when(statementRepository.findById(1L)).thenReturn(Optional.of(statement));
        when(statementRepository.save(any())).thenAnswer(inv -> inv.getArgument(0));
        when(paymentRepository.findByStatementId(1L)).thenReturn(List.of());
        when(paymentRepository.findByCourseCreatorIdAndStatus(1L, "SUCCESS")).thenReturn(List.of(fallback));
        when(trainerProfileRepository.findById(1L)).thenReturn(Optional.of(
                TrainerProfile.builder().userId(1L).trainerType("PROFESSIONAL").build()));

        MonthlyStatementDTO result = statementService.regenerateStatement(1L);

        assertEquals(1, result.getTotalOrders());
    }

    // =================================================================
    // getStatementPayments
    // =================================================================

    @Test
    void getStatementPaymentsShouldMapLinkedPaymentsToManagerDTO() {
        User buyer = trainer(3L, "buyer@example.com");
        User creator = trainer(2L, "creator@example.com");
        Course course = Course.builder().id(1L).title("Course A").creator(creator).build();
        Payment p = Payment.builder().id(80L).user(buyer).course(course).txnRef("80")
                .amount(new BigDecimal("100000")).status("SUCCESS").statementId(5L).build();
        when(paymentRepository.findByStatementId(5L)).thenReturn(List.of(p));

        List<com.hango.hango_backend.dto.ManagerPaymentDTO> result = statementService.getStatementPayments(5L);

        assertEquals(1, result.size());
        assertEquals("Course A", result.get(0).getCourseTitle());
        assertEquals("Trainer 2", result.get(0).getTrainerName());
        assertEquals(2L, result.get(0).getTrainerId());
    }

    @Test
    void getStatementPaymentsShouldReturnEmptyListWhenNoPaymentsLinked() {
        when(paymentRepository.findByStatementId(9L)).thenReturn(List.of());

        List<com.hango.hango_backend.dto.ManagerPaymentDTO> result = statementService.getStatementPayments(9L);

        assertTrue(result.isEmpty());
    }

    // =================================================================
    // exportStatementsToExcel
    // =================================================================

    @Test
    void exportStatementsToExcelShouldReturnNonEmptyWorkbookBytes() {
        User owner = trainer(1L, "owner@example.com");
        MonthlyStatement statement = MonthlyStatement.builder().id(1L).trainer(owner).periodMonth("2026-07")
                .status("PAID").netPayoutAmount(new BigDecimal("500000")).build();
        when(statementRepository.findAll()).thenReturn(List.of(statement));
        when(trainerProfileRepository.findById(1L)).thenReturn(Optional.empty());

        byte[] result = statementService.exportStatementsToExcel(null, null);

        assertTrue(result.length > 0);
    }

    @Test
    void exportStatementsToExcelShouldReturnValidWorkbookWhenNoStatementsMatch() {
        when(statementRepository.findByPeriodMonth("2026-08")).thenReturn(List.of());

        byte[] result = statementService.exportStatementsToExcel("2026-08", null);

        assertTrue(result.length > 0);
    }

    // =================================================================
    // settleStatement
    // =================================================================

    @Test
    void settleStatementShouldThrowWhenStatementNotFound() {
        when(statementRepository.findById(1L)).thenReturn(Optional.empty());

        assertThrows(RuntimeException.class, () -> statementService.settleStatement(1L, "TXN1", "note"));
    }

    @Test
    void settleStatementThreeArgOverloadShouldThrowBecausePayoutReceiptUrlIsRequired() {
        User owner = trainer(1L, "owner@example.com");
        MonthlyStatement statement = MonthlyStatement.builder().id(2L).trainer(owner).periodMonth("2026-07")
                .netPayoutAmount(new BigDecimal("500000")).build();
        when(statementRepository.findById(2L)).thenReturn(Optional.of(statement));

        assertThrows(IllegalArgumentException.class, () -> statementService.settleStatement(2L, "TXN-999", "note"));
    }

    @Test
    void settleStatementShouldThrowWhenBankTxnRefIsBlank() {
        User owner = trainer(1L, "owner@example.com");
        MonthlyStatement statement = MonthlyStatement.builder().id(3L).trainer(owner).periodMonth("2026-07").build();
        when(statementRepository.findById(3L)).thenReturn(Optional.of(statement));

        assertThrows(IllegalArgumentException.class,
                () -> statementService.settleStatement(3L, "  ", "note", "https://example.com/r.png"));
    }

    @Test
    void settleStatementShouldThrowWhenBankTxnRefTooShort() {
        User owner = trainer(1L, "owner@example.com");
        MonthlyStatement statement = MonthlyStatement.builder().id(4L).trainer(owner).periodMonth("2026-07").build();
        when(statementRepository.findById(4L)).thenReturn(Optional.of(statement));

        assertThrows(IllegalArgumentException.class,
                () -> statementService.settleStatement(4L, "AB", "note", "https://example.com/r.png"));
    }

    @Test
    void settleStatementShouldThrowWhenReceiptUrlDoesNotStartWithHttp() {
        User owner = trainer(1L, "owner@example.com");
        MonthlyStatement statement = MonthlyStatement.builder().id(5L).trainer(owner).periodMonth("2026-07").build();
        when(statementRepository.findById(5L)).thenReturn(Optional.of(statement));

        assertThrows(IllegalArgumentException.class,
                () -> statementService.settleStatement(5L, "TXN-123", "note", "ftp://example.com/r.png"));
    }

    @Test
    void settleStatementShouldThrowWhenReceiptUrlHasUnsupportedExtension() {
        User owner = trainer(1L, "owner@example.com");
        MonthlyStatement statement = MonthlyStatement.builder().id(6L).trainer(owner).periodMonth("2026-07").build();
        when(statementRepository.findById(6L)).thenReturn(Optional.of(statement));

        assertThrows(IllegalArgumentException.class,
                () -> statementService.settleStatement(6L, "TXN-123", "note", "https://example.com/r.webp"));
    }

    @Test
    void settleStatementShouldUpdateLinkedPaymentsToSettled() {
        User owner = trainer(1L, "owner@example.com");
        MonthlyStatement statement = MonthlyStatement.builder().id(7L).trainer(owner).periodMonth("2026-07")
                .netPayoutAmount(new BigDecimal("500000")).build();
        Payment linked = payment(owner, new BigDecimal("100000"), "IN_STATEMENT", LocalDateTime.now());
        when(statementRepository.findById(7L)).thenReturn(Optional.of(statement));
        when(statementRepository.save(any())).thenAnswer(inv -> inv.getArgument(0));
        when(paymentRepository.findByStatementId(7L)).thenReturn(List.of(linked));
        when(trainerProfileRepository.findById(1L)).thenReturn(Optional.empty());

        statementService.settleStatement(7L, "TXN-777", "note", "https://example.com/r.jpg");

        assertEquals("SETTLED", linked.getSettlementStatus());
        verify(paymentRepository).save(linked);
    }

    @Test
    void settleStatementShouldMarkPaidAndSetBankTxnRefAndNotes() {
        User trainerUser = trainer(1L, "trainer@example.com");
        MonthlyStatement statement = MonthlyStatement.builder().id(1L).trainer(trainerUser).periodMonth("2026-07")
                .netPayoutAmount(new BigDecimal("500000")).build();
        when(statementRepository.findById(1L)).thenReturn(Optional.of(statement));
        when(statementRepository.save(any())).thenAnswer(inv -> inv.getArgument(0));
        when(trainerProfileRepository.findById(1L)).thenReturn(Optional.empty());

        MonthlyStatementDTO result = statementService.settleStatement(1L, "TXN-123", "Paid via bank transfer",
                "https://example.com/receipts/txn-123.png");

        assertEquals("PAID", result.getStatus());
        assertEquals("TXN-123", statement.getBankTxnRef());
        assertEquals("Paid via bank transfer", statement.getAdminNotes());
        assertEquals(true, statement.getPaidAt() != null);
        verify(emailService).sendSettlementPaidEmail(eq("trainer@example.com"), any(), eq("2026-07"), any(), eq("TXN-123"), eq("https://example.com/receipts/txn-123.png"));
    }

    // =================================================================
    // getTrainerStatements
    // =================================================================

    @Test
    void getTrainerStatementsShouldReturnEmptyListWhenTrainerHasNoStatements() {
        when(statementRepository.findByTrainerIdOrderByPeriodMonthDesc(1L)).thenReturn(List.of());

        List<MonthlyStatementDTO> result = statementService.getTrainerStatements(1L);

        assertTrue(result.isEmpty());
    }

    @Test
    void getTrainerStatementsShouldMapAllStatementsForTheGivenTrainerNewestFirst() {
        User trainerUser = trainer(1L, "trainer@example.com");
        MonthlyStatement recent = MonthlyStatement.builder().id(2L).trainer(trainerUser).periodMonth("2026-07")
                .status("PENDING_TRAINER_CONFIRM").netPayoutAmount(new BigDecimal("100000")).build();
        MonthlyStatement older = MonthlyStatement.builder().id(1L).trainer(trainerUser).periodMonth("2026-06")
                .status("PAID").netPayoutAmount(new BigDecimal("200000")).build();
        when(statementRepository.findByTrainerIdOrderByPeriodMonthDesc(1L)).thenReturn(List.of(recent, older));
        when(trainerProfileRepository.findById(1L)).thenReturn(Optional.empty());

        List<MonthlyStatementDTO> result = statementService.getTrainerStatements(1L);

        assertEquals(2, result.size());
        assertEquals("2026-07", result.get(0).getPeriodMonth());
        assertEquals("2026-06", result.get(1).getPeriodMonth());
    }

    @Test
    void getTrainerStatementsShouldNotLeakAnotherTrainersStatements() {
        when(statementRepository.findByTrainerIdOrderByPeriodMonthDesc(1L)).thenReturn(List.of());

        statementService.getTrainerStatements(1L);

        verify(statementRepository).findByTrainerIdOrderByPeriodMonthDesc(1L);
        verify(statementRepository, never()).findAll();
    }
}
