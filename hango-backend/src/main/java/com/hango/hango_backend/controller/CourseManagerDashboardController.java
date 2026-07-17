package com.hango.hango_backend.controller;

import com.hango.hango_backend.dto.CourseManagerDashboardSummaryDTO;
import com.hango.hango_backend.dto.CourseReviewDetailDTO;
import com.hango.hango_backend.service.CourseManagerDashboardService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.CrossOrigin;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;

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

    @GetMapping("/courses/review")
    @PreAuthorize("hasAnyRole('TRAINER_LEAD', 'COURSE_MANAGER', 'ADMINISTRATOR')")
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
    @PreAuthorize("hasAnyRole('TRAINER_LEAD', 'COURSE_MANAGER', 'ADMINISTRATOR')")
    public ResponseEntity<?> getCourseReviewDetail(@PathVariable Long id) {
        try {
            return ResponseEntity.ok(courseManagerDashboardService.getCourseReviewDetail(id));
        } catch (Exception e) {
            e.printStackTrace();
            return ResponseEntity.badRequest().body("{\"error\": \"" + e.getMessage() + "\"}");
        }
    }

    @PostMapping("/courses/{id}/publish")
    @PreAuthorize("hasAnyRole('TRAINER_LEAD', 'COURSE_MANAGER', 'ADMINISTRATOR')")
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
    @PreAuthorize("hasAnyRole('TRAINER_LEAD', 'COURSE_MANAGER', 'ADMINISTRATOR')")
    public ResponseEntity<?> rejectCourse(@PathVariable Long id) {
        try {
            courseManagerDashboardService.returnCourseToDraft(id);
            return ResponseEntity.ok("{\"message\": \"Course returned to draft\"}");
        } catch (Exception e) {
            e.printStackTrace();
            return ResponseEntity.badRequest().body("{\"error\": \"" + e.getMessage() + "\"}");
        }
    }
}
