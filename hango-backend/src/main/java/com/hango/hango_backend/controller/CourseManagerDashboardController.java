package com.hango.hango_backend.controller;

import com.hango.hango_backend.dto.CourseManagerDashboardSummaryDTO;
import com.hango.hango_backend.service.CourseManagerDashboardService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.CrossOrigin;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@CrossOrigin(origins = "*", maxAge = 3600)
@RestController
@RequestMapping("/api/v1/course-manager")
@RequiredArgsConstructor
public class CourseManagerDashboardController {

    private final CourseManagerDashboardService courseManagerDashboardService;

    @GetMapping("/dashboard")
    @PreAuthorize("hasAnyRole('TRAINER_LEAD', 'COURSE_MANAGER', 'ADMINISTRATOR')")
    public ResponseEntity<?> getDashboardSummary() {
        try {
            CourseManagerDashboardSummaryDTO summary = courseManagerDashboardService.getDashboardSummary();
            return ResponseEntity.ok(summary);
        } catch (Exception e) {
            e.printStackTrace();
            return ResponseEntity.badRequest().body("{\"error\": \"" + e.getMessage() + "\"}");
        }
    }
}
