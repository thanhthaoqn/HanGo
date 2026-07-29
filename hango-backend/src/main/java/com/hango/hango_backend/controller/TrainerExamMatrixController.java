package com.hango.hango_backend.controller;

import com.hango.hango_backend.dto.ExamMatrixCreateRequestDTO;
import com.hango.hango_backend.dto.ExamMatrixDTO;
import com.hango.hango_backend.repository.QuestionRepository;
import com.hango.hango_backend.service.TrainerExamMatrixService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.Map;

@RestController
@RequestMapping("/api/v1/trainer/matrices")
@RequiredArgsConstructor
public class TrainerExamMatrixController {

    private final TrainerExamMatrixService matrixService;
    private final QuestionRepository questionRepository;

    @GetMapping
    @PreAuthorize("hasAnyRole('TRAINER', 'ADMINISTRATOR', 'COURSE_MANAGER', 'COURSE_MANAGER')")
    public ResponseEntity<List<ExamMatrixDTO>> getAllMatrices(
            @AuthenticationPrincipal UserDetails userDetails) {
        if (userDetails == null) {
            return ResponseEntity.status(401).build();
        }
        return ResponseEntity.ok(matrixService.getAllExamMatrices());
    }

    @PostMapping
    @PreAuthorize("hasAnyRole('ADMINISTRATOR', 'COURSE_MANAGER')")
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
    @PreAuthorize("hasAnyRole('TRAINER', 'ADMINISTRATOR', 'COURSE_MANAGER', 'COURSE_MANAGER')")
    public ResponseEntity<?> generateExamFromMatrix(
            @PathVariable Long id,
            @AuthenticationPrincipal UserDetails userDetails,
            @RequestBody Map<String, String> request) {
        try {
            if (userDetails == null) {
                return ResponseEntity.status(401).body("{\"error\": \"Unauthorized\"}");
            }
            String title = request.get("title");
            Long generatedExamId = matrixService.generateExamFromMatrix(id, title, userDetails.getUsername());
            return ResponseEntity.ok("{\"examId\": " + generatedExamId + ", \"message\": \"Exam generated successfully\"}");
        } catch (Exception e) {
            e.printStackTrace();
            return ResponseEntity.badRequest().body("{\"error\": \"" + e.getMessage() + "\"}");
        }
    }

    @GetMapping("/count-available")
    @PreAuthorize("hasAnyRole('COURSE_MANAGER', 'ADMINISTRATOR')")
    public ResponseEntity<?> countAvailableQuestions(
            @RequestParam Long skillId,
            @RequestParam Long diffId,
            @RequestParam Long catId) {
        try {
            long count = questionRepository.countQuestionsByCriteria(skillId, diffId, catId);
            return ResponseEntity.ok("{\"count\": " + count + "}");
        } catch (Exception e) {
            e.printStackTrace();
            return ResponseEntity.badRequest().body("{\"error\": \"" + e.getMessage() + "\"}");
        }
    }
}
