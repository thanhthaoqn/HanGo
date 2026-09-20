package com.hango.hango_backend.controller;

import com.hango.hango_backend.dto.CourseSummaryDTO;
import com.hango.hango_backend.dto.CourseReviewRequestDTO;
import com.hango.hango_backend.service.CourseRatingService;
import com.hango.hango_backend.service.CourseService;
import com.hango.hango_backend.repository.CourseRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Pageable;
import org.springframework.data.domain.Sort;

@RestController
@RequestMapping("/api/v1/courses")
@RequiredArgsConstructor
public class CourseController {

    private final CourseService courseService;
    private final CourseRatingService courseRatingService;
    private final CourseRepository courseRepository;

    private Long resolveCourseId(String identifier) {
        if (identifier == null || identifier.isBlank()) {
            throw new RuntimeException("Course identifier cannot be blank");
        }
        try {
            return Long.parseLong(identifier);
        } catch (NumberFormatException ignored) {}
        return courseRepository.findByUuidAndDeletedAtIsNull(identifier)
                .map(com.hango.hango_backend.entity.Course::getId)
                .orElseThrow(() -> new RuntimeException("Course not found with identifier: " + identifier));
    }

    @GetMapping
    public ResponseEntity<Page<CourseSummaryDTO>> getCourses(
            @RequestParam(required = false) String search,
            @RequestParam(required = false, defaultValue = "ALL") String filterType,
            @RequestParam(required = false, defaultValue = "ALL") String difficulty,
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "8") int size) {
        
        Pageable pageable = PageRequest.of(page, size, Sort.by("createdAt").descending());
        Page<CourseSummaryDTO> courses = courseService.getCourses(search, filterType, difficulty, pageable);
        return ResponseEntity.ok(courses);
    }

    private Long getCurrentUserId() {
        org.springframework.security.core.Authentication auth = org.springframework.security.core.context.SecurityContextHolder.getContext().getAuthentication();
        if (auth != null && auth.getPrincipal() instanceof com.hango.hango_backend.security.UserDetailsImpl) {
            return ((com.hango.hango_backend.security.UserDetailsImpl) auth.getPrincipal()).getId();
        }
        return null;
    }

    @GetMapping("/{identifier}")
    public ResponseEntity<?> getCourseDetail(@PathVariable String identifier) {
        try {
            Long currentUserId = getCurrentUserId();
            return ResponseEntity.ok(courseService.getCourseDetailByIdentifier(identifier, currentUserId));
        } catch (RuntimeException e) {
            e.printStackTrace();
            return ResponseEntity.status(404).body(e.getClass().getName() + ": " + e.getMessage());
        }
    }

    @PostMapping("/{identifier}/enroll")
    @PreAuthorize("hasAuthority('ENROLL_AND_LEARN_COURSES') or hasAnyRole('TRAINER', 'COURSE_MANAGER', 'ADMINISTRATOR') or hasAuthority('MANAGE_ACCOUNTS_ROLES')")
    public ResponseEntity<?> enrollCourse(@PathVariable String identifier) {
        try {
            Long currentUserId = getCurrentUserId();
            if (currentUserId == null) {
                return ResponseEntity.status(401).body("{\"error\": \"Unauthorized\"}");
            }
            Long id = resolveCourseId(identifier);
            courseService.enrollCourse(id, currentUserId);
            return ResponseEntity.ok().body("{\"message\": \"Enrollment successful\"}");
        } catch (RuntimeException e) {
            e.printStackTrace();
            return ResponseEntity.status(400).body("{\"error\": \"" + e.getMessage() + "\"}");
        }
    }


    @DeleteMapping("/{identifier}/enroll")
    @PreAuthorize("hasAuthority('ENROLL_AND_LEARN_COURSES') or hasAnyRole('TRAINER', 'COURSE_MANAGER', 'ADMINISTRATOR') or hasAuthority('MANAGE_ACCOUNTS_ROLES')")
    public ResponseEntity<?> unenrollCourse(@PathVariable String identifier) {
        try {
            Long currentUserId = getCurrentUserId();
            if (currentUserId == null) {
                return ResponseEntity.status(401).body("{\"error\": \"Unauthorized\"}");
            }
            Long id = resolveCourseId(identifier);
            courseService.unenrollCourse(id, currentUserId);
            return ResponseEntity.ok().body("{\"message\": \"Unenrollment successful\"}");
        } catch (RuntimeException e) {
            e.printStackTrace();
            return ResponseEntity.status(400).body("{\"error\": \"" + e.getMessage() + "\"}");
        }
    }

    @PostMapping("/{identifier}/switch-version")
    @PreAuthorize("hasAuthority('ENROLL_AND_LEARN_COURSES') or hasAnyRole('TRAINER', 'COURSE_MANAGER', 'ADMINISTRATOR') or hasAuthority('MANAGE_ACCOUNTS_ROLES')")
    public ResponseEntity<?> switchCourseVersion(@PathVariable String identifier) {
        try {
            Long currentUserId = getCurrentUserId();
            if (currentUserId == null) {
                return ResponseEntity.status(401).body("{\"error\": \"Unauthorized\"}");
            }
            Long id = resolveCourseId(identifier);
            courseService.switchCourseVersion(id, currentUserId);
            return ResponseEntity.ok().body("{\"message\": \"Course version switched successfully\"}");
        } catch (RuntimeException e) {
            e.printStackTrace();
            return ResponseEntity.status(400).body("{\"error\": \"" + e.getMessage() + "\"}");
        }
    }

    @GetMapping("/{identifier}/reviews")
    public ResponseEntity<?> getCourseReviews(@PathVariable String identifier) {
        try {
            Long id = resolveCourseId(identifier);
            return ResponseEntity.ok(courseRatingService.getCourseReviews(id));
        } catch (RuntimeException e) {
            e.printStackTrace();
            return ResponseEntity.status(404).body(e.getClass().getName() + ": " + e.getMessage());
        }
    }

    @PreAuthorize("hasAuthority('RATE_AND_COMMENT') or hasAuthority('MANAGE_ACCOUNTS_ROLES') or hasRole('ADMINISTRATOR')")
    @PostMapping("/{identifier}/reviews")
    public ResponseEntity<?> addCourseReview(@PathVariable String identifier,
                                             @RequestBody @jakarta.validation.Valid CourseReviewRequestDTO request) {
        try {
            Long currentUserId = getCurrentUserId();
            if (currentUserId == null) {
                return ResponseEntity.status(401).body("{\"error\": \"Unauthorized\"}");
            }
            Long id = resolveCourseId(identifier);
            courseRatingService.addCourseReview(id, currentUserId, request.getRating(), request.getContent());
            return ResponseEntity.ok().body("{\"message\": \"Review posted successfully\"}");
        } catch (RuntimeException e) {
            e.printStackTrace();
            return ResponseEntity.status(400).body("{\"error\": \"" + e.getMessage() + "\"}");
        }
    }

    @PreAuthorize("hasAuthority('RATE_AND_COMMENT') or hasAuthority('MODERATE_COMMENTS') or hasAuthority('MANAGE_ACCOUNTS_ROLES') or hasRole('ADMINISTRATOR')")
    @DeleteMapping("/{identifier}/reviews")
    public ResponseEntity<?> deleteCourseReview(@PathVariable String identifier) {
        try {
            Long currentUserId = getCurrentUserId();
            if (currentUserId == null) {
                return ResponseEntity.status(401).body("{\"error\": \"Unauthorized\"}");
            }
            Long id = resolveCourseId(identifier);
            courseRatingService.deleteCourseReview(id, currentUserId);
            return ResponseEntity.ok().body("{\"message\": \"Review deleted successfully\"}");
        } catch (RuntimeException e) {
            e.printStackTrace();
            return ResponseEntity.status(400).body("{\"error\": \"" + e.getMessage() + "\"}");
        }
    }

    @GetMapping("/{id}/versions")
    public ResponseEntity<?> getCourseVersionHistory(@PathVariable Long id) {
        try {
            return ResponseEntity.ok(courseService.getCourseVersionHistory(id));
        } catch (RuntimeException e) {
            e.printStackTrace();
            return ResponseEntity.status(404).body(e.getClass().getName() + ": " + e.getMessage());
        }
    }
}
