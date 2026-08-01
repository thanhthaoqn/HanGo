package com.hango.hango_backend.controller;

import com.hango.hango_backend.dto.LessonDetailDTO;
import com.hango.hango_backend.dto.LessonDetailDTO;
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
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import com.hango.hango_backend.security.UserDetailsImpl;
import com.hango.hango_backend.security.UserDetailsImpl;

@RestController
@RequestMapping("/api/v1/lessons")
@RequiredArgsConstructor
public class LessonController {

    private final LessonService lessonService;



    @GetMapping("/{id}")
    public ResponseEntity<LessonDetailDTO> getLessonDetail(
            @PathVariable Long id,
            @AuthenticationPrincipal UserDetailsImpl currentUser) {
        Long currentUserId = currentUser != null ? currentUser.getId() : null;
        return ResponseEntity.ok(lessonService.getLessonDetail(id, currentUserId));
    }

    @PutMapping("/{id}/complete")
    public ResponseEntity<?> completeLesson(
            @PathVariable Long id,
            @AuthenticationPrincipal UserDetailsImpl currentUser,
            @RequestParam(required = false, defaultValue = "true") boolean completed) {
        if (currentUser == null) {
            return ResponseEntity.status(401).body("{\"error\": \"Unauthorized\"}");
        }
        lessonService.completeLesson(id, currentUser.getId(), completed);
        return ResponseEntity.ok().body("{\"message\": \"Lesson progress updated successfully\"}");
    }

    @GetMapping("/{id}/quiz-attempts")
    public ResponseEntity<?> getQuizAttempts(
            @PathVariable Long id,
            @AuthenticationPrincipal UserDetailsImpl currentUser) {
        if (currentUser == null) {
            return ResponseEntity.status(401).body("{\"error\": \"Unauthorized\"}");
        }
        return ResponseEntity.ok(lessonService.getQuizAttempts(id, currentUser.getId()));
    }

    @PostMapping("/{id}/quiz-attempts")
    public ResponseEntity<?> saveQuizAttempt(
            @PathVariable Long id,
            @AuthenticationPrincipal UserDetailsImpl currentUser,
            @RequestBody LessonQuizAttemptRequestDTO request) {
        if (currentUser == null) {
            return ResponseEntity.status(401).body("{\"error\": \"Unauthorized\"}");
        }
        return ResponseEntity.ok(lessonService.saveQuizAttempt(id, currentUser.getId(), request));
    }
}
