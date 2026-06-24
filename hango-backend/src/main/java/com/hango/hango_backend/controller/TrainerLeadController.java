package com.hango.hango_backend.controller;

import com.hango.hango_backend.repository.CourseRepository;
import com.hango.hango_backend.repository.UserRepository;
import com.hango.hango_backend.repository.TaskRepository;
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

    @Autowired
    private TaskRepository taskRepository;

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

            // Data for Task Management
            long assignedTasks = taskRepository.count();
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

    @GetMapping("/trainers")
    @PreAuthorize("hasAnyRole('TRAINER_LEAD', 'ADMINISTRATOR')")
    public ResponseEntity<?> getTrainers() {
        try {
            java.util.List<com.hango.hango_backend.entity.User> allUsers = userRepository.findAll();
            java.util.List<java.util.Map<String, Object>> trainers = allUsers.stream()
                .filter(u -> u.getRoles().stream().anyMatch(r -> r.getRoleName().equals("TRAINER") || r.getRoleName().equals("TRAINER_LEAD")))
                .map(u -> {
                    java.util.Map<String, Object> map = new java.util.HashMap<>();
                    map.put("id", u.getId());
                    map.put("fullName", u.getFullName());
                    map.put("roles", u.getRoles().stream().map(r -> r.getRoleName()).toList());
                    return map;
                })
                .toList();
            return ResponseEntity.ok(trainers);
        } catch (Exception e) {
            return ResponseEntity.badRequest().body("Error: " + e.getMessage());
        }
    }
}
