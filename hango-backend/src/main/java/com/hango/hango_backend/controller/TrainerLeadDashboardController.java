package com.hango.hango_backend.controller;

import com.hango.hango_backend.dto.TrainerLeadDashboardStatsDto;
import com.hango.hango_backend.service.TrainerLeadDashboardService;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/v1/trainer-lead/dashboard")
public class TrainerLeadDashboardController {

    @Autowired
    private TrainerLeadDashboardService trainerLeadDashboardService;

    @GetMapping("/stats")
    // Use @PreAuthorize if you have roles set up, e.g. @PreAuthorize("hasAuthority('ROLE_TRAINER_LEAD')")
    // For now we will rely on SecurityConfig for simplicity or leave it open if configured so
    public ResponseEntity<TrainerLeadDashboardStatsDto> getDashboardStats() {
        TrainerLeadDashboardStatsDto stats = trainerLeadDashboardService.getDashboardStats();
        return ResponseEntity.ok(stats);
    }
}
