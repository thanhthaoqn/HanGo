package com.hango.hango_backend.controller;

import com.hango.hango_backend.dto.LessonDetailDTO;
import com.hango.hango_backend.service.LessonService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/v1/lessons")
@RequiredArgsConstructor
public class LessonController {

    private final LessonService lessonService;

    @GetMapping("/{id}")
    public ResponseEntity<LessonDetailDTO> getLessonDetail(@PathVariable Long id) {
        return ResponseEntity.ok(lessonService.getLessonDetail(id));
    }
}
