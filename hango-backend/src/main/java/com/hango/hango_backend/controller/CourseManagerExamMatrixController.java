package com.hango.hango_backend.controller;

import com.hango.hango_backend.dto.ExamMatrixCreateRequestDTO;
import com.hango.hango_backend.dto.ExamMatrixDTO;
import com.hango.hango_backend.repository.QuestionRepository;
import com.hango.hango_backend.repository.UserRepository;
import com.hango.hango_backend.entity.User;
import com.hango.hango_backend.service.ExamMatrixService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.Map;

@RestController
@RequestMapping("/api/v1/course-manager/matrices")
@RequiredArgsConstructor
public class CourseManagerExamMatrixController {

    private final ExamMatrixService matrixService;
    private final QuestionRepository questionRepository;
    private final UserRepository userRepository;

    @GetMapping
    @PreAuthorize("hasAnyAuthority('COURSE_MANAGER', 'ADMINISTRATOR', 'ROLE_COURSE_MANAGER', 'ROLE_ADMINISTRATOR')")
    public ResponseEntity<List<ExamMatrixDTO>> getAllMatrices(
            @AuthenticationPrincipal UserDetails userDetails) {
        if (userDetails == null) {
            return ResponseEntity.status(401).build();
        }
        try {
            List<ExamMatrixDTO> result = matrixService.getAllMatricesForManager();
            System.out.println("[CourseManagerMatrix] getAllMatrices returned " + result.size() + " items");
            return ResponseEntity.ok(result);
        } catch (Exception e) {
            System.err.println("[CourseManagerMatrix] ERROR in getAllMatrices: " + e.getMessage());
            e.printStackTrace();
            return ResponseEntity.ok(java.util.Collections.emptyList());
        }
    }

    @PostMapping
    @PreAuthorize("hasAuthority('CREATE_AND_MANAGE_EXAMS_CM') or hasAuthority('MANAGE_ACCOUNTS_ROLES') or hasRole('ADMINISTRATOR')")
    public ResponseEntity<?> createMatrix(
            @AuthenticationPrincipal UserDetails userDetails,
            @RequestBody ExamMatrixCreateRequestDTO request) {
        try {
            if (userDetails == null) {
                return ResponseEntity.status(401).body("{\"error\": \"Unauthorized\"}");
            }
            matrixService.createExamMatrix(userDetails.getUsername(), request);
            return ResponseEntity.ok("{\"message\": \"Exam matrix created successfully\"}");
        } catch (Exception e) {
            e.printStackTrace();
            return ResponseEntity.badRequest().body("{\"error\": \"" + e.getMessage() + "\"}");
        }
    }

    @PostMapping("/{id}/generate")
    @PreAuthorize("hasAuthority('CREATE_AND_MANAGE_EXAMS_CM') or hasAuthority('MANAGE_ACCOUNTS_ROLES') or hasRole('ADMINISTRATOR')")
    public ResponseEntity<?> generateExamFromMatrix(
            @PathVariable Long id,
            @AuthenticationPrincipal UserDetails userDetails,
            @RequestBody Map<String, Object> request) {
        try {
            if (userDetails == null) {
                return ResponseEntity.status(401).body("{\"error\": \"Unauthorized\"}");
            }
            String title = request.get("title") != null ? request.get("title").toString() : null;
            String description = request.get("description") != null ? request.get("description").toString() : null;
            Integer durationMinutes = request.get("durationMinutes") != null ? Integer.parseInt(request.get("durationMinutes").toString()) : null;
            Integer expectedQuestionCount = request.get("expectedQuestionCount") != null ? Integer.parseInt(request.get("expectedQuestionCount").toString()) : null;
            Double passingScore = request.get("passingScore") != null ? Double.parseDouble(request.get("passingScore").toString()) : null;
            Integer questionSourceType = request.get("questionSourceType") != null ? Integer.parseInt(request.get("questionSourceType").toString()) : null;

            Long generatedExamId = matrixService.generateExamFromMatrix(id, title, description, expectedQuestionCount, passingScore, durationMinutes, questionSourceType, userDetails.getUsername());
            return ResponseEntity
                    .ok("{\"examId\": " + generatedExamId + ", \"message\": \"Exam generated successfully\"}");
        } catch (Exception e) {
            e.printStackTrace();
            return ResponseEntity.badRequest().body("{\"error\": \"" + e.getMessage() + "\"}");
        }
    }

    @GetMapping("/count-available")
    @PreAuthorize("hasAuthority('CREATE_AND_MANAGE_EXAMS_CM') or hasAuthority('MANAGE_ACCOUNTS_ROLES') or hasRole('ADMINISTRATOR')")
    public ResponseEntity<?> countAvailableQuestions(
            @AuthenticationPrincipal UserDetails userDetails,
            @RequestParam Long skillId,
            @RequestParam Long diffId,
            @RequestParam Long catId,
            @RequestParam(required = false) Integer questionSourceType) {
        try {
            if (userDetails == null) {
                return ResponseEntity.status(401).body("{\"error\": \"Unauthorized\"}");
            }
            User user = userRepository.findByEmail(userDetails.getUsername())
                    .orElseThrow(() -> new RuntimeException("User not found: " + userDetails.getUsername()));
            long count = questionRepository.countQuestionsByCriteria(skillId, diffId, catId, user.getId(), questionSourceType);
            return ResponseEntity.ok("{\"count\": " + count + "}");
        } catch (Exception e) {
            e.printStackTrace();
            return ResponseEntity.badRequest().body("{\"error\": \"" + e.getMessage() + "\"}");
        }
    }

    @PutMapping("/{id}/toggle-public")
    @PreAuthorize("hasAuthority('CREATE_AND_MANAGE_EXAMS_CM') or hasAuthority('MANAGE_ACCOUNTS_ROLES') or hasRole('ADMINISTRATOR')")
    public ResponseEntity<?> toggleMatrixStatus(
            @PathVariable Long id,
            @AuthenticationPrincipal UserDetails userDetails) {
        try {
            if (userDetails == null) {
                return ResponseEntity.status(401).body("{\"error\": \"Unauthorized\"}");
            }
            matrixService.toggleMatrixStatus(id);
            return ResponseEntity.ok("{\"message\": \"Matrix status toggled successfully\"}");
        } catch (Exception e) {
            e.printStackTrace();
            return ResponseEntity.badRequest().body("{\"error\": \"" + e.getMessage() + "\"}");
        }
    }

    @PutMapping("/{id}")
    @PreAuthorize("hasAuthority('CREATE_AND_MANAGE_EXAMS_CM') or hasAuthority('MANAGE_ACCOUNTS_ROLES') or hasRole('ADMINISTRATOR')")
    public ResponseEntity<?> updateMatrix(
            @PathVariable Long id,
            @AuthenticationPrincipal UserDetails userDetails,
            @RequestBody ExamMatrixCreateRequestDTO request) {
        try {
            if (userDetails == null) {
                return ResponseEntity.status(401).body("{\"error\": \"Unauthorized\"}");
            }
            matrixService.updateExamMatrix(id, request);
            return ResponseEntity.ok("{\"message\": \"Exam matrix updated successfully\"}");
        } catch (Exception e) {
            e.printStackTrace();
            return ResponseEntity.badRequest().body("{\"error\": \"" + e.getMessage() + "\"}");
        }
    }
}
