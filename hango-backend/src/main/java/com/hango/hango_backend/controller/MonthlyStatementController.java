package com.hango.hango_backend.controller;

import com.hango.hango_backend.dto.MonthlyStatementDTO;
import com.hango.hango_backend.dto.TrainerRevenueSummaryDTO;
import com.hango.hango_backend.security.UserDetailsImpl;
import com.hango.hango_backend.service.MonthlyStatementService;
import lombok.Data;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@Slf4j
@RestController
@RequestMapping("/api/v1")
@RequiredArgsConstructor
public class MonthlyStatementController {

    private final MonthlyStatementService statementService;

    // --- Trainer Endpoints ---

    @GetMapping("/trainer/revenue-summary")
    @PreAuthorize("hasAuthority('VIEW_OWN_REVENUE') or hasAuthority('VIEW_PLATFORM_DASHBOARD')")
    public ResponseEntity<TrainerRevenueSummaryDTO> getTrainerRevenueSummary(
            @AuthenticationPrincipal UserDetailsImpl currentUser) {
        TrainerRevenueSummaryDTO summary = statementService.getTrainerRevenueSummary(currentUser.getId());
        return ResponseEntity.ok(summary);
    }

    @GetMapping("/trainer/statements")
    @PreAuthorize("hasAuthority('VIEW_OWN_REVENUE') or hasAuthority('VIEW_PLATFORM_DASHBOARD')")
    public ResponseEntity<List<MonthlyStatementDTO>> getTrainerStatements(
            @AuthenticationPrincipal UserDetailsImpl currentUser) {
        List<MonthlyStatementDTO> statements = statementService.getTrainerStatements(currentUser.getId());
        return ResponseEntity.ok(statements);
    }

    @PostMapping("/trainer/statements/{id}/confirm")
    @PreAuthorize("hasAuthority('VIEW_OWN_REVENUE') or hasAuthority('VIEW_PLATFORM_DASHBOARD')")
    public ResponseEntity<MonthlyStatementDTO> confirmTrainerStatement(
            @PathVariable("id") Long id,
            @AuthenticationPrincipal UserDetailsImpl currentUser) {
        MonthlyStatementDTO updated = statementService.confirmTrainerStatement(id, currentUser.getId());
        return ResponseEntity.ok(updated);
    }

    @PostMapping("/trainer/statements/{id}/reject")
    @PreAuthorize("hasAuthority('VIEW_OWN_REVENUE') or hasAuthority('VIEW_PLATFORM_DASHBOARD')")
    public ResponseEntity<MonthlyStatementDTO> rejectTrainerStatement(
            @PathVariable("id") Long id,
            @RequestBody(required = false) RejectRequestDTO request,
            @AuthenticationPrincipal UserDetailsImpl currentUser) {
        String reason = request != null ? request.getReason() : null;
        MonthlyStatementDTO updated = statementService.rejectTrainerStatement(id, currentUser.getId(), reason);
        return ResponseEntity.ok(updated);
    }

    // --- Course Manager / Admin Endpoints ---

    @GetMapping("/course-manager/statements")
    @PreAuthorize("hasAnyAuthority('VIEW_PLATFORM_DASHBOARD', 'MANAGE_ACCOUNTS_ROLES', 'COURSE_MANAGER', 'ROLE_COURSE_MANAGER', 'ADMINISTRATOR', 'ROLE_ADMINISTRATOR')")
    public ResponseEntity<List<MonthlyStatementDTO>> getCourseManagerStatements(
            @RequestParam(name = "periodMonth", required = false) String periodMonth,
            @RequestParam(name = "status", required = false) String status) {
        List<MonthlyStatementDTO> list = statementService.getCourseManagerStatements(periodMonth, status);
        return ResponseEntity.ok(list);
    }

    @PostMapping("/course-manager/statements/generate")
    @PreAuthorize("hasAnyAuthority('VIEW_PLATFORM_DASHBOARD', 'MANAGE_ACCOUNTS_ROLES', 'COURSE_MANAGER', 'ROLE_COURSE_MANAGER', 'ADMINISTRATOR', 'ROLE_ADMINISTRATOR')")
    public ResponseEntity<List<MonthlyStatementDTO>> generateMonthlyCutoff(
            @RequestParam(name = "periodMonth", required = false) String periodMonth) {
        List<MonthlyStatementDTO> generated = statementService.generateMonthlyCutoff(periodMonth);
        return ResponseEntity.ok(generated);
    }

    @PostMapping("/course-manager/statements/{id}/settle")
    @PreAuthorize("hasAnyAuthority('VIEW_PLATFORM_DASHBOARD', 'MANAGE_ACCOUNTS_ROLES', 'COURSE_MANAGER', 'ROLE_COURSE_MANAGER', 'ADMINISTRATOR', 'ROLE_ADMINISTRATOR')")
    public ResponseEntity<MonthlyStatementDTO> settleStatement(
            @PathVariable("id") Long id,
            @RequestBody SettleRequestDTO request) {
        String bankTxnRef = request != null ? request.getBankTxnRef() : null;
        String notes = request != null ? request.getNotes() : null;
        String payoutReceiptUrl = request != null ? request.getPayoutReceiptUrl() : null;
        MonthlyStatementDTO settled = statementService.settleStatement(id, bankTxnRef, notes, payoutReceiptUrl);
        return ResponseEntity.ok(settled);
    }

    @PostMapping("/course-manager/statements/{id}/cancel")
    @PreAuthorize("hasAnyAuthority('VIEW_PLATFORM_DASHBOARD', 'MANAGE_ACCOUNTS_ROLES', 'COURSE_MANAGER', 'ROLE_COURSE_MANAGER', 'ADMINISTRATOR', 'ROLE_ADMINISTRATOR')")
    public ResponseEntity<MonthlyStatementDTO> cancelStatement(
            @PathVariable("id") Long id) {
        MonthlyStatementDTO cancelled = statementService.cancelStatement(id);
        return ResponseEntity.ok(cancelled);
    }

    @PostMapping("/course-manager/statements/{id}/regenerate")
    @PreAuthorize("hasAnyAuthority('VIEW_PLATFORM_DASHBOARD', 'MANAGE_ACCOUNTS_ROLES', 'COURSE_MANAGER', 'ROLE_COURSE_MANAGER', 'ADMINISTRATOR', 'ROLE_ADMINISTRATOR')")
    public ResponseEntity<MonthlyStatementDTO> regenerateStatement(
            @PathVariable("id") Long id) {
        MonthlyStatementDTO regenerated = statementService.regenerateStatement(id);
        return ResponseEntity.ok(regenerated);
    }

    @GetMapping("/course-manager/statements/{id}/items")
    @PreAuthorize("hasAnyAuthority('VIEW_OWN_REVENUE', 'COURSE_MANAGER', 'ADMINISTRATOR', 'ROLE_COURSE_MANAGER', 'ROLE_ADMINISTRATOR', 'TRAINER', 'ROLE_TRAINER', 'TEACHER', 'ROLE_TEACHER', 'INSTRUCTOR', 'ROLE_INSTRUCTOR', 'PEER_TUTOR', 'ROLE_PEER_TUTOR')")
    public ResponseEntity<List<com.hango.hango_backend.dto.ManagerPaymentDTO>> getStatementPayments(
            @PathVariable("id") Long id) {
        List<com.hango.hango_backend.dto.ManagerPaymentDTO> items = statementService.getStatementPayments(id);
        return ResponseEntity.ok(items);
    }

    @GetMapping("/course-manager/statements/export-excel")
    @PreAuthorize("hasAnyAuthority('COURSE_MANAGER', 'ADMINISTRATOR', 'ROLE_COURSE_MANAGER', 'ROLE_ADMINISTRATOR', 'VIEW_PLATFORM_DASHBOARD')")
    public ResponseEntity<byte[]> exportStatementsToExcel(
            @RequestParam(name = "periodMonth", required = false) String periodMonth,
            @RequestParam(name = "status", required = false) String status) {
        byte[] excelBytes = statementService.exportStatementsToExcel(periodMonth, status);
        String filename = "HanGo_Revenue_Settlement_" + (periodMonth != null && !periodMonth.isEmpty() ? periodMonth : "All") + ".xlsx";
        return ResponseEntity.ok()
                .header(org.springframework.http.HttpHeaders.CONTENT_DISPOSITION, "attachment; filename=\"" + filename + "\"")
                .header(org.springframework.http.HttpHeaders.CONTENT_TYPE, "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet")
                .body(excelBytes);
    }

    @Data
    public static class SettleRequestDTO {
        private String bankTxnRef;
        private String notes;
        private String payoutReceiptUrl;
    }

    @Data
    public static class RejectRequestDTO {
        private String reason;
    }
}

