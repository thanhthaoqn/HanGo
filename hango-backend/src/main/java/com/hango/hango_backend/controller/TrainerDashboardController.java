package com.hango.hango_backend.controller;

import com.hango.hango_backend.dto.TrainerDashboardSummaryDTO;
import com.hango.hango_backend.dto.TrainerCoursesResponseDTO;
import com.hango.hango_backend.dto.CourseImportResultDTO;
import com.hango.hango_backend.service.CourseImportService;
import com.hango.hango_backend.service.TrainerDashboardService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.web.bind.annotation.CrossOrigin;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestPart;
import org.springframework.web.multipart.MultipartFile;
import com.hango.hango_backend.service.CloudinaryService;
import com.hango.hango_backend.dto.TrainerCreateCourseRequestDTO;

@CrossOrigin(origins = "*", maxAge = 3600)
@RestController
@RequestMapping("/api/v1/trainer")
@RequiredArgsConstructor
public class TrainerDashboardController {

    private final TrainerDashboardService trainerDashboardService;
    private final CloudinaryService cloudinaryService;
    private final CourseImportService courseImportService;

    @PostMapping("/courses/upload")
    @PreAuthorize("hasAnyRole('TRAINER', 'ADMINISTRATOR', 'TRAINER_LEAD', 'COURSE_MANAGER')")
    public ResponseEntity<?> uploadCourseThumbnail(@RequestPart("file") MultipartFile file) {
        try {
            String url = cloudinaryService.uploadImage(file);
            return ResponseEntity.ok("{\"url\": \"" + url + "\"}");
        } catch (Exception e) {
            e.printStackTrace();
            return ResponseEntity.badRequest().body("{\"error\": \"" + e.getMessage() + "\"}");
        }
    }

    @GetMapping("/courses/import/template")
    @PreAuthorize("hasAnyRole('TRAINER', 'ADMINISTRATOR', 'TRAINER_LEAD', 'COURSE_MANAGER')")
    public ResponseEntity<byte[]> downloadCourseImportTemplate() {
        try {
            byte[] workbook = courseImportService.buildTemplateWorkbook();
            return ResponseEntity.ok()
                    .header(HttpHeaders.CONTENT_DISPOSITION, "attachment; filename=\"Hango_Course_Import_Template.xlsx\"")
                    .contentType(MediaType.parseMediaType("application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"))
                    .body(workbook);
        } catch (Exception e) {
            e.printStackTrace();
            return ResponseEntity.internalServerError().build();
        }
    }

    @PostMapping("/courses/import")
    @PreAuthorize("hasAnyRole('TRAINER', 'ADMINISTRATOR', 'TRAINER_LEAD', 'COURSE_MANAGER')")
    public ResponseEntity<?> importCoursesFromExcel(
            @AuthenticationPrincipal UserDetails userDetails,
            @RequestPart("file") MultipartFile file) {
        try {
            if (userDetails == null) {
                return ResponseEntity.status(401).body("{\"error\": \"Unauthorized\"}");
            }
            CourseImportResultDTO result = courseImportService.importWorkbook(userDetails.getUsername(), file);
            return ResponseEntity.ok(result);
        } catch (Exception e) {
            e.printStackTrace();
            return ResponseEntity.badRequest().body("{\"error\": \"" + e.getMessage() + "\"}");
        }
    }

    @GetMapping("/system-parameters")
    @PreAuthorize("hasAnyRole('TRAINER', 'ADMINISTRATOR', 'TRAINER_LEAD', 'COURSE_MANAGER')")
    public ResponseEntity<?> getSystemParameters(@RequestParam("type") String type) {
        try {
            return ResponseEntity.ok(trainerDashboardService.getSystemParametersByType(type));
        } catch (Exception e) {
            e.printStackTrace();
            return ResponseEntity.badRequest().body("{\"error\": \"" + e.getMessage() + "\"}");
        }
    }

    @PostMapping("/courses")
    @PreAuthorize("hasAnyRole('TRAINER', 'ADMINISTRATOR', 'TRAINER_LEAD', 'COURSE_MANAGER')")
    public ResponseEntity<?> createCourse(
            @AuthenticationPrincipal UserDetails userDetails,
            @RequestBody TrainerCreateCourseRequestDTO request) {
        try {
            if (userDetails == null) {
                return ResponseEntity.status(401).body("{\"error\": \"Unauthorized\"}");
            }
            trainerDashboardService.createTrainerCourse(userDetails.getUsername(), request);
            return ResponseEntity.ok("{\"message\": \"Course created successfully in DRAFT status\"}");
        } catch (Exception e) {
            e.printStackTrace();
            return ResponseEntity.badRequest().body("{\"error\": \"" + e.getMessage() + "\"}");
        }
    }

    @DeleteMapping("/courses/{id}")
    @PreAuthorize("hasAnyRole('TRAINER', 'ADMINISTRATOR', 'TRAINER_LEAD', 'COURSE_MANAGER')")
    public ResponseEntity<?> deleteTrainerCourse(
            @PathVariable Long id,
            @AuthenticationPrincipal UserDetails userDetails) {
        try {
            if (userDetails == null) {
                return ResponseEntity.status(401).body("{\"error\": \"Unauthorized\"}");
            }
            trainerDashboardService.deleteTrainerCourse(id, userDetails.getUsername());
            return ResponseEntity.ok("{\"message\": \"Course deleted successfully\"}");
        } catch (Exception e) {
            e.printStackTrace();
            return ResponseEntity.badRequest().body("{\"error\": \"" + e.getMessage() + "\"}");
        }
    }

    @PutMapping("/courses/{id}")
    @PreAuthorize("hasAnyRole('TRAINER', 'ADMINISTRATOR', 'TRAINER_LEAD', 'COURSE_MANAGER')")
    public ResponseEntity<?> updateCourse(
            @PathVariable Long id,
            @AuthenticationPrincipal UserDetails userDetails,
            @RequestBody TrainerCreateCourseRequestDTO request) {
        try {
            if (userDetails == null) {
                return ResponseEntity.status(401).body("{\"error\": \"Unauthorized\"}");
            }
            trainerDashboardService.updateTrainerCourse(id, userDetails.getUsername(), request);
            return ResponseEntity.ok("{\"message\": \"Course updated successfully\"}");
        } catch (Exception e) {
            e.printStackTrace();
            return ResponseEntity.badRequest().body("{\"error\": \"" + e.getMessage() + "\"}");
        }
    }

    @PostMapping("/courses/{id}/publish")
    @PreAuthorize("hasAnyRole('TRAINER', 'ADMINISTRATOR', 'TRAINER_LEAD', 'COURSE_MANAGER')")
    public ResponseEntity<?> publishCourse(
            @PathVariable Long id,
            @AuthenticationPrincipal UserDetails userDetails) {
        try {
            if (userDetails == null) {
                return ResponseEntity.status(401).body("{\"error\": \"Unauthorized\"}");
            }
            trainerDashboardService.publishTrainerCourse(id, userDetails.getUsername());
            return ResponseEntity.ok("{\"message\": \"Course published successfully\"}");
        } catch (Exception e) {
            e.printStackTrace();
            return ResponseEntity.badRequest().body("{\"error\": \"" + e.getMessage() + "\"}");
        }
    }

    @PostMapping("/courses/{id}/submit")
    @PreAuthorize("hasAnyRole('TRAINER', 'ADMINISTRATOR', 'TRAINER_LEAD', 'COURSE_MANAGER')")
    public ResponseEntity<?> submitCourseForReview(
            @PathVariable Long id,
            @AuthenticationPrincipal UserDetails userDetails) {
        try {
            if (userDetails == null) {
                return ResponseEntity.status(401).body("{\"error\": \"Unauthorized\"}");
            }
            trainerDashboardService.submitTrainerCourse(id, userDetails.getUsername());
            return ResponseEntity.ok("{\"message\": \"Course submitted for review\"}");
        } catch (Exception e) {
            e.printStackTrace();
            return ResponseEntity.badRequest().body("{\"error\": \"" + e.getMessage() + "\"}");
        }
    }

    @GetMapping("/dashboard")
    @PreAuthorize("hasAnyRole('TRAINER', 'ADMINISTRATOR', 'TRAINER_LEAD', 'COURSE_MANAGER')")
    public ResponseEntity<?> getTrainerDashboard(@AuthenticationPrincipal UserDetails userDetails) {
        try {
            if (userDetails == null) {
                return ResponseEntity.status(401).body("{\"error\": \"Unauthorized\"}");
            }
            TrainerDashboardSummaryDTO summary = trainerDashboardService.getTrainerDashboardSummary(userDetails.getUsername());
            return ResponseEntity.ok(summary);
        } catch (Exception e) {
            e.printStackTrace();
            return ResponseEntity.badRequest().body("{\"error\": \"" + e.getMessage() + "\"}");
        }
    }

    @GetMapping("/courses")
    @PreAuthorize("hasAnyRole('TRAINER', 'ADMINISTRATOR', 'TRAINER_LEAD', 'COURSE_MANAGER')")
    public ResponseEntity<?> getTrainerCourses(
            @AuthenticationPrincipal UserDetails userDetails,
            @RequestParam(defaultValue = "ALL") String status,
            @RequestParam(required = false) String search,
            @RequestParam(defaultValue = "NEWEST") String sortBy,
            @RequestParam(defaultValue = "ALL") String timePeriod) {
        try {
            if (userDetails == null) {
                return ResponseEntity.status(401).body("{\"error\": \"Unauthorized\"}");
            }
            TrainerCoursesResponseDTO response = trainerDashboardService.getTrainerCourses(
                    userDetails.getUsername(), status, search, sortBy, timePeriod);
            return ResponseEntity.ok(response);
        } catch (Exception e) {
            e.printStackTrace();
            return ResponseEntity.badRequest().body("{\"error\": \"" + e.getMessage() + "\"}");
        }
    }

    @GetMapping("/exams")
    @PreAuthorize("hasAnyRole('TRAINER', 'ADMINISTRATOR', 'TRAINER_LEAD', 'COURSE_MANAGER')")
    public ResponseEntity<?> getTrainerExams(@AuthenticationPrincipal UserDetails userDetails) {
        try {
            if (userDetails == null) {
                return ResponseEntity.status(401).body("{\"error\": \"Unauthorized\"}");
            }
            java.util.List<com.hango.hango_backend.dto.TrainerExamResponseDTO> response = trainerDashboardService.getTrainerExams(userDetails.getUsername());
            return ResponseEntity.ok(response);
        } catch (Exception e) {
            e.printStackTrace();
            return ResponseEntity.badRequest().body("{\"error\": \"" + e.getMessage() + "\"}");
        }
    }

    @PostMapping("/exams")
    @PreAuthorize("hasAnyRole('TRAINER', 'ADMINISTRATOR', 'TRAINER_LEAD', 'COURSE_MANAGER')")
    public ResponseEntity<?> createTrainerExam(
            @AuthenticationPrincipal UserDetails userDetails,
            @RequestBody com.hango.hango_backend.dto.TrainerCreateExamRequestDTO request) {
        try {
            if (userDetails == null) {
                return ResponseEntity.status(401).body("{\"error\": \"Unauthorized\"}");
            }
            trainerDashboardService.createTrainerExam(userDetails.getUsername(), request);
            return ResponseEntity.ok("{\"message\": \"Exam created successfully in DRAFT status\"}");
        } catch (Exception e) {
            e.printStackTrace();
            return ResponseEntity.badRequest().body("{\"error\": \"" + e.getMessage() + "\"}");
        }
    }

    @PostMapping("/exams/{id}/questions")
    @PreAuthorize("hasAnyRole('TRAINER', 'ADMINISTRATOR', 'TRAINER_LEAD', 'COURSE_MANAGER')")
    public ResponseEntity<?> saveExamQuestions(
            @PathVariable Long id,
            @AuthenticationPrincipal UserDetails userDetails,
            @RequestBody com.hango.hango_backend.dto.TrainerSaveExamQuestionsRequestDTO request) {
        try {
            if (userDetails == null) {
                return ResponseEntity.status(401).body("{\"error\": \"Unauthorized\"}");
            }
            trainerDashboardService.saveExamQuestions(id, userDetails.getUsername(), request);
            return ResponseEntity.ok("{\"message\": \"Exam questions saved successfully\"}");
        } catch (Exception e) {
            e.printStackTrace();
            return ResponseEntity.badRequest().body("{\"error\": \"" + e.getMessage() + "\"}");
        }
    }

    @GetMapping("/exams/{id}/questions")
    @PreAuthorize("hasAnyRole('TRAINER', 'ADMINISTRATOR', 'TRAINER_LEAD', 'COURSE_MANAGER')")
    public ResponseEntity<?> getExamQuestions(
            @PathVariable Long id,
            @AuthenticationPrincipal UserDetails userDetails) {
        try {
            if (userDetails == null) {
                return ResponseEntity.status(401).body("{\"error\": \"Unauthorized\"}");
            }
            com.hango.hango_backend.dto.TrainerSaveExamQuestionsRequestDTO response = trainerDashboardService.getExamQuestions(id, userDetails.getUsername());
            return ResponseEntity.ok(response);
        } catch (Exception e) {
            e.printStackTrace();
            return ResponseEntity.badRequest().body("{\"error\": \"" + e.getMessage() + "\"}");
        }
    }

    @org.springframework.web.bind.annotation.PatchMapping("/exams/{id}/status")
    @PreAuthorize("hasAnyRole('TRAINER', 'ADMINISTRATOR', 'TRAINER_LEAD', 'COURSE_MANAGER')")
    public ResponseEntity<?> updateExamStatus(
            @PathVariable Long id,
            @AuthenticationPrincipal UserDetails userDetails,
            @RequestBody java.util.Map<String, String> body) {
        try {
            if (userDetails == null) {
                return ResponseEntity.status(401).body("{\"error\": \"Unauthorized\"}");
            }
            String newStatus = body.get("status");
            if (newStatus == null || newStatus.isBlank()) {
                return ResponseEntity.badRequest().body("{\"error\": \"Status is required\"}");
            }
            trainerDashboardService.updateExamStatus(id, userDetails.getUsername(), newStatus);
            return ResponseEntity.ok("{\"message\": \"Exam status updated to " + newStatus + "\"}");
        } catch (Exception e) {
            e.printStackTrace();
            return ResponseEntity.badRequest().body("{\"error\": \"" + e.getMessage() + "\"}");
        }
    }

    @org.springframework.web.bind.annotation.PatchMapping("/exams/{id}/visibility")
    @PreAuthorize("hasAnyRole('TRAINER', 'ADMINISTRATOR', 'TRAINER_LEAD', 'COURSE_MANAGER')")
    public ResponseEntity<?> updateExamVisibility(
            @PathVariable Long id,
            @AuthenticationPrincipal UserDetails userDetails,
            @RequestBody java.util.Map<String, String> body) {
        try {
            if (userDetails == null) {
                return ResponseEntity.status(401).body("{\"error\": \"Unauthorized\"}");
            }
            String newVisibility = body.get("visibility");
            if (newVisibility == null || newVisibility.isBlank()) {
                return ResponseEntity.badRequest().body("{\"error\": \"Visibility is required\"}");
            }
            trainerDashboardService.updateExamVisibility(id, userDetails.getUsername(), newVisibility.toUpperCase());
            return ResponseEntity.ok("{\"message\": \"Exam visibility updated to " + newVisibility.toUpperCase() + "\"}");
        } catch (Exception e) {
            e.printStackTrace();
            return ResponseEntity.badRequest().body("{\"error\": \"" + e.getMessage() + "\"}");
        }
    }

    @org.springframework.web.bind.annotation.DeleteMapping("/exams/{id}")
    @PreAuthorize("hasAnyRole('TRAINER', 'ADMINISTRATOR', 'TRAINER_LEAD', 'COURSE_MANAGER')")
    public ResponseEntity<?> deleteTrainerExam(
            @PathVariable Long id,
            @AuthenticationPrincipal UserDetails userDetails) {
        try {
            if (userDetails == null) {
                return ResponseEntity.status(401).body("{\"error\": \"Unauthorized\"}");
            }
            trainerDashboardService.deleteTrainerExam(id, userDetails.getUsername());
            return ResponseEntity.ok("{\"message\": \"Exam deleted successfully\"}");
        } catch (Exception e) {
            e.printStackTrace();
            return ResponseEntity.badRequest().body("{\"error\": \"" + e.getMessage() + "\"}");
        }
    }
}
