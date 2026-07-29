package com.hango.hango_backend.controller;

import com.hango.hango_backend.dto.CourseManagerDashboardSummaryDTO;
import com.hango.hango_backend.dto.CourseReviewDetailDTO;
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
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
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
    @PreAuthorize("hasAnyRole('COURSE_MANAGER', 'COURSE_MANAGER', 'ADMINISTRATOR')")
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
    @PreAuthorize("hasRole('COURSE_MANAGER')")
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
    @PreAuthorize("hasRole('COURSE_MANAGER')")
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

    @GetMapping("/courses/review")
    @PreAuthorize("hasAnyRole('COURSE_MANAGER', 'COURSE_MANAGER', 'ADMINISTRATOR')")
    public ResponseEntity<?> getCoursesForReview(@RequestParam(defaultValue = "PENDING") String status) {
        try {
            List<CourseReviewDetailDTO> courses = courseManagerDashboardService.getCoursesForReview(status);
            return ResponseEntity.ok(courses);
        } catch (Exception e) {
            e.printStackTrace();
            return ResponseEntity.badRequest().body("{\"error\": \"" + e.getMessage() + "\"}");
        }
    }

    @GetMapping("/courses/{id}/review-detail")
    @PreAuthorize("hasAnyRole('COURSE_MANAGER', 'COURSE_MANAGER', 'ADMINISTRATOR')")
    public ResponseEntity<?> getCourseReviewDetail(@PathVariable Long id) {
        try {
            return ResponseEntity.ok(courseManagerDashboardService.getCourseReviewDetail(id));
        } catch (Exception e) {
            e.printStackTrace();
            return ResponseEntity.badRequest().body("{\"error\": \"" + e.getMessage() + "\"}");
        }
    }

    @PostMapping("/courses/{id}/publish")
    @PreAuthorize("hasAnyRole('COURSE_MANAGER', 'COURSE_MANAGER', 'ADMINISTRATOR')")
    public ResponseEntity<?> publishCourse(@PathVariable Long id) {
        try {
            courseManagerDashboardService.publishCourse(id);
            return ResponseEntity.ok("{\"message\": \"Course published successfully\"}");
        } catch (Exception e) {
            e.printStackTrace();
            return ResponseEntity.badRequest().body("{\"error\": \"" + e.getMessage() + "\"}");
        }
    }

    @PostMapping("/courses/{id}/reject")
    @PreAuthorize("hasAnyRole('COURSE_MANAGER', 'COURSE_MANAGER', 'ADMINISTRATOR')")
    public ResponseEntity<?> rejectCourse(@PathVariable Long id, @org.springframework.web.bind.annotation.RequestBody(required = false) java.util.Map<String, String> body) {
        try {
            // Reason could be used later: String reason = body != null ? body.get("reason") : null;
            courseManagerDashboardService.returnCourseToDraft(id);
            return ResponseEntity.ok("{\"message\": \"Course returned to draft\"}");
        } catch (Exception e) {
            e.printStackTrace();
            return ResponseEntity.badRequest().body("{\"error\": \"" + e.getMessage() + "\"}");
        }
    }

    @PostMapping("/courses/{id}/hide")
    @PreAuthorize("hasAnyRole('COURSE_MANAGER', 'COURSE_MANAGER', 'ADMINISTRATOR')")
    public ResponseEntity<?> hideCourse(@PathVariable Long id) {
        try {
            courseManagerDashboardService.hideCourse(id);
            return ResponseEntity.ok("{\"message\": \"Course hidden successfully\"}");
        } catch (Exception e) {
            e.printStackTrace();
            return ResponseEntity.badRequest().body("{\"error\": \"" + e.getMessage() + "\"}");
        }
    }

    @PostMapping("/courses/{id}/unhide")
    @PreAuthorize("hasAnyRole('COURSE_MANAGER', 'COURSE_MANAGER', 'ADMINISTRATOR')")
    public ResponseEntity<?> unhideCourse(@PathVariable Long id) {
        try {
            courseManagerDashboardService.unhideCourse(id);
            return ResponseEntity.ok("{\"message\": \"Course unhidden successfully\"}");
        } catch (Exception e) {
            e.printStackTrace();
            return ResponseEntity.badRequest().body("{\"error\": \"" + e.getMessage() + "\"}");
        }
    }

    @GetMapping("/exams/review")
    @PreAuthorize("hasAnyRole('COURSE_MANAGER', 'COURSE_MANAGER', 'ADMINISTRATOR')")
    public ResponseEntity<?> getExamsForReview(@RequestParam(defaultValue = "PENDING_APPROVAL") String status) {
        try {
            List<com.hango.hango_backend.dto.ExamResponseDTO> exams = courseManagerDashboardService.getExamsForReview(status);
            return ResponseEntity.ok(exams);
        } catch (Exception e) {
            e.printStackTrace();
            return ResponseEntity.badRequest().body("{\"error\": \"" + e.getMessage() + "\"}");
        }
    }

    @PostMapping("/exams/{id}/publish")
    @PreAuthorize("hasAnyRole('COURSE_MANAGER', 'COURSE_MANAGER', 'ADMINISTRATOR')")
    public ResponseEntity<?> publishExam(@PathVariable Long id) {
        try {
            courseManagerDashboardService.publishExam(id);
            return ResponseEntity.ok("{\"message\": \"Exam published successfully\"}");
        } catch (Exception e) {
            e.printStackTrace();
            return ResponseEntity.badRequest().body("{\"error\": \"" + e.getMessage() + "\"}");
        }
    }

    @PostMapping("/exams/{id}/reject")
    @PreAuthorize("hasAnyRole('COURSE_MANAGER', 'COURSE_MANAGER', 'ADMINISTRATOR')")
    public ResponseEntity<?> rejectExam(@PathVariable Long id, @org.springframework.web.bind.annotation.RequestBody(required = false) java.util.Map<String, String> body) {
        try {
            String reason = body != null ? body.get("reason") : null;
            if (reason == null || reason.trim().isEmpty()) {
                return ResponseEntity.badRequest().body("{\"error\": \"Rejection reason is required\"}");
            }
            courseManagerDashboardService.returnExamToDraft(id, reason);
            return ResponseEntity.ok("{\"message\": \"Exam returned to draft\"}");
        } catch (Exception e) {
            e.printStackTrace();
            return ResponseEntity.badRequest().body("{\"error\": \"" + e.getMessage() + "\"}");
        }
    }
}
