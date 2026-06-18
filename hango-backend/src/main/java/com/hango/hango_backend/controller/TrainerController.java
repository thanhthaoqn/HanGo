package com.hango.hango_backend.controller;

import com.hango.hango_backend.dto.TrainerDashboardDTO;
import com.hango.hango_backend.service.TrainerService;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Pageable;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.validation.annotation.Validated;
import org.springframework.web.bind.annotation.*;

@CrossOrigin(origins = "*", maxAge = 3600)
@RestController
@RequestMapping("/api/v1/trainer")
@Validated
public class TrainerController {

    @Autowired
    private TrainerService trainerService;

    @GetMapping("/dashboard")
    @PreAuthorize("hasRole('TRAINER') or hasRole('TRAINING_LEAD') or hasRole('ADMINISTRATOR')")
    public ResponseEntity<TrainerDashboardDTO> getTrainerDashboard(
            @AuthenticationPrincipal UserDetails userDetails,
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "6") int size) {
        
        Pageable pageable = PageRequest.of(page, size);
        TrainerDashboardDTO data = trainerService.getTrainerDashboard(userDetails.getUsername(), pageable);
        return ResponseEntity.ok(data);
    }
}
