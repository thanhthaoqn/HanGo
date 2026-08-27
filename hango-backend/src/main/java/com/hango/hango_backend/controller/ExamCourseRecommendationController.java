package com.hango.hango_backend.controller;

import com.hango.hango_backend.dto.ExamCourseRecommendationAIRequestDTO;
import com.hango.hango_backend.dto.ExamCourseRecommendationAIResponseDTO;
import com.hango.hango_backend.service.ExamCourseRecommendationAIService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.web.bind.annotation.*;

import com.hango.hango_backend.security.UserDetailsImpl;
import com.hango.hango_backend.entity.User;

@RestController
@RequestMapping("/api/v1/exams")
@RequiredArgsConstructor
public class ExamCourseRecommendationController {

    private final ExamCourseRecommendationAIService aiService;

    private Long getCurrentUserId() {
        var auth = SecurityContextHolder.getContext().getAuthentication();
        if (auth == null || !auth.isAuthenticated()) return null;
        Object principal = auth.getPrincipal();
        if (principal instanceof User) return ((User) principal).getId();
        if (principal instanceof UserDetailsImpl) return ((UserDetailsImpl) principal).getId();
        return null;
    }

    /**
     * AI recommend courses after exam.
     * FE send examAttemptId.
     */
    @PostMapping("/ai/recommend-courses")
    public ResponseEntity<ExamCourseRecommendationAIResponseDTO> recommendCoursesAI(
            @RequestBody ExamCourseRecommendationAIRequestDTO request
    ) {
        Long userId = getCurrentUserId();
        if (userId == null) {
            return ResponseEntity.status(HttpStatus.UNAUTHORIZED).build();
        }

        // Spec 20 - E6: kiem tra attempt co thuoc ve user dang login (service tu throw 403)
        ExamCourseRecommendationAIResponseDTO resp = aiService.recommendCoursesAI(
                request.getExamAttemptId(), request.getWeakestSkill(), userId);
        return ResponseEntity.ok(resp);
    }
}

