package com.hango.hango_backend.controller;

import com.hango.hango_backend.dto.LessonDetailDTO;
import com.hango.hango_backend.dto.LessonQuizAttemptDTO;
import com.hango.hango_backend.dto.LessonQuizAttemptRequestDTO;
import com.hango.hango_backend.service.LessonService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;
import java.util.List;

@RestController
@RequestMapping("/api/v1/lessons")
@RequiredArgsConstructor
public class LessonController {

    private final LessonService lessonService;

    private Long getCurrentUserId() {
        org.springframework.security.core.Authentication auth = org.springframework.security.core.context.SecurityContextHolder.getContext().getAuthentication();
        if (auth != null && auth.getPrincipal() instanceof com.hango.hango_backend.sercurity.UserDetailsImpl) {
            return ((com.hango.hango_backend.sercurity.UserDetailsImpl) auth.getPrincipal()).getId();
        }
        return null;
    }

    @GetMapping("/{id}")
    public ResponseEntity<LessonDetailDTO> getLessonDetail(
            @PathVariable Long id,
            @RequestParam(required = false) Long userId) {
        Long currentUserId = userId;
        if (currentUserId == null) {
            currentUserId = getCurrentUserId();
        }
        return ResponseEntity.ok(lessonService.getLessonDetail(id, currentUserId));
    }

    @PutMapping("/{id}/complete")
    public ResponseEntity<?> completeLesson(
            @PathVariable Long id,
            @RequestParam(required = false) Long userId,
            @RequestParam(required = false, defaultValue = "true") boolean completed) {
        Long currentUserId = userId;
        if (currentUserId == null) {
            currentUserId = getCurrentUserId();
        }
        if (currentUserId == null) {
            return ResponseEntity.status(401).body("{\"error\": \"Unauthorized\"}");
        }
        lessonService.completeLesson(id, currentUserId, completed);
        return ResponseEntity.ok().body("{\"message\": \"Lesson progress updated successfully\"}");
    }

    @GetMapping("/{id}/quiz-attempts")
    public ResponseEntity<List<LessonQuizAttemptDTO>> getQuizAttempts(
            @PathVariable Long id,
            @RequestParam Long userId) {
        return ResponseEntity.ok(lessonService.getQuizAttempts(id, userId));
    }

    @PostMapping("/{id}/quiz-attempts")
    public ResponseEntity<LessonQuizAttemptDTO> saveQuizAttempt(
            @PathVariable Long id,
            @RequestParam Long userId,
            @RequestBody LessonQuizAttemptRequestDTO request) {
        return ResponseEntity.ok(lessonService.saveQuizAttempt(id, userId, request));
    }
}
