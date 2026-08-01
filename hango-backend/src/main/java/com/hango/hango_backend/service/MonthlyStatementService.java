package com.hango.hango_backend.service;

import com.hango.hango_backend.dto.ManagerPaymentDTO;
import com.hango.hango_backend.dto.MonthlyStatementDTO;
import com.hango.hango_backend.dto.TrainerRevenueSummaryDTO;


import java.util.List;

public interface MonthlyStatementService {
    TrainerRevenueSummaryDTO getTrainerRevenueSummary(Long trainerId);
    List<MonthlyStatementDTO> getTrainerStatements(Long trainerId);
    MonthlyStatementDTO confirmTrainerStatement(Long statementId, Long trainerId);
    
    // Course Manager & Admin APIs
    List<MonthlyStatementDTO> getCourseManagerStatements(String periodMonth, String status);
    List<MonthlyStatementDTO> generateMonthlyCutoff(String periodMonth);
    MonthlyStatementDTO settleStatement(Long statementId, String bankTxnRef, String notes);
    MonthlyStatementDTO settleStatement(Long statementId, String bankTxnRef, String notes, String payoutReceiptUrl);
    List<ManagerPaymentDTO> getStatementPayments(Long statementId);
    byte[] exportStatementsToExcel(String periodMonth, String status);
}


