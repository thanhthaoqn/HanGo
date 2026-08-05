package com.hango.hango_backend.service;

import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDate;
import java.time.format.DateTimeFormatter;

@Slf4j
@Component
@RequiredArgsConstructor
public class MonthlyStatementScheduler {

    private final MonthlyStatementService statementService;

    /**
     * Tự động chạy chốt sổ doanh thu tháng trước vào lúc 00:00 ngày đầu tiên của mỗi tháng.
     * Cron format: Second Minute Hour Day-of-month Month Day-of-week
     */
    @Scheduled(cron = "0 0 0 1 * *")
    @Transactional
    public void autoGenerateMonthlyCutoff() {
        LocalDate previousMonth = LocalDate.now().minusMonths(1);
        String periodMonth = previousMonth.format(DateTimeFormatter.ofPattern("yyyy-MM"));

        log.info("Starting automated monthly settlement cutoff scheduler for period: {}", periodMonth);
        try {
            statementService.generateMonthlyCutoff(periodMonth);
            log.info("Successfully executed automated monthly cutoff for period: {}", periodMonth);
        } catch (Exception e) {
            log.error("Failed to execute automated monthly cutoff for period: {}", periodMonth, e);
        }
    }
}
