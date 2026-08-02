package com.hango.hango_backend.controller;

import com.hango.hango_backend.dto.CreateTrainerQuestionAIRequestDTO;
import com.hango.hango_backend.dto.CreateTrainerQuestionAIResponseDTO;
import com.hango.hango_backend.dto.CreateTrainerExamAIResponseDTO;
import com.hango.hango_backend.dto.TrainerExamChatRequestDTO;
import com.hango.hango_backend.service.TrainerQuestionAIService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/v1/trainer/questions/ai")
@RequiredArgsConstructor
@CrossOrigin(origins = "*", maxAge = 3600)
public class TrainerQuestionAIController {

    private final TrainerQuestionAIService trainerQuestionAIService;

    @PostMapping("/generate")
    public ResponseEntity<CreateTrainerQuestionAIResponseDTO> generate(@RequestBody CreateTrainerQuestionAIRequestDTO request) {
        return ResponseEntity.ok(trainerQuestionAIService.generatePayload(request));
    }

    @PostMapping("/exams/chat")
    public ResponseEntity<String> chatExam(@RequestBody TrainerExamChatRequestDTO request) {
        return ResponseEntity.ok(trainerQuestionAIService.handleExamChat(request));
    }

    @PostMapping("/exams/generate-from-chat")
    public ResponseEntity<CreateTrainerExamAIResponseDTO> generateExamFromChat(@RequestBody TrainerExamChatRequestDTO request) {
        return ResponseEntity.ok(trainerQuestionAIService.generateExamFromChat(request));
    }
}

