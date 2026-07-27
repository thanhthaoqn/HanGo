package com.hango.hango_backend.service;

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

        List<Payment> payments = paymentRepository.findByCourseCreatorIdAndStatus(trainerId, "SUCCESS");

        LocalDateTime holdThreshold = LocalDateTime.now().minusDays(7);
        BigDecimal pendingHold = BigDecimal.ZERO;
        BigDecimal available = BigDecimal.ZERO;

        for (Payment p : payments) {
            BigDecimal earnings = p.getTrainerEarnings();
            if (earnings == null) {
                // Default calculation if old record
                double platformRate = "PEER_TUTOR".equalsIgnoreCase(trainerType) ? 0.40 : 0.30;
                BigDecimal gross = p.getAmount() != null ? p.getAmount() : BigDecimal.ZERO;
                BigDecimal pFee = gross.multiply(BigDecimal.valueOf(platformRate)).setScale(2, RoundingMode.HALF_UP);
                earnings = gross.subtract(pFee);
            }

            if ("PENDING".equalsIgnoreCase(p.getSettlementStatus()) || p.getSettlementStatus() == null) {
                if (p.getCreatedAt() != null && p.getCreatedAt().isAfter(holdThreshold)) {
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
    @Transactional(readOnly = true)
    public List<MonthlyStatementDTO> getCourseManagerStatements(String periodMonth, String status) {
        List<MonthlyStatement> list;
        if (periodMonth != null && !periodMonth.isEmpty() && status != null && !status.isEmpty()) {
            list = statementRepository.findByPeriodMonthAndStatus(periodMonth, status);
        } else if (periodMonth != null && !periodMonth.isEmpty()) {
            list = statementRepository.findByPeriodMonth(periodMonth);
        } else {
            list = statementRepository.findAll();
        }
        return list.stream().map(this::mapToDTO).collect(Collectors.toList());
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

            BigDecimal pitTax = trainerGrossSum.multiply(BigDecimal.valueOf(0.10)).setScale(2, RoundingMode.HALF_UP);
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
        MonthlyStatement statement = statementRepository.findById(statementId)
                .orElseThrow(() -> new RuntimeException("Statement not found with ID: " + statementId));

        statement.setStatus("PAID");
        statement.setPaidAt(LocalDateTime.now());
        statement.setBankTxnRef(bankTxnRef);
        if (notes != null && !notes.trim().isEmpty()) {
            statement.setAdminNotes(notes);
        }

        MonthlyStatement saved = statementRepository.save(statement);

        // Send email notification to Trainer
        try {
            if (statement.getTrainer() != null && statement.getTrainer().getEmail() != null) {
                emailService.sendTrainerStatusNotificationEmail(
                        statement.getTrainer().getEmail(),
                        "SETTLEMENT_PAID",
                        "Your monthly revenue payout for period " + statement.getPeriodMonth() +
                                " (Net Payout: " + String.format("%,.0f", statement.getNetPayoutAmount()) + " VND) has been successfully transferred." +
                                (bankTxnRef != null ? " Bank Txn Ref: " + bankTxnRef : "")
                );
            }
        } catch (Exception e) {
            log.warn("Could not send email for statement settlement: {}", e.getMessage());
        }

        return mapToDTO(saved);
    }

    private MonthlyStatementDTO mapToDTO(MonthlyStatement s) {
        TrainerProfile profile = trainerProfileRepository.findById(s.getTrainer().getId()).orElse(null);
        String tType = profile != null && profile.getTrainerType() != null ? profile.getTrainerType() : "PROFESSIONAL";

        return MonthlyStatementDTO.builder()
                .id(s.getId())
                .statementCode(s.getStatementCode())
                .trainerId(s.getTrainer().getId())
                .trainerName(s.getTrainer().getFullName())
                .trainerEmail(s.getTrainer().getEmail())
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
                .createdAt(s.getCreatedAt())
                .build();
    }
}
