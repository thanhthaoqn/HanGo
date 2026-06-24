package com.hango.hango_backend.controller;

import com.hango.hango_backend.dto.CourseSummaryDTO;
import com.hango.hango_backend.dto.CourseReviewRequestDTO;
import com.hango.hango_backend.service.CourseRatingService;
import com.hango.hango_backend.service.CourseService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api/v1/courses")
@RequiredArgsConstructor
public class CourseController {

    private final CourseService courseService;
    private final CourseRatingService courseRatingService;

    @GetMapping
    public ResponseEntity<List<CourseSummaryDTO>> getCourses(
            @RequestParam(required = false) String search,
            @RequestParam(required = false, defaultValue = "ALL") String filterType,
            @RequestParam(required = false, defaultValue = "ALL") String difficulty) {
        
        List<CourseSummaryDTO> courses = courseService.getCourses(search, filterType, difficulty);
        return ResponseEntity.ok(courses);
    }

    private Long getCurrentUserId() {
        org.springframework.security.core.Authentication auth = org.springframework.security.core.context.SecurityContextHolder.getContext().getAuthentication();
        if (auth != null && auth.getPrincipal() instanceof com.hango.hango_backend.sercurity.UserDetailsImpl) {
            return ((com.hango.hango_backend.sercurity.UserDetailsImpl) auth.getPrincipal()).getId();
        }
        return null;
    }

    @GetMapping("/{id}")
    public ResponseEntity<?> getCourseDetail(@PathVariable Long id) {
        try {
            Long currentUserId = getCurrentUserId();
            return ResponseEntity.ok(courseService.getCourseDetail(id, currentUserId));
        } catch (RuntimeException e) {
            e.printStackTrace();
            return ResponseEntity.status(404).body(e.getClass().getName() + ": " + e.getMessage());
        }
    }

    @PostMapping("/{id}/enroll")
    public ResponseEntity<?> enrollCourse(@PathVariable Long id) {
        try {
            Long currentUserId = getCurrentUserId();
            if (currentUserId == null) {
                return ResponseEntity.status(401).body("{\"error\": \"Unauthorized\"}");
            }
            courseService.enrollCourse(id, currentUserId);
            return ResponseEntity.ok().body("{\"message\": \"Enrollment successful\"}");
        } catch (RuntimeException e) {
            e.printStackTrace();
            return ResponseEntity.status(400).body("{\"error\": \"" + e.getMessage() + "\"}");
        }
    }

    @DeleteMapping("/{id}/enroll")
    public ResponseEntity<?> unenrollCourse(@PathVariable Long id) {
        try {
            Long currentUserId = getCurrentUserId();
            if (currentUserId == null) {
                return ResponseEntity.status(401).body("{\"error\": \"Unauthorized\"}");
            }
            courseService.unenrollCourse(id, currentUserId);
            return ResponseEntity.ok().body("{\"message\": \"Unenrollment successful\"}");
        } catch (RuntimeException e) {
            e.printStackTrace();
            return ResponseEntity.status(400).body("{\"error\": \"" + e.getMessage() + "\"}");
        }
    }

    @GetMapping("/{id}/reviews")
    public ResponseEntity<?> getCourseReviews(@PathVariable Long id) {
        try {
            return ResponseEntity.ok(courseRatingService.getCourseReviews(id));
        } catch (RuntimeException e) {
            e.printStackTrace();
            return ResponseEntity.status(404).body(e.getClass().getName() + ": " + e.getMessage());
        }
    }

    @PostMapping("/{id}/reviews")
    public ResponseEntity<?> addCourseReview(@PathVariable Long id,
                                             @RequestBody @jakarta.validation.Valid CourseReviewRequestDTO request) {
        try {
            Long currentUserId = getCurrentUserId();
            if (currentUserId == null) {
                return ResponseEntity.status(401).body("{\"error\": \"Unauthorized\"}");
            }
            courseRatingService.addCourseReview(id, currentUserId, request.getRating(), request.getContent());
            return ResponseEntity.ok().body("{\"message\": \"Review posted successfully\"}");
        } catch (RuntimeException e) {
            e.printStackTrace();
            return ResponseEntity.status(400).body("{\"error\": \"" + e.getMessage() + "\"}");
        }
    }

    @DeleteMapping("/{id}/reviews")
    public ResponseEntity<?> deleteCourseReview(@PathVariable Long id) {
        try {
            Long currentUserId = getCurrentUserId();
            if (currentUserId == null) {
                return ResponseEntity.status(401).body("{\"error\": \"Unauthorized\"}");
            }
            courseRatingService.deleteCourseReview(id, currentUserId);
            return ResponseEntity.ok().body("{\"message\": \"Review deleted successfully\"}");
        } catch (RuntimeException e) {
            e.printStackTrace();
            return ResponseEntity.status(400).body("{\"error\": \"" + e.getMessage() + "\"}");
        }
    }
}
