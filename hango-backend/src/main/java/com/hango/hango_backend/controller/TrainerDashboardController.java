package com.hango.hango_backend.controller;

import com.hango.hango_backend.dto.TrainerDashboardSummaryDTO;
import com.hango.hango_backend.dto.TrainerCoursesResponseDTO;
import com.hango.hango_backend.dto.CourseImportResultDTO;
import com.hango.hango_backend.service.CourseImportService;
import com.hango.hango_backend.service.ExamHistoryService;
import com.hango.hango_backend.service.TrainerDashboardService;
import com.hango.hango_backend.service.GeminiClientService;
import com.hango.hango_backend.dto.GenerateTranscriptRequest;
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
import com.hango.hango_backend.exception.ApiException;

@CrossOrigin(origins = "*", maxAge = 3600)
@RestController
@RequestMapping("/api/v1/trainer")
@RequiredArgsConstructor
public class TrainerDashboardController {

    private final TrainerDashboardService trainerDashboardService;
    private final CloudinaryService cloudinaryService;
    private final CourseImportService courseImportService;
    private final ExamHistoryService examHistoryService;
    private final GeminiClientService geminiClientService;

    @PostMapping("/courses/generate-transcript")
    @PreAuthorize("hasAuthority('MANAGE_OWN_COURSES') or hasAuthority('MANAGE_ACCOUNTS_ROLES') or hasRole('ADMINISTRATOR')")
    public ResponseEntity<?> generateVideoTranscript(@RequestBody GenerateTranscriptRequest request) {
        try {
            if (request == null || request.getVideoUrl() == null || request.getVideoUrl().isBlank()) {
                return ResponseEntity.badRequest().body("{\"error\": \"videoUrl is required\"}");
            }
            String transcript = geminiClientService.generateVideoTranscript(request.getVideoUrl());
            // Return JSON so the Frontend can parse it easily
            return ResponseEntity.ok(java.util.Map.of("transcript", transcript));
        } catch (Exception e) {
            e.printStackTrace();
            return ResponseEntity.badRequest().body(java.util.Map.of("error", e.getMessage() != null ? e.getMessage() : "Unknown error"));
        }
    }

    @PostMapping("/courses/upload")
    @PreAuthorize("hasAuthority('MANAGE_OWN_COURSES') or hasAuthority('MANAGE_ACCOUNTS_ROLES') or hasRole('ADMINISTRATOR')")
    public ResponseEntity<?> uploadCourseThumbnail(@RequestPart("file") MultipartFile file) {
        try {
            String url = cloudinaryService.uploadImage(file);
            return ResponseEntity.ok("{\"url\": \"" + url + "\"}");
        } catch (Exception e) {
            e.printStackTrace();
            return ResponseEntity.badRequest().body("{\"error\": \"" + e.getMessage() + "\"}");
        }
    }

    @PostMapping("/courses/upload-video")
    @PreAuthorize("hasAuthority('MANAGE_OWN_COURSES') or hasAuthority('MANAGE_ACCOUNTS_ROLES') or hasRole('ADMINISTRATOR')")
    public ResponseEntity<?> uploadCourseVideo(@RequestPart("file") MultipartFile file) {
        try {
            String url = cloudinaryService.uploadVideo(file);
            return ResponseEntity.ok("{\"url\": \"" + url + "\"}");
        } catch (Exception e) {
            e.printStackTrace();
            return ResponseEntity.badRequest().body("{\"error\": \"" + e.getMessage() + "\"}");
        }
    }

    @GetMapping("/courses/import/template")
    @PreAuthorize("hasAuthority('MANAGE_OWN_COURSES') or hasAuthority('MANAGE_ACCOUNTS_ROLES') or hasRole('COURSE_MANAGER') or hasRole('ADMINISTRATOR')")
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
    @PreAuthorize("hasAuthority('MANAGE_OWN_COURSES') or hasAuthority('MANAGE_ACCOUNTS_ROLES') or hasRole('ADMINISTRATOR')")
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
    @PreAuthorize("hasAuthority('MANAGE_OWN_COURSES') or hasAuthority('MANAGE_ACCOUNTS_ROLES') or hasRole('ADMINISTRATOR')")
    public ResponseEntity<?> getSystemParameters(@RequestParam("type") String type) {
        try {
            return ResponseEntity.ok(trainerDashboardService.getSystemParametersByType(type));
        } catch (Exception e) {
            e.printStackTrace();
            return ResponseEntity.badRequest().body("{\"error\": \"" + e.getMessage() + "\"}");
        }
    }

    // Buoc 1 cua flow "Content Building": Trainer tao khoa hoc moi.
    // Khoa hoc luon duoc tao voi status = "DRAFT" (xem TrainerDashboardServiceImpl
    // .createTrainerCourse) - chua co Section/Lesson nao, chi la thong tin chung
    // (tieu de, mo ta, danh muc, do kho, gia goi y).
    @PostMapping("/courses")
    @PreAuthorize("hasAuthority('MANAGE_OWN_COURSES') or hasAuthority('MANAGE_ACCOUNTS_ROLES') or hasRole('ADMINISTRATOR')")
    public ResponseEntity<?> createCourse(
            @AuthenticationPrincipal UserDetails userDetails,
            @RequestBody @jakarta.validation.Valid TrainerCreateCourseRequestDTO request) {
        try {
            if (userDetails == null) {
                return ResponseEntity.status(401).body("{\"error\": \"Unauthorized\"}");
            }
            trainerDashboardService.createTrainerCourse(userDetails.getUsername(), request);
            return ResponseEntity.ok("{\"message\": \"Course created successfully in DRAFT status\"}");
        } catch (ApiException e) {
            return ResponseEntity.status(e.getStatus()).body("{\"error\": \"" + e.getMessage() + "\"}");
        } catch (Exception e) {
            e.printStackTrace();
            return ResponseEntity.badRequest().body("{\"error\": \"" + e.getMessage() + "\"}");
        }
    }

    @DeleteMapping("/courses/{id}")
    @PreAuthorize("hasAuthority('MANAGE_OWN_COURSES') or hasAuthority('MANAGE_ACCOUNTS_ROLES') or hasRole('ADMINISTRATOR')")
    public ResponseEntity<?> deleteTrainerCourse(
            @PathVariable Long id,
            @AuthenticationPrincipal UserDetails userDetails) {
        try {
            if (userDetails == null) {
                return ResponseEntity.status(401).body("{\"error\": \"Unauthorized\"}");
            }
            trainerDashboardService.deleteTrainerCourse(id, userDetails.getUsername());
            return ResponseEntity.ok("{\"message\": \"Course deleted successfully\"}");
        } catch (ApiException e) {
            return ResponseEntity.status(e.getStatus()).body("{\"error\": \"" + e.getMessage() + "\"}");
        } catch (Exception e) {
            e.printStackTrace();
            return ResponseEntity.badRequest().body("{\"error\": \"" + e.getMessage() + "\"}");
        }
    }

    // Buoc 2: Trainer chinh sua noi dung (Section/Lesson) cua khoa hoc.
    // Endpoint nay dung CHUNG cho ca "Save draft" va "Auto-save" ben Frontend
    // (xem edit_course_page.dart _saveCourse/_autoSaveCourse - ca hai deu goi PUT nay).
    // Neu khoa hoc dang o trang thai PUBLISHED, Service se KHONG sua truc tiep
    // ma tao ra 1 ban DRAFT phien ban moi (xem updateTrainerCourse trong
    // TrainerDashboardServiceImpl) de khong lam thay doi noi dung hoc vien dang hoc.
    @PutMapping("/courses/{id}")
    @PreAuthorize("hasAuthority('MANAGE_OWN_COURSES') or hasAuthority('MANAGE_ACCOUNTS_ROLES') or hasRole('ADMINISTRATOR')")
    public ResponseEntity<?> updateCourse(
            @PathVariable Long id,
            @AuthenticationPrincipal UserDetails userDetails,
            @RequestBody @jakarta.validation.Valid TrainerCreateCourseRequestDTO request) {
        try {
            if (userDetails == null) {
                return ResponseEntity.status(401).body("{\"error\": \"Unauthorized\"}");
            }
            Long updatedCourseId = trainerDashboardService.updateTrainerCourse(id, userDetails.getUsername(), request);
            java.util.Map<String, Object> response = new java.util.HashMap<>();
            response.put("message", "Course updated successfully");
            response.put("courseId", updatedCourseId);
            return ResponseEntity.ok(response);
        } catch (ApiException e) {
            return ResponseEntity.status(e.getStatus()).body("{\"error\": \"" + e.getMessage() + "\"}");
        } catch (Exception e) {
            e.printStackTrace();
            return ResponseEntity.badRequest().body("{\"error\": \"" + e.getMessage() + "\"}");
        }
    }

    @PostMapping("/courses/{id}/publish")
    @PreAuthorize("hasAuthority('MANAGE_OWN_COURSES') or hasAuthority('MANAGE_ACCOUNTS_ROLES') or hasRole('ADMINISTRATOR')")
    public ResponseEntity<?> publishCourse(
            @PathVariable Long id,
            @AuthenticationPrincipal UserDetails userDetails) {
        try {
            if (userDetails == null) {
                return ResponseEntity.status(401).body("{\"error\": \"Unauthorized\"}");
            }
            trainerDashboardService.publishTrainerCourse(id, userDetails.getUsername());
            return ResponseEntity.ok("{\"message\": \"Course published successfully\"}");
        } catch (ApiException e) {
            return ResponseEntity.status(e.getStatus()).body("{\"error\": \"" + e.getMessage() + "\"}");
        } catch (Exception e) {
            e.printStackTrace();
            return ResponseEntity.badRequest().body("{\"error\": \"" + e.getMessage() + "\"}");
        }
    }

    // Buoc 3: Trainer bam "Submit for review" -> chuyen khoa hoc sang trang thai
    // cho duyet. Neu nguoi tao la Trainer thuong: status -> PENDING_APPROVAL,
    // cho Course Manager duyet (xem CourseManagerDashboardController.publishCourse).
    // Neu nguoi tao von da la COURSE_MANAGER/ADMINISTRATOR: tu dong PUBLISHED
    // luon, khong can ai duyet (xem logic isManager trong submitTrainerCourse).
    @PostMapping("/courses/{id}/submit")
    @PreAuthorize("hasAuthority('MANAGE_OWN_COURSES') or hasAuthority('MANAGE_ACCOUNTS_ROLES') or hasRole('ADMINISTRATOR')")
    public ResponseEntity<?> submitCourseForReview(
            @PathVariable Long id,
            @AuthenticationPrincipal UserDetails userDetails) {
        try {
            if (userDetails == null) {
                return ResponseEntity.status(401).body("{\"error\": \"Unauthorized\"}");
            }
            trainerDashboardService.submitTrainerCourse(id, userDetails.getUsername());
            return ResponseEntity.ok("{\"message\": \"Course submitted for review\"}");
        } catch (ApiException e) {
            return ResponseEntity.status(e.getStatus()).body("{\"error\": \"" + e.getMessage() + "\"}");
        } catch (Exception e) {
            e.printStackTrace();
            return ResponseEntity.badRequest().body("{\"error\": \"" + e.getMessage() + "\"}");
        }
    }

    @PostMapping("/courses/{id}/re-evaluate-price")
    @PreAuthorize("hasAuthority('MANAGE_OWN_COURSES') or hasAuthority('MANAGE_ACCOUNTS_ROLES') or hasRole('ADMINISTRATOR')")
    public ResponseEntity<?> reEvaluateCoursePrice(
            @PathVariable Long id,
            @AuthenticationPrincipal UserDetails userDetails) {
        try {
            if (userDetails == null) {
                return ResponseEntity.status(401).body("{\"error\": \"Unauthorized\"}");
            }
            trainerDashboardService.reEvaluateCoursePrice(id, userDetails.getUsername());
            return ResponseEntity.ok("{\"message\": \"Course price re-evaluated successfully\"}");
        } catch (ApiException e) {
            return ResponseEntity.status(e.getStatus()).body("{\"error\": \"" + e.getMessage() + "\"}");
        } catch (Exception e) {
            e.printStackTrace();
            return ResponseEntity.badRequest().body("{\"error\": \"" + e.getMessage() + "\"}");
        }
    }

    @GetMapping("/dashboard")
    @PreAuthorize("hasAuthority('MANAGE_OWN_COURSES') or hasAuthority('MANAGE_ACCOUNTS_ROLES') or hasRole('ADMINISTRATOR')")
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
    @PreAuthorize("hasAuthority('MANAGE_OWN_COURSES') or hasAuthority('MANAGE_ACCOUNTS_ROLES') or hasRole('ADMINISTRATOR')")
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
    @PreAuthorize("hasAuthority('CREATE_EXAMS_TRAINER') or hasAuthority('MANAGE_ACCOUNTS_ROLES') or hasRole('COURSE_MANAGER') or hasRole('ADMINISTRATOR')")
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

    @GetMapping("/exams/{id}/history")
    @PreAuthorize("hasAuthority('CREATE_EXAMS_TRAINER') or hasAuthority('MANAGE_ACCOUNTS_ROLES') or hasRole('COURSE_MANAGER') or hasRole('ADMINISTRATOR')")
    public ResponseEntity<?> getExamHistory(@PathVariable Long id, @AuthenticationPrincipal UserDetails userDetails) {
        try {
            if (userDetails == null) {
                return ResponseEntity.status(401).body("{\"error\": \"Unauthorized\"}");
            }
            java.util.List<com.hango.hango_backend.dto.ExamHistoryLogDTO> history = examHistoryService
                    .getHistory(id, userDetails.getUsername());
            return ResponseEntity.ok(history);
        } catch (org.springframework.security.access.AccessDeniedException e) {
            return ResponseEntity.status(403).body("{\"error\": \"" + e.getMessage() + "\"}");
        } catch (Exception e) {
            e.printStackTrace();
            return ResponseEntity.badRequest().body("{\"error\": \"" + e.getMessage() + "\"}");
        }
    }

    @PostMapping("/exams")
    @PreAuthorize("hasAuthority('CREATE_EXAMS_TRAINER') or hasAuthority('CREATE_AND_MANAGE_EXAMS_CM') or hasRole('COURSE_MANAGER') or hasRole('ADMINISTRATOR')")
    public ResponseEntity<?> createTrainerExam(
            @AuthenticationPrincipal UserDetails userDetails,
            @RequestBody com.hango.hango_backend.dto.TrainerCreateExamRequestDTO request) {
        try {
            if (userDetails == null) {
                return ResponseEntity.status(401).body("{\"error\": \"Unauthorized\"}");
            }
            Long newId = trainerDashboardService.createTrainerExam(userDetails.getUsername(), request);
            return ResponseEntity.ok("{\"id\": " + newId + ", \"message\": \"Exam created successfully in DRAFT status\"}");
        } catch (Exception e) {
            e.printStackTrace();
            return ResponseEntity.badRequest().body("{\"error\": \"" + e.getMessage() + "\"}");
        }
    }

    @org.springframework.web.bind.annotation.PutMapping("/exams/{id}/info")
    @PreAuthorize("hasAuthority('CREATE_EXAMS_TRAINER') or hasAuthority('CREATE_AND_MANAGE_EXAMS_CM') or hasRole('COURSE_MANAGER') or hasRole('ADMINISTRATOR')")
    public ResponseEntity<?> updateExamBasicInfo(
            @PathVariable Long id,
            @AuthenticationPrincipal UserDetails userDetails,
            @RequestBody com.hango.hango_backend.dto.TrainerUpdateExamInfoRequestDTO request) {
        try {
            if (userDetails == null) {
                return ResponseEntity.status(401).body("{\"error\": \"Unauthorized\"}");
            }
            trainerDashboardService.updateTrainerExamBasicInfo(id, userDetails.getUsername(), request);
            return ResponseEntity.ok("{\"message\": \"Exam metadata updated successfully\"}");
        } catch (Exception e) {
            e.printStackTrace();
            return ResponseEntity.badRequest().body("{\"error\": \"" + e.getMessage() + "\"}");
        }
    }

    @PostMapping("/exams/{id}/questions")
    @PreAuthorize("hasAuthority('CREATE_EXAMS_TRAINER') or hasAuthority('CREATE_AND_MANAGE_EXAMS_CM') or hasAuthority('MANAGE_ACCOUNTS_ROLES') or hasRole('ADMINISTRATOR')")
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
    @PreAuthorize("hasAuthority('CREATE_EXAMS_TRAINER') or hasAuthority('CREATE_AND_MANAGE_EXAMS_CM') or hasAuthority('MANAGE_ACCOUNTS_ROLES') or hasRole('ADMINISTRATOR')")
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
    @PreAuthorize("hasAuthority('CREATE_EXAMS_TRAINER') or hasAuthority('CREATE_AND_MANAGE_EXAMS_CM') or hasAuthority('MANAGE_ACCOUNTS_ROLES') or hasRole('ADMINISTRATOR')")
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
    @PreAuthorize("hasAuthority('CREATE_EXAMS_TRAINER') or hasAuthority('MANAGE_ACCOUNTS_ROLES') or hasRole('ADMINISTRATOR')")
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
    @PreAuthorize("hasAuthority('MANAGE_OWN_COURSES') or hasAuthority('MANAGE_ACCOUNTS_ROLES') or hasRole('ADMINISTRATOR')")
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
