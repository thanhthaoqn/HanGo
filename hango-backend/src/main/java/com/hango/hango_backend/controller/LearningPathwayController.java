package com.hango.hango_backend.controller;

import com.hango.hango_backend.dto.LearningPathwayResponseDTO;
import com.hango.hango_backend.dto.PathwayGenerateRequestDTO;
import com.hango.hango_backend.service.LearningPathwayService;
import com.hango.hango_backend.sercurity.UserDetailsImpl;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/v1/pathways")
@RequiredArgsConstructor
public class LearningPathwayController {

    private final LearningPathwayService learningPathwayService;

    @PostMapping("/generate")
    @PreAuthorize("hasRole('LEARNER')")
    public ResponseEntity<LearningPathwayResponseDTO> generatePathway(
            @AuthenticationPrincipal UserDetailsImpl userDetails,
            @Valid @RequestBody PathwayGenerateRequestDTO requestDTO) {
        
        LearningPathwayResponseDTO response = learningPathwayService.generatePathway(userDetails.getId(), requestDTO.getExamAttemptId());
        return ResponseEntity.ok(response);
    }

    @GetMapping("/{id}")
    @PreAuthorize("hasRole('LEARNER')")
    public ResponseEntity<LearningPathwayResponseDTO> getPathwayById(
            @PathVariable Long id,
            @AuthenticationPrincipal UserDetailsImpl userDetails) {

        LearningPathwayResponseDTO response = learningPathwayService.getPathwayById(id, userDetails.getId());
        return ResponseEntity.ok(response);
    }

    @GetMapping("/me")
    @PreAuthorize("hasRole('LEARNER')")
    public ResponseEntity<LearningPathwayResponseDTO> getMyPathway(
            @AuthenticationPrincipal UserDetailsImpl userDetails) {
        
        LearningPathwayResponseDTO response = learningPathwayService.getMyPathway(userDetails.getId());
        return ResponseEntity.ok(response);
    }

    @PutMapping("/{id}/reroute")
    @PreAuthorize("hasRole('LEARNER')")
    public ResponseEntity<LearningPathwayResponseDTO> reroutePathway(
            @PathVariable Long id,
            @AuthenticationPrincipal UserDetailsImpl userDetails,
            @RequestParam(defaultValue = "0") int quizScore) {

        LearningPathwayResponseDTO response = learningPathwayService.reroutePathway(id, userDetails.getId(), quizScore);
        return ResponseEntity.ok(response);
    }

    @PostMapping("/{id}/chat")
    @PreAuthorize("hasRole('LEARNER')")
    public ResponseEntity<String> chatWithMentor(
            @PathVariable Long id,
            @AuthenticationPrincipal UserDetailsImpl userDetails,
            @Valid @RequestBody com.hango.hango_backend.dto.PathwayChatRequestDTO requestDTO) {
        
        String response = learningPathwayService.chatWithMentor(id, userDetails.getId(), requestDTO.getMessage());
        return ResponseEntity.ok(response);
    }
}
