package com.hango.hango_backend.controller;

import com.hango.hango_backend.dto.QuestionDTO;
import com.hango.hango_backend.service.TrainerQuestionService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.web.bind.annotation.*;
import java.util.List;

@CrossOrigin(origins = "*", maxAge = 3600)
@RestController
@RequestMapping("/api/v1/trainer/questions")
@RequiredArgsConstructor
public class TrainerQuestionController {

    private final TrainerQuestionService trainerQuestionService;

    @GetMapping
    @PreAuthorize("hasAnyRole('TRAINER', 'ADMINISTRATOR', 'TRAINER_LEAD')")
    public ResponseEntity<List<QuestionDTO>> getQuestions(
            @AuthenticationPrincipal UserDetails userDetails,
            @RequestParam(defaultValue = "QUIZ") String type,
            @RequestParam(required = false) String search,
            @RequestParam(defaultValue = "NEWEST") String sortBy) {
        if (userDetails == null) {
            return ResponseEntity.status(401).build();
        }
        List<QuestionDTO> questions = trainerQuestionService.getTrainerQuestions(
                userDetails.getUsername(), type, search, sortBy);
        return ResponseEntity.ok(questions);
    }
}
