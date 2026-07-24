package com.hango.hango_backend.service;

import com.hango.hango_backend.entity.Payment;
import com.hango.hango_backend.repository.PaymentRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDateTime;
import java.util.List;

@Slf4j
@Component
@RequiredArgsConstructor
public class PaymentExpirationScheduler {

    private final PaymentRepository paymentRepository;

    /**
     * Tự động quét và đóng các giao dịch PENDING được tạo quá 30 phút.
     * Chạy mỗi 15 phút.
     */
    @Scheduled(cron = "0 */15 * * * *")
    @Transactional
    public void expirePendingPayments() {
        LocalDateTime cutoffTime = LocalDateTime.now().minusMinutes(30);
        List<Payment> expiredPayments = paymentRepository.findByStatusAndCreatedAtBefore("PENDING", cutoffTime);

        if (!expiredPayments.isEmpty()) {
            log.info("Found {} pending payments older than 30 minutes. Marking as EXPIRED...", expiredPayments.size());
            for (Payment p : expiredPayments) {
                p.setStatus("EXPIRED");
                paymentRepository.save(p);
            }
            log.info("Successfully marked {} payments as EXPIRED.", expiredPayments.size());
        }
    }
}
