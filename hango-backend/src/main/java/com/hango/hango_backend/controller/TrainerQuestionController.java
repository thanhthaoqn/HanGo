package com.hango.hango_backend.controller;

import com.hango.hango_backend.dto.QuestionDTO;
import com.hango.hango_backend.dto.CreateGroupQuestionRequestDTO;
import com.hango.hango_backend.service.TrainerQuestionService;
import java.util.Map;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.web.bind.annotation.*;
import java.util.List;

@CrossOrigin(origins = "*", maxAge = 3600)
@RestController
@RequestMapping("/api/v1/trainer/question-bank")
@RequiredArgsConstructor
public class TrainerQuestionController {

    private final TrainerQuestionService trainerQuestionService;

    @GetMapping
    @PreAuthorize("hasAuthority('MANAGE_QUESTION_BANK') or hasAuthority('MANAGE_ACCOUNTS_ROLES') or hasRole('ADMINISTRATOR')")
    public ResponseEntity<List<QuestionDTO>> getQuestions(
            @AuthenticationPrincipal UserDetails userDetails,
            @RequestParam(defaultValue = "QUIZ") String type,
            @RequestParam(required = false) String search,
            @RequestParam(required = false) Long skillId,
            @RequestParam(required = false) Long categoryId,
            @RequestParam(required = false) Long difficultyId,
            @RequestParam(required = false) Integer usageType,
            @RequestParam(required = false) Long groupTypeId,
            @RequestParam(defaultValue = "NEWEST") String sortBy) {
        if (userDetails == null) {
            return ResponseEntity.status(401).build();
        }
        List<QuestionDTO> questions = trainerQuestionService.getTrainerQuestions(
                userDetails.getUsername(), type, search, sortBy, skillId, categoryId, difficultyId, usageType, groupTypeId);
        return ResponseEntity.ok(questions);
    }


    @PostMapping
    @PreAuthorize("hasAuthority('MANAGE_QUESTION_BANK') or hasAuthority('MANAGE_ACCOUNTS_ROLES') or hasRole('ADMINISTRATOR')")
    public ResponseEntity<Map<String, Object>> createQuestion(
            @AuthenticationPrincipal UserDetails userDetails,
            @RequestBody CreateGroupQuestionRequestDTO request) {
        if (userDetails == null) {
            return ResponseEntity.status(401).build();
        }
        Map<String, Object> response = trainerQuestionService.createQuestionBankGroup(userDetails.getUsername(), request);
        return ResponseEntity.ok(response);
    }

    @GetMapping("/detail/{id}")
    @PreAuthorize("hasAuthority('MANAGE_QUESTION_BANK') or hasAuthority('MANAGE_ACCOUNTS_ROLES') or hasRole('ADMINISTRATOR')")
    public ResponseEntity<CreateGroupQuestionRequestDTO> getQuestionDetail(
            @AuthenticationPrincipal UserDetails userDetails,
            @PathVariable Long id,
            @RequestParam(defaultValue = "false") boolean isGroup) {
        if (userDetails == null) {
            return ResponseEntity.status(401).build();
        }
        CreateGroupQuestionRequestDTO detail = trainerQuestionService.getQuestionDetail(userDetails.getUsername(), id, isGroup);
        return ResponseEntity.ok(detail);
    }

    @PutMapping("/{id}")
    @PreAuthorize("hasAuthority('MANAGE_QUESTION_BANK') or hasAuthority('MANAGE_ACCOUNTS_ROLES') or hasRole('ADMINISTRATOR')")
    public ResponseEntity<Map<String, Object>> updateQuestionBankGroup(
            @AuthenticationPrincipal UserDetails userDetails,
            @PathVariable Long id,
            @RequestParam(defaultValue = "false") boolean isGroup,
            @RequestBody CreateGroupQuestionRequestDTO request) {
        if (userDetails == null) {
            return ResponseEntity.status(401).build();
        }
        trainerQuestionService.updateQuestionBankGroup(userDetails.getUsername(), id, isGroup, request);
        return ResponseEntity.ok(Map.of("message", "Question updated successfully"));
    }

    @PatchMapping("/{id}/status")
    @PreAuthorize("hasAuthority('MANAGE_QUESTION_BANK') or hasAuthority('MANAGE_ACCOUNTS_ROLES') or hasRole('ADMINISTRATOR')")
    public ResponseEntity<Map<String, Object>> toggleQuestionStatus(
            @AuthenticationPrincipal UserDetails userDetails,
            @PathVariable Long id,
            @RequestParam String status,
            @RequestParam(defaultValue = "false") boolean isGroup) {
        if (userDetails == null) {
            return ResponseEntity.status(401).build();
        }
        trainerQuestionService.updateQuestionStatus(userDetails.getUsername(), id, status, isGroup);
        return ResponseEntity.ok(Map.of("message", "Status updated successfully"));
    }
    @GetMapping("/import-excel/template")
    @PreAuthorize("hasAuthority('MANAGE_QUESTION_BANK') or hasAuthority('MANAGE_ACCOUNTS_ROLES') or hasRole('ADMINISTRATOR')")
    public ResponseEntity<byte[]> downloadTemplate() {
        try {
            String fileName = "Hango_Question_Bank_Import_Template.xlsx";
            org.springframework.core.io.ClassPathResource resource = new org.springframework.core.io.ClassPathResource("templates/" + fileName);
            if (!resource.exists()) {
                throw new java.io.IOException("Template not found in classpath:templates/");
            }
            byte[] bytes = resource.getInputStream().readAllBytes();
            return ResponseEntity.ok()
                    .header("Content-Disposition", "attachment; filename=" + fileName)
                    .header("Content-Type", "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet")
                    .body(bytes);
        } catch (Exception e) {
            e.printStackTrace();
            return ResponseEntity.internalServerError().build();
        }
    }
}
