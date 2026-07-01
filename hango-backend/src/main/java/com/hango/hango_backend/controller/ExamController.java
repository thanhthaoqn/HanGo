package com.hango.hango_backend.controller;

import com.hango.hango_backend.dto.ExamResponseDTO;
import com.hango.hango_backend.dto.ExamAttemptRequestDTO;
import com.hango.hango_backend.dto.ExamAttemptResponseDTO;
import com.hango.hango_backend.service.ExamService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;
import org.springframework.security.core.context.SecurityContextHolder;

import java.util.List;

@RestController
@RequestMapping("/api/v1/exams")
@RequiredArgsConstructor
public class ExamController {

    private final ExamService examService;

    private Long getCurrentUserId() {
        org.springframework.security.core.Authentication auth = SecurityContextHolder.getContext().getAuthentication();
        if (auth == null || !auth.isAuthenticated()) {
            return null;
        }
        Object principal = auth.getPrincipal();
        if (principal instanceof com.hango.hango_backend.sercurity.UserDetailsImpl) {
            return ((com.hango.hango_backend.sercurity.UserDetailsImpl) principal).getId();
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

    @GetMapping("/{id}/attempts")
    public ResponseEntity<List<ExamAttemptResponseDTO>> getExamAttempts(@PathVariable Long id) {
        Long currentUserId = getCurrentUserId();
        if (currentUserId == null) {
            return ResponseEntity.status(401).build();
        }
        List<ExamAttemptResponseDTO> attempts = examService.getExamAttempts(id, currentUserId);
        return ResponseEntity.ok(attempts);
    }

    @PostMapping("/{id}/submit")
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
}
