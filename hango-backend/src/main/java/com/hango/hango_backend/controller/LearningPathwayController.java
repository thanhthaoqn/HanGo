package com.hango.hango_backend.controller;

import com.hango.hango_backend.dto.LearningPathwayResponseDTO;
import com.hango.hango_backend.dto.PathwayGenerateRequestDTO;
import com.hango.hango_backend.dto.PathwayScheduleRequestDTO;
import com.hango.hango_backend.dto.ProgressSnapshotDTO;
import com.hango.hango_backend.dto.PathwayRerouteSuggestionDTO;
import com.hango.hango_backend.dto.MergePreviewDTO;
import com.hango.hango_backend.entity.LearningPathway;
import com.hango.hango_backend.service.LearningPathwayService;
import com.hango.hango_backend.service.PathwayProgressSnapshotService;
import com.hango.hango_backend.service.PathwayReroutePolicyService;
import com.hango.hango_backend.service.PathwayMutationService;
import com.hango.hango_backend.service.PathwayGoalMergeService;
import com.hango.hango_backend.repository.LearningPathwayRepository;
import com.hango.hango_backend.exeption.ApiException;
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
    private final PathwayProgressSnapshotService progressSnapshotService;
    private final PathwayReroutePolicyService reroutePolicyService;
    private final PathwayMutationService mutationService;
    private final PathwayGoalMergeService goalMergeService;
    private final LearningPathwayRepository pathwayRepository;

    @PostMapping("/generate")
    @PreAuthorize("hasRole('LEARNER')")
    public ResponseEntity<LearningPathwayResponseDTO> generatePathway(
            @AuthenticationPrincipal UserDetailsImpl userDetails,
            @Valid @RequestBody PathwayGenerateRequestDTO requestDTO) {

        // Feature B: planning inputs (nullable for now)
        LearningPathwayResponseDTO response = learningPathwayService.generatePathway(
                userDetails.getId(),
                requestDTO);

        // Planning inputs are accepted in request DTO (Feature B contract-first)
        // but not yet used by scheduling logic.

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
    @PreAuthorize("hasRole('LEARNER') or hasRole('TRAINER') or hasRole('ADMINISTRATOR') or hasRole('TRAINER_LEAD') or hasRole('COURSE_MANAGER')")
    public ResponseEntity<LearningPathwayResponseDTO> getMyPathway(
            @AuthenticationPrincipal UserDetailsImpl userDetails) {
        
        LearningPathwayResponseDTO response = learningPathwayService.getMyPathway(userDetails.getId());
        return ResponseEntity.ok(response);
    }

    @PutMapping("/{id}/reroute")
    @PreAuthorize("hasRole('LEARNER')")
    public ResponseEntity<LearningPathwayResponseDTO> reroutePathway(
            @PathVariable Long id,
            @AuthenticationPrincipal UserDetailsImpl userDetails) {

        LearningPathwayResponseDTO response = learningPathwayService.reroutePathway(id, userDetails.getId());
        return ResponseEntity.ok(response);
    }

    // Feature B: Smart Time-boxing
    @PutMapping("/{id}/schedule")
    @PreAuthorize("hasRole('LEARNER')")
    public ResponseEntity<LearningPathwayResponseDTO> applySchedule(
            @PathVariable Long id,
            @AuthenticationPrincipal UserDetailsImpl userDetails,
            @Valid @RequestBody PathwayScheduleRequestDTO requestDTO) {
        
        return ResponseEntity.ok(learningPathwayService.applySchedule(id, userDetails.getId(), requestDTO));
    }

    @GetMapping("/{id}/schedule-status")
    @PreAuthorize("hasRole('LEARNER')")
    public ResponseEntity<String> getScheduleStatus(
            @PathVariable Long id,
            @AuthenticationPrincipal UserDetailsImpl userDetails) {
        
        return ResponseEntity.ok("{\"status\": \"" + learningPathwayService.getScheduleStatus(id, userDetails.getId()) + "\"}");
    }

    // FE-11 agentic reroute contract (Feature A)
    @GetMapping("/{id}/progress-snapshot")
    @PreAuthorize("hasRole('LEARNER')")
    public ResponseEntity<ProgressSnapshotDTO> progressSnapshot(
            @PathVariable Long id,
            @AuthenticationPrincipal UserDetailsImpl userDetails) {
        return ResponseEntity.ok(progressSnapshotService.getProgressSnapshot(id, userDetails.getId()));
    }

    @PostMapping("/{id}/reroute/suggestions")
    @PreAuthorize("hasRole('LEARNER')")
    public ResponseEntity<PathwayRerouteSuggestionDTO> rerouteSuggestions(
            @PathVariable Long id,
            @AuthenticationPrincipal UserDetailsImpl userDetails) {
        
        ProgressSnapshotDTO snapshot = progressSnapshotService.getProgressSnapshot(id, userDetails.getId());
        PathwayReroutePolicyService.PolicyDecision decision = reroutePolicyService.evaluate(snapshot);
        
        PathwayRerouteSuggestionDTO dto = new PathwayRerouteSuggestionDTO();
        dto.setNodeType(decision.action.name());
        dto.setRerouteReason(decision.reason);
        dto.setCanSkip(decision.action == PathwayReroutePolicyService.PolicyAction.FAST_TRACK_ELIGIBLE);
        dto.setBlockedReason(decision.action == PathwayReroutePolicyService.PolicyAction.DETOUR_REQUIRED ? decision.reason : null);
        
        return ResponseEntity.ok(dto);
    }

    @PostMapping("/{id}/reroute/accept")
    @PreAuthorize("hasRole('LEARNER')")
    public ResponseEntity<LearningPathwayResponseDTO> rerouteAccept(
            @PathVariable Long id,
            @AuthenticationPrincipal UserDetailsImpl userDetails) {
        
        LearningPathway pathway = pathwayRepository.findById(id)
                .orElseThrow(() -> new ApiException("Pathway not found", org.springframework.http.HttpStatus.NOT_FOUND));
        if (!pathway.getStudent().getId().equals(userDetails.getId())) {
            throw new ApiException("Access denied", org.springframework.http.HttpStatus.FORBIDDEN);
        }

        ProgressSnapshotDTO snapshot = progressSnapshotService.getProgressSnapshot(id, userDetails.getId());
        PathwayReroutePolicyService.PolicyDecision decision = reroutePolicyService.evaluate(snapshot);

        if (decision.action == PathwayReroutePolicyService.PolicyAction.FAST_TRACK_ELIGIBLE) {
            mutationService.applyFastTrackSkip(pathway, decision.targetNode.getNodeId(), decision.reason);
        } else if (decision.action == PathwayReroutePolicyService.PolicyAction.DETOUR_REQUIRED) {
            // Need a real remedial course. Using target node's course id as placeholder.
            // Normally this calls a tool suggestRemedialCourseOrLesson
            mutationService.applyDetourInsertion(pathway, decision.targetNode.getNodeId(), pathway.getNodes().get(0).getCourse(), decision.reason);
        }

        return ResponseEntity.ok(learningPathwayService.getPathwayById(id, userDetails.getId()));
    }

    @PostMapping("/{id}/reroute/decline")
    @PreAuthorize("hasRole('LEARNER')")
    public ResponseEntity<LearningPathwayResponseDTO> rerouteDecline(
            @PathVariable Long id,
            @AuthenticationPrincipal UserDetailsImpl userDetails) {
        // Just return current if declined
        return ResponseEntity.ok(learningPathwayService.getPathwayById(id, userDetails.getId()));
    }

    // Feature C: Multi-goal Merging
    @PostMapping("/merge-preview")
    @PreAuthorize("hasRole('LEARNER')")
    public ResponseEntity<MergePreviewDTO> mergePreview(
            @AuthenticationPrincipal UserDetailsImpl userDetails,
            @RequestBody java.util.List<Long> courseIds) {
        return ResponseEntity.ok(goalMergeService.mergePreview(courseIds));
    }

    @PostMapping("/{id}/merge-confirm")
    @PreAuthorize("hasRole('LEARNER')")
    public ResponseEntity<LearningPathwayResponseDTO> mergeConfirm(
            @PathVariable Long id,
            @AuthenticationPrincipal UserDetailsImpl userDetails,
            @RequestBody MergePreviewDTO previewDTO) {
        
        goalMergeService.mergeConfirm(id, userDetails.getId(), previewDTO);
        return ResponseEntity.ok(learningPathwayService.getPathwayById(id, userDetails.getId()));
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
