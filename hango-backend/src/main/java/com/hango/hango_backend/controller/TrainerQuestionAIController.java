package com.hango.hango_backend.controller;

import com.hango.hango_backend.dto.CreateTrainerQuestionAIRequestDTO;
import com.hango.hango_backend.dto.CreateTrainerQuestionAIResponseDTO;
import com.hango.hango_backend.dto.CreateTrainerExamAIResponseDTO;
import com.hango.hango_backend.dto.TrainerExamChatRequestDTO;
import com.hango.hango_backend.service.TrainerQuestionAIService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/v1/trainer/questions/ai")
@RequiredArgsConstructor
@CrossOrigin(origins = "*", maxAge = 3600)
public class TrainerQuestionAIController {

    private final TrainerQuestionAIService trainerQuestionAIService;

    @PostMapping("/generate")
    @PreAuthorize("hasAuthority('MANAGE_QUESTION_BANK') or hasAuthority('MANAGE_ACCOUNTS_ROLES') or hasRole('ADMINISTRATOR')")
    public ResponseEntity<CreateTrainerQuestionAIResponseDTO> generate(@RequestBody CreateTrainerQuestionAIRequestDTO request) {
        return ResponseEntity.ok(trainerQuestionAIService.generatePayload(request));
    }

    @PostMapping("/exams/chat")
    @PreAuthorize("hasAuthority('CREATE_EXAMS_TRAINER') or hasAuthority('CREATE_AND_MANAGE_EXAMS_CM') or hasAuthority('MANAGE_ACCOUNTS_ROLES') or hasRole('ADMINISTRATOR')")
    public ResponseEntity<String> chatExam(@RequestBody TrainerExamChatRequestDTO request) {
        return ResponseEntity.ok(trainerQuestionAIService.handleExamChat(request));
    }

    @PostMapping("/exams/generate-from-chat")
    @PreAuthorize("hasAuthority('CREATE_EXAMS_TRAINER') or hasAuthority('CREATE_AND_MANAGE_EXAMS_CM') or hasAuthority('MANAGE_ACCOUNTS_ROLES') or hasRole('ADMINISTRATOR')")
    public ResponseEntity<CreateTrainerExamAIResponseDTO> generateExamFromChat(@RequestBody TrainerExamChatRequestDTO request) {
        return ResponseEntity.ok(trainerQuestionAIService.generateExamFromChat(request));
    }
}

