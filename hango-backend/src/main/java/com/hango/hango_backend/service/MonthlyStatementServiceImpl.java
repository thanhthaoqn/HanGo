package com.hango.hango_backend.service;

import com.hango.hango_backend.dto.ManagerPaymentDTO;
import com.hango.hango_backend.dto.MonthlyStatementDTO;
import com.hango.hango_backend.dto.TrainerRevenueSummaryDTO;

import com.hango.hango_backend.entity.MonthlyStatement;
import com.hango.hango_backend.entity.Payment;
import com.hango.hango_backend.entity.TrainerProfile;
import com.hango.hango_backend.entity.User;
import com.hango.hango_backend.entity.Course;
import com.hango.hango_backend.repository.CourseRepository;
import com.hango.hango_backend.entity.SystemParameter;
import com.hango.hango_backend.repository.SystemParameterRepository;
import com.hango.hango_backend.repository.MonthlyStatementRepository;
import com.hango.hango_backend.repository.PaymentRepository;
import com.hango.hango_backend.repository.TrainerProfileRepository;
import com.hango.hango_backend.repository.UserRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.time.LocalDateTime;
import java.time.format.DateTimeFormatter;
import java.util.*;
import java.util.stream.Collectors;

@Slf4j
@Service
@RequiredArgsConstructor
public class MonthlyStatementServiceImpl implements MonthlyStatementService {

    private final MonthlyStatementRepository statementRepository;
    private final PaymentRepository paymentRepository;
    private final TrainerProfileRepository trainerProfileRepository;
    private final UserRepository userRepository;
    private final CourseRepository courseRepository;
    private final SystemParameterRepository systemParameterRepository;
    private final EmailService emailService;
    private final NotificationService notificationService;

    @Override
    @Transactional(readOnly = true)
    public TrainerRevenueSummaryDTO getTrainerRevenueSummary(Long trainerId) {
        User trainer = userRepository.findById(trainerId)
                .orElseThrow(() -> new RuntimeException("Trainer not found with ID: " + trainerId));

        TrainerProfile profile = trainerProfileRepository.findById(trainerId).orElse(null);
        String trainerType = profile != null && profile.getTrainerType() != null ? profile.getTrainerType() : "PROFESSIONAL";

        List<Object[]> revenueRows = paymentRepository.findRevenueDataByTrainerId(trainerId);

        LocalDateTime holdThreshold = LocalDateTime.now().minusDays(7);
        BigDecimal pendingHold = BigDecimal.ZERO;
        BigDecimal available = BigDecimal.ZERO;

        for (Object[] row : revenueRows) {
            BigDecimal earnings = row[0] != null ? new BigDecimal(row[0].toString()) : null;
            if (earnings == null) {
                // Default calculation if old record
                double platformRate = "PEER_TUTOR".equalsIgnoreCase(trainerType) ? 0.40 : 0.30;
                BigDecimal gross = row[1] != null ? new BigDecimal(row[1].toString()) : BigDecimal.ZERO;
                BigDecimal pFee = gross.multiply(BigDecimal.valueOf(platformRate)).setScale(2, RoundingMode.HALF_UP);
                earnings = gross.subtract(pFee);
            }

            String settlementStatus = row[2] != null ? row[2].toString() : null;
            java.sql.Timestamp createdAtTs = row[3] != null ? (java.sql.Timestamp) row[3] : null;
            LocalDateTime createdAt = createdAtTs != null ? createdAtTs.toLocalDateTime() : null;

            if ("PENDING".equalsIgnoreCase(settlementStatus) || settlementStatus == null) {
                if (createdAt != null && createdAt.isAfter(holdThreshold)) {
                    pendingHold = pendingHold.add(earnings);
                } else {
                    available = available.add(earnings);
                }
            }
        }

        List<MonthlyStatement> statements = statementRepository.findByTrainerIdOrderByPeriodMonthDesc(trainerId);
        BigDecimal totalPaid = statements.stream()
                .filter(s -> "PAID".equalsIgnoreCase(s.getStatus()))
                .map(s -> s.getNetPayoutAmount() != null ? s.getNetPayoutAmount() : BigDecimal.ZERO)
                .reduce(BigDecimal.ZERO, BigDecimal::add);

        List<MonthlyStatementDTO> statementDTOs = statements.stream()
                .map(this::mapToDTO)
                .collect(Collectors.toList());

        return TrainerRevenueSummaryDTO.builder()
                .availableBalance(available)
                .pendingHoldBalance(pendingHold)
                .totalPaid(totalPaid)
                .trainerType(trainerType)
                .statements(statementDTOs)
                .build();
    }

    @Override
    @Transactional(readOnly = true)
    public List<MonthlyStatementDTO> getTrainerStatements(Long trainerId) {
        return statementRepository.findByTrainerIdOrderByPeriodMonthDesc(trainerId)
                .stream()
                .map(this::mapToDTO)
                .collect(Collectors.toList());
    }

    @Override
    @Transactional
    public MonthlyStatementDTO confirmTrainerStatement(Long statementId, Long trainerId) {
        MonthlyStatement statement = statementRepository.findById(statementId)
                .orElseThrow(() -> new RuntimeException("Statement not found with ID: " + statementId));

        if (!statement.getTrainer().getId().equals(trainerId)) {
            throw new RuntimeException("Unauthorized statement access");
        }

        statement.setStatus("TRAINER_CONFIRMED");
        statement.setTrainerConfirmedAt(LocalDateTime.now());
        MonthlyStatement saved = statementRepository.save(statement);
        return mapToDTO(saved);
    }

    @Override
    @Transactional
    public MonthlyStatementDTO rejectTrainerStatement(Long statementId, Long trainerId, String rejectReason) {
        MonthlyStatement statement = statementRepository.findById(statementId)
                .orElseThrow(() -> new RuntimeException("Statement not found with ID: " + statementId));

        if (!statement.getTrainer().getId().equals(trainerId)) {
            throw new RuntimeException("Unauthorized statement access");
        }

        statement.setStatus("REJECTED");
        if (rejectReason != null && !rejectReason.trim().isEmpty()) {
            String note = "Rejected by Trainer: " + rejectReason;
            statement.setAdminNotes(statement.getAdminNotes() != null ? (statement.getAdminNotes() + "\n" + note) : note);
        }
        MonthlyStatement saved = statementRepository.save(statement);
        return mapToDTO(saved);
    }

    @Override
    @Transactional(readOnly = true)
    public List<MonthlyStatementDTO> getCourseManagerStatements(String periodMonth, String status) {
        List<MonthlyStatement> list;
        boolean hasPeriod = periodMonth != null && !periodMonth.trim().isEmpty() && !"ALL".equalsIgnoreCase(periodMonth.trim());
        boolean hasStatus = status != null && !status.trim().isEmpty() && !"ALL".equalsIgnoreCase(status.trim());

        if (hasPeriod && hasStatus) {
            list = statementRepository.findByPeriodMonthAndStatus(periodMonth.trim(), status.trim());
        } else if (hasPeriod) {
            list = statementRepository.findByPeriodMonth(periodMonth.trim());
        } else if (hasStatus) {
            list = statementRepository.findByStatus(status.trim());
        } else {
            list = statementRepository.findAll();
        }
        return list.stream()
                .sorted((a, b) -> {
                    if (b.getCreatedAt() != null && a.getCreatedAt() != null) {
                        return b.getCreatedAt().compareTo(a.getCreatedAt());
                    }
                    if (b.getId() != null && a.getId() != null) {
                        return b.getId().compareTo(a.getId());
                    }
                    return 0;
                })
                .map(this::mapToDTO).collect(Collectors.toList());
    }

    @Override
    @Transactional
    public List<MonthlyStatementDTO> generateMonthlyCutoff(String periodMonth) {
        if (periodMonth == null || periodMonth.trim().isEmpty()) {
            periodMonth = LocalDateTime.now().format(DateTimeFormatter.ofPattern("yyyy-MM"));
        }

        // Find all payments with status SUCCESS and settlementStatus PENDING
        List<Payment> allPendingPayments = paymentRepository.findAll().stream()
                .filter(p -> "SUCCESS".equalsIgnoreCase(p.getStatus()))
                .filter(p -> "PENDING".equalsIgnoreCase(p.getSettlementStatus()) || p.getSettlementStatus() == null)
                .collect(Collectors.toList());

        // Group payments by course creator (Trainer)
        Map<User, List<Payment>> paymentsByTrainer = new HashMap<>();
        for (Payment p : allPendingPayments) {
            if (p.getCourse() != null && p.getCourse().getCreator() != null) {
                User creator = p.getCourse().getCreator();
                paymentsByTrainer.computeIfAbsent(creator, k -> new ArrayList<>()).add(p);
            }
        }

        List<MonthlyStatement> generatedStatements = new ArrayList<>();

        for (Map.Entry<User, List<Payment>> entry : paymentsByTrainer.entrySet()) {
            User trainer = entry.getKey();
            List<Payment> trainerPayments = entry.getValue();

            TrainerProfile profile = trainerProfileRepository.findById(trainer.getId()).orElse(null);
            String trainerType = profile != null && profile.getTrainerType() != null ? profile.getTrainerType() : "PROFESSIONAL";
            double platformRate = "PEER_TUTOR".equalsIgnoreCase(trainerType) ? 0.40 : 0.30;

            int totalOrders = trainerPayments.size();
            BigDecimal grossSum = BigDecimal.ZERO;
            BigDecimal platformSum = BigDecimal.ZERO;
            BigDecimal trainerGrossSum = BigDecimal.ZERO;

            for (Payment p : trainerPayments) {
                BigDecimal gross = p.getAmount() != null ? p.getAmount() : BigDecimal.ZERO;
                BigDecimal pFee = p.getPlatformFee();
                BigDecimal tEarn = p.getTrainerEarnings();

                if (pFee == null || tEarn == null) {
                    pFee = gross.multiply(BigDecimal.valueOf(platformRate)).setScale(2, RoundingMode.HALF_UP);
                    tEarn = gross.subtract(pFee);
                }

                grossSum = grossSum.add(gross);
                platformSum = platformSum.add(pFee);
                trainerGrossSum = trainerGrossSum.add(tEarn);
            }

            // Theo Khoản 1 Điều 25 Thông tư 111/2013/TT-BTC: Chỉ khấu trừ 10% Thuế TNCN khi tổng thu nhập từ 2.000.000 VNĐ trở lên
            BigDecimal pitTax = BigDecimal.ZERO;
            if (trainerGrossSum.compareTo(new BigDecimal("2000000")) >= 0) {
                pitTax = trainerGrossSum.multiply(BigDecimal.valueOf(0.10)).setScale(2, RoundingMode.HALF_UP);
            }
            BigDecimal netPayout = trainerGrossSum.subtract(pitTax);

            String finalPeriodMonth = periodMonth;
            MonthlyStatement statement = statementRepository.findByTrainerIdAndPeriodMonth(trainer.getId(), periodMonth)
                    .orElseGet(() -> MonthlyStatement.builder()
                            .statementCode("ST-" + finalPeriodMonth.replace("-", "") + "-TR" + trainer.getId())
                            .trainer(trainer)
                            .periodMonth(finalPeriodMonth)
                            .build());

            statement.setTotalOrders(totalOrders);
            statement.setTotalGrossAmount(grossSum);
            statement.setTotalPlatformFee(platformSum);
            statement.setTotalTrainerGross(trainerGrossSum);
            statement.setPitTaxAmount(pitTax);
            statement.setNetPayoutAmount(netPayout);

            if (profile != null) {
                statement.setBankName(profile.getBankName());
                statement.setBankAccount(profile.getBankAccount());
                statement.setBankAccountName(profile.getBankAccountName());
            }

            if (statement.getStatus() == null || "DRAFT".equalsIgnoreCase(statement.getStatus())) {
                statement.setStatus("PENDING_TRAINER_CONFIRM");
            }

            MonthlyStatement savedStatement = statementRepository.save(statement);
            generatedStatements.add(savedStatement);

            notificationService.notifyUser(trainer, NotificationService.TYPE_STATEMENT_READY,
                    "Monthly statement ready",
                    "Your revenue statement for " + finalPeriodMonth + " (Net payout: "
                            + String.format("%,.0f", netPayout) + " VND) is ready to review.",
                    null);

            // Mark payments as IN_STATEMENT and link to statementId
            for (Payment p : trainerPayments) {
                p.setSettlementStatus("IN_STATEMENT");
                p.setStatementId(savedStatement.getId());
                paymentRepository.save(p);
            }
        }

        return generatedStatements.stream().map(this::mapToDTO).collect(Collectors.toList());
    }

    @Override
    @Transactional
    public MonthlyStatementDTO settleStatement(Long statementId, String bankTxnRef, String notes) {
        return settleStatement(statementId, bankTxnRef, notes, null);
    }

    @Override
    @Transactional
    public MonthlyStatementDTO settleStatement(Long statementId, String bankTxnRef, String notes, String payoutReceiptUrl) {
        MonthlyStatement statement = statementRepository.findById(statementId)
                .orElseThrow(() -> new RuntimeException("Statement not found with ID: " + statementId));

        if (bankTxnRef == null || bankTxnRef.trim().isEmpty()) {
            bankTxnRef = "TXN-" + (statement.getStatementCode() != null ? statement.getStatementCode() : statement.getId()) + "-" + (System.currentTimeMillis() % 1000000);
        } else if (bankTxnRef.trim().length() < 4) {
            throw new IllegalArgumentException("Bank transaction reference code must be at least 4 characters.");
        }
        if (payoutReceiptUrl == null || payoutReceiptUrl.trim().isEmpty()) {
            throw new IllegalArgumentException("Payout receipt proof image URL is required.");
        }

        String trimmedUrl = payoutReceiptUrl.trim();
        if (!trimmedUrl.startsWith("http://") && !trimmedUrl.startsWith("https://")) {
            throw new IllegalArgumentException("Payout receipt URL must start with http:// or https://");
        }
        String lowerUrl = trimmedUrl.toLowerCase();
        if (!lowerUrl.contains(".jpg") && !lowerUrl.contains(".jpeg") && !lowerUrl.contains(".png")) {
            throw new IllegalArgumentException("Invalid receipt file format. Only JPG, JPEG, and PNG images are allowed (WEBP is excluded).");
        }
        statement.setPayoutReceiptUrl(trimmedUrl);

        statement.setStatus("PAID");
        statement.setPaidAt(LocalDateTime.now());
        statement.setBankTxnRef(bankTxnRef.trim());
        if (notes != null && !notes.trim().isEmpty()) {
            statement.setAdminNotes(notes.trim());
        }

        MonthlyStatement saved = statementRepository.save(statement);

        // Update all linked payments' settlementStatus to "SETTLED"
        List<Payment> linkedPayments = paymentRepository.findByStatementId(statementId);
        for (Payment p : linkedPayments) {
            p.setSettlementStatus("SETTLED");
            paymentRepository.save(p);
        }

        // Send email notification to Trainer
        try {
            if (statement.getTrainer() != null && statement.getTrainer().getEmail() != null) {
                String netPayoutText = String.format("%,.0fđ", statement.getNetPayoutAmount() != null ? statement.getNetPayoutAmount() : BigDecimal.ZERO);
                emailService.sendSettlementPaidEmail(
                        statement.getTrainer().getEmail(),
                        statement.getTrainer().getFullName(),
                        statement.getPeriodMonth(),
                        netPayoutText,
                        bankTxnRef,
                        payoutReceiptUrl
                );
            }
        } catch (Exception e) {
            log.warn("Could not send settlement paid email: {}", e.getMessage());
        }

        return mapToDTO(saved);
    }

    @Override
    @Transactional
    public MonthlyStatementDTO cancelStatement(Long statementId) {
        MonthlyStatement statement = statementRepository.findById(statementId)
                .orElseThrow(() -> new RuntimeException("Statement not found with ID: " + statementId));

        statement.setStatus("CANCELLED");
        MonthlyStatement saved = statementRepository.save(statement);

        // Release all linked payments back to PENDING settlement status
        List<Payment> linkedPayments = paymentRepository.findByStatementId(statementId);
        for (Payment p : linkedPayments) {
            p.setStatementId(null);
            p.setSettlementStatus("PENDING");
            paymentRepository.save(p);
        }
        log.info("Cancelled statement ID={} and released {} payments back to PENDING settlement status.", statementId, linkedPayments.size());

        return mapToDTO(saved);
    }

    @Override
    @Transactional
    public MonthlyStatementDTO regenerateStatement(Long statementId) {
        MonthlyStatement statement = statementRepository.findById(statementId)
                .orElseThrow(() -> new RuntimeException("Statement not found with ID: " + statementId));

        if (!"REJECTED".equalsIgnoreCase(statement.getStatus()) && !"CANCELLED".equalsIgnoreCase(statement.getStatus())) {
            throw new IllegalStateException("Only REJECTED or CANCELLED statements can be recalculated & regenerated.");
        }

        User trainer = statement.getTrainer();
        String periodMonth = statement.getPeriodMonth();

        // Find payments for this statement (or trainer's pending payments)
        List<Payment> linkedPayments = paymentRepository.findByStatementId(statementId);
        if (linkedPayments.isEmpty() && trainer != null) {
            linkedPayments = paymentRepository.findByCourseCreatorIdAndStatus(trainer.getId(), "SUCCESS")
                    .stream()
                    .filter(p -> "IN_STATEMENT".equalsIgnoreCase(p.getSettlementStatus()) || "PENDING".equalsIgnoreCase(p.getSettlementStatus()) || p.getSettlementStatus() == null)
                    .collect(Collectors.toList());
        }

        TrainerProfile profile = trainerProfileRepository.findById(trainer.getId()).orElse(null);
        String trainerType = profile != null && profile.getTrainerType() != null ? profile.getTrainerType() : "PROFESSIONAL";
        double platformRate = "PEER_TUTOR".equalsIgnoreCase(trainerType) ? 0.40 : 0.30;

        int totalOrders = linkedPayments.size();
        BigDecimal grossSum = BigDecimal.ZERO;
        BigDecimal platformSum = BigDecimal.ZERO;
        BigDecimal trainerGrossSum = BigDecimal.ZERO;

        for (Payment p : linkedPayments) {
            BigDecimal gross = p.getAmount() != null ? p.getAmount() : BigDecimal.ZERO;
            BigDecimal pFee = gross.multiply(BigDecimal.valueOf(platformRate)).setScale(2, RoundingMode.HALF_UP);
            BigDecimal tEarn = gross.subtract(pFee);

            grossSum = grossSum.add(gross);
            platformSum = platformSum.add(pFee);
            trainerGrossSum = trainerGrossSum.add(tEarn);

            p.setSettlementStatus("IN_STATEMENT");
            p.setStatementId(statement.getId());
            paymentRepository.save(p);
        }

        BigDecimal pitTax = BigDecimal.ZERO;
        if (trainerGrossSum.compareTo(new BigDecimal("2000000")) >= 0) {
            pitTax = trainerGrossSum.multiply(BigDecimal.valueOf(0.10)).setScale(2, RoundingMode.HALF_UP);
        }
        BigDecimal netPayout = trainerGrossSum.subtract(pitTax);

        statement.setTotalOrders(totalOrders);
        statement.setTotalGrossAmount(grossSum);
        statement.setTotalPlatformFee(platformSum);
        statement.setTotalTrainerGross(trainerGrossSum);
        statement.setPitTaxAmount(pitTax);
        statement.setNetPayoutAmount(netPayout);
        statement.setStatus("PENDING_TRAINER_CONFIRM"); // Reset back to PENDING_TRAINER_CONFIRM

        String auditNote = "\n[System] Recalculated & regenerated by Course Manager at " + LocalDateTime.now().format(DateTimeFormatter.ofPattern("yyyy-MM-dd HH:mm"));
        statement.setAdminNotes(statement.getAdminNotes() != null ? (statement.getAdminNotes() + auditNote) : auditNote);

        MonthlyStatement saved = statementRepository.save(statement);

        if (trainer != null) {
            notificationService.notifyUser(trainer, NotificationService.TYPE_STATEMENT_READY,
                    "Revenue statement recalculated",
                    "Your revenue statement for " + periodMonth + " (Net: "
                            + String.format("%,.0f", netPayout) + " VND) has been recalculated and is ready to review again.",
                    null);
        }

        log.info("Regenerated statement ID={} for period {}. New Status=PENDING_TRAINER_CONFIRM", statementId, periodMonth);
        return mapToDTO(saved);
    }

    @Override
    public List<ManagerPaymentDTO> getStatementPayments(Long statementId) {
        List<Payment> payments = paymentRepository.findByStatementId(statementId);
        return payments.stream().map(p -> {
            String uName = p.getUser() != null ? p.getUser().getFullName() : "N/A";
            String uEmail = p.getUser() != null ? p.getUser().getEmail() : "N/A";
            String cTitle = p.getCourse() != null ? p.getCourse().getTitle() : "N/A";
            String tName = (p.getCourse() != null && p.getCourse().getCreator() != null)
                    ? p.getCourse().getCreator().getFullName() : "N/A";
            Long tId = (p.getCourse() != null && p.getCourse().getCreator() != null)
                    ? p.getCourse().getCreator().getId() : null;

            return ManagerPaymentDTO.builder()
                    .id(p.getId())
                    .txnRef(p.getTxnRef())
                    .learnerId(p.getUser() != null ? p.getUser().getId() : null)
                    .learnerName(uName)
                    .learnerEmail(uEmail)
                    .courseId(p.getCourse() != null ? p.getCourse().getId() : null)
                    .courseTitle(cTitle)
                    .trainerId(tId)
                    .trainerName(tName)
                    .amount(p.getAmount())
                    .platformFee(p.getPlatformFee())
                    .trainerEarnings(p.getTrainerEarnings())
                    .bankCode(p.getBankCode())
                    .vnpayTxnNo(p.getVnpayTxnNo())
                    .status(p.getStatus())
                    .settlementStatus(p.getSettlementStatus())
                    .statementId(p.getStatementId())
                    .paidAt(p.getPaidAt())
                    .createdAt(p.getCreatedAt())
                    .build();
        }).collect(Collectors.toList());
    }


    @Override
    @Transactional(readOnly = true)
    public byte[] exportStatementsToExcel(String periodMonth, String status) {
        List<MonthlyStatementDTO> list = getCourseManagerStatements(periodMonth, status);

        try (org.apache.poi.ss.usermodel.Workbook workbook = new org.apache.poi.xssf.usermodel.XSSFWorkbook();
             java.io.ByteArrayOutputStream out = new java.io.ByteArrayOutputStream()) {

            org.apache.poi.ss.usermodel.Sheet sheet = workbook.createSheet("Monthly Statements");

            org.apache.poi.ss.usermodel.CellStyle headerStyle = workbook.createCellStyle();
            org.apache.poi.ss.usermodel.Font headerFont = workbook.createFont();
            headerFont.setBold(true);
            headerFont.setColor(org.apache.poi.ss.usermodel.IndexedColors.WHITE.getIndex());
            headerStyle.setFont(headerFont);
            headerStyle.setFillForegroundColor(org.apache.poi.ss.usermodel.IndexedColors.TEAL.getIndex());
            headerStyle.setFillPattern(org.apache.poi.ss.usermodel.FillPatternType.SOLID_FOREGROUND);
            headerStyle.setAlignment(org.apache.poi.ss.usermodel.HorizontalAlignment.CENTER);

            String[] columns = {
                    "STT", "Code", "Period", "Trainer Name", "Trainer Email", "Trainer Type",
                    "Bank Name", "Bank Account", "Account Name", "Total Orders",
                    "Gross Amount (VND)", "Platform Fee (VND)", "Trainer Gross (VND)",
                    "PIT Tax 10% (VND)", "Net Payout (VND)", "Status", "Paid At", "Bank Txn Ref"
            };

            org.apache.poi.ss.usermodel.Row headerRow = sheet.createRow(0);
            for (int i = 0; i < columns.length; i++) {
                org.apache.poi.ss.usermodel.Cell cell = headerRow.createCell(i);
                cell.setCellValue(columns[i]);
                cell.setCellStyle(headerStyle);
            }

            int rowIdx = 1;
            for (MonthlyStatementDTO dto : list) {
                org.apache.poi.ss.usermodel.Row row = sheet.createRow(rowIdx++);
                row.createCell(0).setCellValue(rowIdx - 1);
                row.createCell(1).setCellValue(dto.getStatementCode() != null ? dto.getStatementCode() : "");
                row.createCell(2).setCellValue(dto.getPeriodMonth() != null ? dto.getPeriodMonth() : "");
                row.createCell(3).setCellValue(dto.getTrainerName() != null ? dto.getTrainerName() : "");
                row.createCell(4).setCellValue(dto.getTrainerEmail() != null ? dto.getTrainerEmail() : "");
                row.createCell(5).setCellValue(dto.getTrainerType() != null ? dto.getTrainerType() : "");
                row.createCell(6).setCellValue(dto.getBankName() != null ? dto.getBankName() : "");
                row.createCell(7).setCellValue(dto.getBankAccount() != null ? dto.getBankAccount() : "");
                row.createCell(8).setCellValue(dto.getBankAccountName() != null ? dto.getBankAccountName() : "");
                row.createCell(9).setCellValue(dto.getTotalOrders() != null ? dto.getTotalOrders() : 0);
                row.createCell(10).setCellValue(dto.getTotalGrossAmount() != null ? dto.getTotalGrossAmount().doubleValue() : 0);
                row.createCell(11).setCellValue(dto.getTotalPlatformFee() != null ? dto.getTotalPlatformFee().doubleValue() : 0);
                row.createCell(12).setCellValue(dto.getTotalTrainerGross() != null ? dto.getTotalTrainerGross().doubleValue() : 0);
                row.createCell(13).setCellValue(dto.getPitTaxAmount() != null ? dto.getPitTaxAmount().doubleValue() : 0);
                row.createCell(14).setCellValue(dto.getNetPayoutAmount() != null ? dto.getNetPayoutAmount().doubleValue() : 0);
                row.createCell(15).setCellValue(dto.getStatus() != null ? dto.getStatus() : "");
                row.createCell(16).setCellValue(dto.getPaidAt() != null ? dto.getPaidAt().toString() : "");
                row.createCell(17).setCellValue(dto.getBankTxnRef() != null ? dto.getBankTxnRef() : "");
            }

            for (int i = 0; i < columns.length; i++) {
                try {
                    sheet.autoSizeColumn(i);
                } catch (Exception e) {
                    log.warn("Could not auto-size column {}: {}", i, e.getMessage());
                }
            }

            workbook.write(out);
            return out.toByteArray();
        } catch (Exception e) {
            log.error("Error exporting monthly statements to excel", e);
            throw new RuntimeException("Failed to export statements to Excel: " + e.getMessage());
        }
    }

    private MonthlyStatementDTO mapToDTO(MonthlyStatement s) {
        if (s == null) return null;

        User trainer = s.getTrainer();
        Long trainerId = null;
        String trainerName = "N/A";
        String trainerEmail = "";
        TrainerProfile profile = null;

        if (trainer != null) {
            try {
                trainerId = trainer.getId();
                trainerName = trainer.getFullName() != null ? trainer.getFullName() : "N/A";
                trainerEmail = trainer.getEmail() != null ? trainer.getEmail() : "";
                if (trainerId != null) {
                    profile = trainerProfileRepository.findById(trainerId).orElse(null);
                }
            } catch (Exception e) {
                log.warn("Could not load trainer details for statement {}: {}", s.getId(), e.getMessage());
            }
        }

        String tType = profile != null && profile.getTrainerType() != null ? profile.getTrainerType() : "PROFESSIONAL";

        return MonthlyStatementDTO.builder()
                .id(s.getId())
                .statementCode(s.getStatementCode())
                .trainerId(trainerId)
                .trainerName(trainerName)
                .trainerEmail(trainerEmail)
                .trainerType(tType)
                .periodMonth(s.getPeriodMonth())
                .totalOrders(s.getTotalOrders())
                .totalGrossAmount(s.getTotalGrossAmount())
                .totalPlatformFee(s.getTotalPlatformFee())
                .totalTrainerGross(s.getTotalTrainerGross())
                .pitTaxAmount(s.getPitTaxAmount())
                .netPayoutAmount(s.getNetPayoutAmount())
                .bankName(s.getBankName() != null ? s.getBankName() : (profile != null ? profile.getBankName() : ""))
                .bankAccount(s.getBankAccount() != null ? s.getBankAccount() : (profile != null ? profile.getBankAccount() : ""))
                .bankAccountName(s.getBankAccountName() != null ? s.getBankAccountName() : (profile != null ? profile.getBankAccountName() : ""))
                .status(s.getStatus())
                .trainerConfirmedAt(s.getTrainerConfirmedAt())
                .paidAt(s.getPaidAt())
                .bankTxnRef(s.getBankTxnRef())
                .adminNotes(s.getAdminNotes())
                .payoutReceiptUrl(s.getPayoutReceiptUrl())
                .createdAt(s.getCreatedAt())
                .build();
    }
}
