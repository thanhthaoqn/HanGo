package com.hango.hango_backend.controller;

import com.hango.hango_backend.dto.ExamResponseDTO;
import com.hango.hango_backend.service.ExamService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;

@RestController
@RequestMapping("/api/v1/exams")
@RequiredArgsConstructor
public class ExamController {

    private final ExamService examService;

    @GetMapping
    public ResponseEntity<List<ExamResponseDTO>> getAllExams(
            @RequestParam(required = false, defaultValue = "All") String status) {
        List<ExamResponseDTO> exams = examService.getAllExams(status);
        return ResponseEntity.ok(exams);
    }
}
