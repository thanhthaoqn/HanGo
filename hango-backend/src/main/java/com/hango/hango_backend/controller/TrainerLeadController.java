package com.hango.hango_backend.controller;

import com.hango.hango_backend.repository.CourseRepository;
import com.hango.hango_backend.repository.UserRepository;
import com.hango.hango_backend.dto.TrainerLeadDashboardResponse;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

@CrossOrigin(origins = "*", maxAge = 3600)
@RestController
@RequestMapping("/api/v1/trainer-lead")
public class TrainerLeadController {

    @Autowired
    private UserRepository userRepository;

    @Autowired
    private CourseRepository courseRepository;

    @GetMapping("/dashboard/stats")
    @PreAuthorize("hasAnyRole('TRAINER_LEAD', 'ADMINISTRATOR')")
    public ResponseEntity<?> getDashboardStats() {
        try {
            long totalUsers = userRepository.count();
            long totalCourses = courseRepository.count();
            
            // Counting active courses (ACTIVE or PUBLISHED)
            long activeCourses = courseRepository.countByStatus("ACTIVE") + courseRepository.countByStatus("PUBLISHED");
            
            // Inactive courses are DRAFT, INACTIVE, or DELETED
            long inactiveCourses = courseRepository.countByStatus("DRAFT") + courseRepository.countByStatus("INACTIVE") + courseRepository.countByStatus("DELETED");

            // Mock Data for Task Management as FT-12 is not fully implemented
            long assignedTasks = 10;
            long pendingApprovals = 2;
            double percentageIncrease = 12.5;

            TrainerLeadDashboardResponse response = TrainerLeadDashboardResponse.builder()
                    .totalUsers(totalUsers)
                    .percentageIncrease(percentageIncrease)
                    .totalCourses(totalCourses)
                    .activeCourses(activeCourses)
                    .inactiveCourses(inactiveCourses)
                    .assignedTasks(assignedTasks)
                    .pendingApprovals(pendingApprovals)
                    .build();

            return ResponseEntity.ok(response);
        } catch (Exception e) {
            return ResponseEntity.badRequest().body("Error: " + e.getMessage());
        }
    }
}
