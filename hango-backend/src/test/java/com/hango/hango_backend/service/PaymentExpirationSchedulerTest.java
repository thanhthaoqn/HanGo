package com.hango.hango_backend.service;

import com.hango.hango_backend.entity.Payment;
import com.hango.hango_backend.repository.PaymentRepository;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.time.LocalDateTime;
import java.util.List;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.times;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class PaymentExpirationSchedulerTest {

    @Mock
    private PaymentRepository paymentRepository;

    @InjectMocks
    private PaymentExpirationScheduler scheduler;

    private Payment payment(Long id, String status) {
        Payment p = new Payment();
        p.setId(id);
        p.setStatus(status);
        return p;
    }

    // =================================================================
    // expirePendingPayments
    // =================================================================

    @Test
    void expirePendingPaymentsShouldDoNothingWhenNoStalePaymentsFound() {
        when(paymentRepository.findByStatusAndCreatedAtBefore(eq("PENDING"), any(LocalDateTime.class)))
                .thenReturn(List.of());

        scheduler.expirePendingPayments();

        verify(paymentRepository, never()).save(any());
    }

    @Test
    void expirePendingPaymentsShouldMarkEachStalePaymentAsExpiredAndSaveIt() {
        Payment p1 = payment(1L, "PENDING");
        Payment p2 = payment(2L, "PENDING");
        when(paymentRepository.findByStatusAndCreatedAtBefore(eq("PENDING"), any(LocalDateTime.class)))
                .thenReturn(List.of(p1, p2));

        scheduler.expirePendingPayments();

        assertEquals("EXPIRED", p1.getStatus());
        assertEquals("EXPIRED", p2.getStatus());
        verify(paymentRepository, times(2)).save(any(Payment.class));
    }

    @Test
    void expirePendingPaymentsShouldQueryPendingStatusWithThirtyMinuteCutoffFromNow() {
        ArgumentCaptor<LocalDateTime> cutoffCaptor = ArgumentCaptor.forClass(LocalDateTime.class);
        when(paymentRepository.findByStatusAndCreatedAtBefore(eq("PENDING"), cutoffCaptor.capture()))
                .thenReturn(List.of());

        LocalDateTime before = LocalDateTime.now().minusMinutes(30);
        scheduler.expirePendingPayments();
        LocalDateTime after = LocalDateTime.now().minusMinutes(30);

        LocalDateTime usedCutoff = cutoffCaptor.getValue();
        assertTrue(!usedCutoff.isBefore(before.minusSeconds(5)) && !usedCutoff.isAfter(after.plusSeconds(5)),
                "cutoff should be ~30 minutes before now, was: " + usedCutoff);
    }
}
