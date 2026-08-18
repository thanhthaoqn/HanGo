package com.hango.hango_backend.controller;

import com.hango.hango_backend.dto.ExamResponseDTO;
import com.hango.hango_backend.dto.ExamAttemptRequestDTO;
import com.hango.hango_backend.dto.ExamAttemptResponseDTO;
import com.hango.hango_backend.dto.LearnerExamQuestionDTO;
import com.hango.hango_backend.service.ExamService;
import com.hango.hango_backend.service.ExamResultAnalyzerService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.context.SecurityContextHolder;

import java.util.List;
import java.util.Map;

@RestController
@RequestMapping("/api/v1/exams")
@RequiredArgsConstructor
public class ExamController {

    private final ExamService examService;
    private final ExamResultAnalyzerService examResultAnalyzerService;

    private Long getCurrentUserId() {
        org.springframework.security.core.Authentication auth = SecurityContextHolder.getContext().getAuthentication();
        if (auth == null || !auth.isAuthenticated()) {
            return null;
        }
        Object principal = auth.getPrincipal();
        if (principal instanceof com.hango.hango_backend.security.UserDetailsImpl) {
            return ((com.hango.hango_backend.security.UserDetailsImpl) principal).getId();
        } else if (principal instanceof com.hango.hango_backend.entity.User) {
            return ((com.hango.hango_backend.entity.User) principal).getId();
        }
        return null;
    }

    @GetMapping
    public ResponseEntity<List<ExamResponseDTO>> getAllExams(
            @RequestParam(required = false, defaultValue = "All") String status) {
        List<ExamResponseDTO> exams = examService.getAllExams(status);
        return ResponseEntity.ok(exams);
    }
    
    @GetMapping("/{id}/questions")
    @PreAuthorize("hasAuthority('ATTEMPT_QUIZ_AND_EXAM') or hasAuthority('CREATE_EXAMS_TRAINER') or hasAuthority('CREATE_AND_MANAGE_EXAMS_CM') or hasAuthority('MANAGE_ACCOUNTS_ROLES') or hasRole('ADMINISTRATOR')")
    public ResponseEntity<List<LearnerExamQuestionDTO>> getExamQuestions(@PathVariable Long id) {
        List<LearnerExamQuestionDTO> questions = examService.getExamQuestions(id);
        return ResponseEntity.ok(questions);
    }

    @GetMapping("/my-attempts")
    @PreAuthorize("hasAuthority('ATTEMPT_QUIZ_AND_EXAM') or hasAuthority('MANAGE_ACCOUNTS_ROLES') or hasRole('ADMINISTRATOR')")
    public ResponseEntity<List<ExamAttemptResponseDTO>> getMyExamAttempts() {
        Long currentUserId = getCurrentUserId();
        if (currentUserId == null) {
            return ResponseEntity.status(401).build();
        }
        List<ExamAttemptResponseDTO> attempts = examService.getMyExamAttempts(currentUserId);
        return ResponseEntity.ok(attempts);
    }

    @GetMapping("/{id}/attempts")
    @PreAuthorize("hasAuthority('ATTEMPT_QUIZ_AND_EXAM') or hasAuthority('MANAGE_ACCOUNTS_ROLES') or hasRole('ADMINISTRATOR')")
    public ResponseEntity<List<ExamAttemptResponseDTO>> getExamAttempts(@PathVariable Long id) {
        Long currentUserId = getCurrentUserId();
        if (currentUserId == null) {
            return ResponseEntity.status(401).build();
        }
        List<ExamAttemptResponseDTO> attempts = examService.getExamAttempts(id, currentUserId);
        return ResponseEntity.ok(attempts);
    }

    @PostMapping("/{id}/submit")
    @PreAuthorize("hasAuthority('ATTEMPT_QUIZ_AND_EXAM') or hasAuthority('MANAGE_ACCOUNTS_ROLES') or hasRole('ADMINISTRATOR')")
    public ResponseEntity<ExamAttemptResponseDTO> submitExam(
            @PathVariable Long id,
            @RequestBody ExamAttemptRequestDTO request) {
        Long currentUserId = getCurrentUserId();
        if (currentUserId == null) {
            return ResponseEntity.status(401).build();
        }
        ExamAttemptResponseDTO response = examService.saveExamAttempt(id, currentUserId, request);
        return ResponseEntity.ok(response);
    }

    @GetMapping("/users/me/analytics/skills")
    @PreAuthorize("hasAuthority('ATTEMPT_QUIZ_AND_EXAM') or hasAuthority('MANAGE_ACCOUNTS_ROLES') or hasRole('ADMINISTRATOR')")
    public ResponseEntity<Map<String, Double>> getMySkillAnalytics() {
        Long currentUserId = getCurrentUserId();
        if (currentUserId == null) {
            return ResponseEntity.status(401).build();
        }
        Map<String, Double> analytics = examResultAnalyzerService.getSkillAnalytics(currentUserId);
        return ResponseEntity.ok(analytics);
    }
}
