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

    // --- Course Manager / Admin Endpoints ---

    @GetMapping("/course-manager/statements")
    @PreAuthorize("hasAuthority('VIEW_PLATFORM_DASHBOARD') or hasAuthority('MANAGE_ACCOUNTS_ROLES') or hasRole('ADMINISTRATOR')")
    public ResponseEntity<List<MonthlyStatementDTO>> getCourseManagerStatements(
            @RequestParam(name = "periodMonth", required = false) String periodMonth,
            @RequestParam(name = "status", required = false) String status) {
        List<MonthlyStatementDTO> list = statementService.getCourseManagerStatements(periodMonth, status);
        return ResponseEntity.ok(list);
    }

    @PostMapping("/course-manager/statements/generate")
    @PreAuthorize("hasAuthority('VIEW_PLATFORM_DASHBOARD') or hasAuthority('MANAGE_ACCOUNTS_ROLES') or hasRole('ADMINISTRATOR')")
    public ResponseEntity<List<MonthlyStatementDTO>> generateMonthlyCutoff(
            @RequestParam(name = "periodMonth", required = false) String periodMonth) {
        List<MonthlyStatementDTO> generated = statementService.generateMonthlyCutoff(periodMonth);
        return ResponseEntity.ok(generated);
    }

    @PostMapping("/course-manager/statements/{id}/settle")
    @PreAuthorize("hasAuthority('VIEW_PLATFORM_DASHBOARD') or hasAuthority('MANAGE_ACCOUNTS_ROLES') or hasRole('ADMINISTRATOR')")
    public ResponseEntity<MonthlyStatementDTO> settleStatement(
            @PathVariable("id") Long id,
            @RequestBody SettleRequestDTO request) {
        String bankTxnRef = request != null ? request.getBankTxnRef() : null;
        String notes = request != null ? request.getNotes() : null;
        MonthlyStatementDTO settled = statementService.settleStatement(id, bankTxnRef, notes);
        return ResponseEntity.ok(settled);
    }

    @Data
    public static class SettleRequestDTO {
        private String bankTxnRef;
        private String notes;
    }
}
