package com.hango.hango_backend.controller;

import com.hango.hango_backend.dto.CourseManagerDashboardSummaryDTO;
import com.hango.hango_backend.entity.Notification;
import com.hango.hango_backend.repository.NotificationRepository;
import com.hango.hango_backend.service.CourseManagerDashboardService;
import com.hango.hango_backend.service.NotificationService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.CrossOrigin;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.time.format.DateTimeFormatter;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.stream.Collectors;

@CrossOrigin(origins = "*", maxAge = 3600)
@RestController
@RequestMapping("/api/v1/course-manager")
@RequiredArgsConstructor
public class CourseManagerDashboardController {

    private final CourseManagerDashboardService courseManagerDashboardService;
    private final NotificationRepository notificationRepository;

    @GetMapping("/dashboard")
    @PreAuthorize("hasRole('TRAINER_LEAD')")
    public ResponseEntity<?> getDashboardSummary() {
        try {
            CourseManagerDashboardSummaryDTO summary = courseManagerDashboardService.getDashboardSummary();
            return ResponseEntity.ok(summary);
        } catch (Exception e) {
            e.printStackTrace();
            return ResponseEntity.badRequest().body("{\"error\": \"" + e.getMessage() + "\"}");
        }
    }

    @GetMapping("/notifications")
    @PreAuthorize("hasRole('TRAINER_LEAD')")
    public ResponseEntity<?> getNotifications() {
        DateTimeFormatter formatter = DateTimeFormatter.ofPattern("dd/MM/yyyy HH:mm");
        List<Notification> notifications = notificationRepository
                .findByRecipientRoleOrderByCreatedAtDesc(NotificationService.RECIPIENT_COURSE_MANAGER);

        List<Map<String, Object>> response = notifications.stream().map(n -> {
            Map<String, Object> map = new HashMap<>();
            map.put("id", n.getId());
            map.put("type", n.getType());
            map.put("title", n.getTitle());
            map.put("message", n.getMessage());
            map.put("courseId", n.getCourse() != null ? n.getCourse().getId() : null);
            map.put("courseTitle", n.getCourse() != null ? n.getCourse().getTitle() : null);
            map.put("read", n.isRead());
            map.put("createdAt", n.getCreatedAt() != null ? n.getCreatedAt().format(formatter) : "");
            return map;
        }).collect(Collectors.toList());

        return ResponseEntity.ok(response);
    }

    @PutMapping("/notifications/{id}/read")
    @PreAuthorize("hasRole('TRAINER_LEAD')")
    public ResponseEntity<?> markNotificationAsRead(@PathVariable Long id) {
        Optional<Notification> notificationOpt = notificationRepository.findById(id);
        if (notificationOpt.isEmpty()) {
            return ResponseEntity.status(404).body("Notification not found");
        }
        Notification notification = notificationOpt.get();
        notification.setRead(true);
        notificationRepository.save(notification);
        return ResponseEntity.ok(Map.of("success", true));
    }
}
