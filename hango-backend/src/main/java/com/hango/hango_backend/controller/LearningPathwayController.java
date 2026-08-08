package com.hango.hango_backend.controller;

import com.hango.hango_backend.dto.LearningPathwayResponseDTO;
import com.hango.hango_backend.dto.PathwayGenerateRequestDTO;
import com.hango.hango_backend.dto.PathwayScheduleRequestDTO;
import com.hango.hango_backend.dto.PathwayChatRequestDTO;
import com.hango.hango_backend.dto.PathwayChatResponseDTO;
import com.hango.hango_backend.dto.ProgressSnapshotDTO;
import com.hango.hango_backend.dto.PathwayRerouteSuggestionDTO;
import com.hango.hango_backend.entity.LearningPathway;
import com.hango.hango_backend.service.LearningPathwayService;
import com.hango.hango_backend.service.PathwayProgressSnapshotService;
import com.hango.hango_backend.service.PathwayReroutePolicyService;
import com.hango.hango_backend.service.PathwayMutationService;
import com.hango.hango_backend.service.PathwayMentorChatService;
import com.hango.hango_backend.repository.LearningPathwayRepository;
import com.hango.hango_backend.exception.ApiException;
import com.hango.hango_backend.security.UserDetailsImpl;
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
    private final PathwayMentorChatService mentorChatService;
    private final LearningPathwayRepository pathwayRepository;

    @PostMapping("/generate")
    @PreAuthorize("hasAuthority('ENROLL_AND_LEARN_COURSES')")
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
    @PreAuthorize("hasAuthority('ENROLL_AND_LEARN_COURSES')")
    public ResponseEntity<LearningPathwayResponseDTO> getPathwayById(
            @PathVariable Long id,
            @AuthenticationPrincipal UserDetailsImpl userDetails) {

        LearningPathwayResponseDTO response = learningPathwayService.getPathwayById(id, userDetails.getId());
        return ResponseEntity.ok(response);
    }

    @GetMapping("/me")
    @PreAuthorize("hasAuthority('ENROLL_AND_LEARN_COURSES')")
    public ResponseEntity<LearningPathwayResponseDTO> getMyPathway(
            @AuthenticationPrincipal UserDetailsImpl userDetails) {
        
        LearningPathwayResponseDTO response = learningPathwayService.getMyPathway(userDetails.getId());
        return ResponseEntity.ok(response);
    }

    @PutMapping("/{id}/reroute")
    @PreAuthorize("hasAuthority('ENROLL_AND_LEARN_COURSES')")
    public ResponseEntity<LearningPathwayResponseDTO> reroutePathway(
            @PathVariable Long id,
            @AuthenticationPrincipal UserDetailsImpl userDetails) {

        LearningPathwayResponseDTO response = learningPathwayService.reroutePathway(id, userDetails.getId());
        return ResponseEntity.ok(response);
    }

    // Feature B: Smart Time-boxing
    @PutMapping("/{id}/schedule")
    @PreAuthorize("hasAuthority('ENROLL_AND_LEARN_COURSES')")
    public ResponseEntity<LearningPathwayResponseDTO> applySchedule(
            @PathVariable Long id,
            @AuthenticationPrincipal UserDetailsImpl userDetails,
            @Valid @RequestBody PathwayScheduleRequestDTO requestDTO) {
        
        return ResponseEntity.ok(learningPathwayService.applySchedule(id, userDetails.getId(), requestDTO));
    }

    // Feature Phase 2: Mastery
    @PostMapping("/{id}/nodes/{nodeId}/mastery")
    @PreAuthorize("hasAuthority('ENROLL_AND_LEARN_COURSES')")
    public ResponseEntity<LearningPathwayResponseDTO> submitMastery(
            @PathVariable Long id,
            @PathVariable Long nodeId,
            @AuthenticationPrincipal UserDetailsImpl userDetails,
            @RequestBody com.hango.hango_backend.dto.MasterySubmitRequestDTO requestDTO) {
        
        return ResponseEntity.ok(learningPathwayService.submitNodeMastery(id, nodeId, userDetails.getId(), requestDTO));
    }

    /**
     * @deprecated Use schedule_status field from GET /pathways/{id} or GET /pathways/me instead.
     */
    @Deprecated
    @GetMapping("/{id}/schedule-status")
    @PreAuthorize("hasAuthority('ENROLL_AND_LEARN_COURSES')")
    public ResponseEntity<String> getScheduleStatus(
            @PathVariable Long id,
            @AuthenticationPrincipal UserDetailsImpl userDetails) {
        
        return ResponseEntity.ok("{\"status\": \"" + learningPathwayService.getScheduleStatus(id, userDetails.getId()) + "\"}");
    }

    // FE-11 agentic reroute contract (Feature A)
    @GetMapping("/{id}/progress-snapshot")
    @PreAuthorize("hasAuthority('ENROLL_AND_LEARN_COURSES')")
    public ResponseEntity<ProgressSnapshotDTO> progressSnapshot(
            @PathVariable Long id,
            @AuthenticationPrincipal UserDetailsImpl userDetails) {
        return ResponseEntity.ok(progressSnapshotService.getProgressSnapshot(id, userDetails.getId()));
    }

    @PostMapping("/{id}/reroute/suggestions")
    @PreAuthorize("hasAuthority('ENROLL_AND_LEARN_COURSES')")
    public ResponseEntity<LearningPathwayResponseDTO> rerouteSuggestions(
            @PathVariable Long id,
            @AuthenticationPrincipal UserDetailsImpl userDetails) {
        
        ProgressSnapshotDTO snapshot = progressSnapshotService.getProgressSnapshot(id, userDetails.getId());
        PathwayReroutePolicyService.PolicyDecision decision = reroutePolicyService.evaluate(snapshot);
        
        PathwayRerouteSuggestionDTO dto = new PathwayRerouteSuggestionDTO();
        dto.setNodeType(mapPolicyActionToNodeType(decision.action));
        dto.setRerouteReason(decision.reason != null
                ? decision.reason
                : "Your current pathway still matches your latest progress. No adjustment is needed right now.");
        dto.setCanSkip(decision.action == PathwayReroutePolicyService.PolicyAction.FAST_TRACK_ELIGIBLE);
        dto.setBlockedReason(decision.action == PathwayReroutePolicyService.PolicyAction.DETOUR_REQUIRED ? decision.reason : null);

        LearningPathwayResponseDTO response = learningPathwayService.getPathwayById(id, userDetails.getId());
        if (decision.action != PathwayReroutePolicyService.PolicyAction.NO_CHANGE) {
            response.setPendingRerouteSuggestion(dto);
        }
        return ResponseEntity.ok(response);
    }

    private String mapPolicyActionToNodeType(PathwayReroutePolicyService.PolicyAction action) {
        if (action == PathwayReroutePolicyService.PolicyAction.FAST_TRACK_ELIGIBLE) {
            return "FAST_TRACK_SKIPPED";
        }
        if (action == PathwayReroutePolicyService.PolicyAction.DETOUR_REQUIRED) {
            return "DETOUR_REMEDIAL";
        }
        return "NORMAL";
    }

    @PostMapping("/{id}/reroute/accept")
    @PreAuthorize("hasAuthority('ENROLL_AND_LEARN_COURSES')")
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
    @PreAuthorize("hasAuthority('ENROLL_AND_LEARN_COURSES')")
    public ResponseEntity<LearningPathwayResponseDTO> rerouteDecline(
            @PathVariable Long id,
            @AuthenticationPrincipal UserDetailsImpl userDetails) {
        // Just return current if declined
        return ResponseEntity.ok(learningPathwayService.getPathwayById(id, userDetails.getId()));
    }

    @PostMapping("/{id}/mentor-action")
    @PreAuthorize("hasAuthority('ENROLL_AND_LEARN_COURSES')")
    public ResponseEntity<LearningPathwayResponseDTO> mentorAction(
            @PathVariable Long id,
            @AuthenticationPrincipal UserDetailsImpl userDetails,
            @Valid @RequestBody com.hango.hango_backend.dto.MentorActionRequestDTO requestDTO) {
        
        LearningPathwayResponseDTO response = learningPathwayService.processMentorAction(id, userDetails.getId(), requestDTO);
        return ResponseEntity.ok(response);
    }

    // ===================== FREE-FORM AI CHAT =====================

    @PostMapping("/{id}/chat")
    @PreAuthorize("hasAuthority('ENROLL_AND_LEARN_COURSES')")
    public ResponseEntity<PathwayChatResponseDTO> chat(
            @PathVariable Long id,
            @AuthenticationPrincipal UserDetailsImpl userDetails,
            @Valid @RequestBody PathwayChatRequestDTO requestDTO) {

        PathwayChatResponseDTO response = mentorChatService.chat(id, userDetails.getId(), requestDTO);
        return ResponseEntity.ok(response);
    }

    @GetMapping("/{id}/chat/history")
    @PreAuthorize("hasAuthority('ENROLL_AND_LEARN_COURSES')")
    public ResponseEntity<java.util.List<PathwayChatResponseDTO>> getChatHistory(
            @PathVariable Long id,
            @AuthenticationPrincipal UserDetailsImpl userDetails) {

        return ResponseEntity.ok(mentorChatService.getChatHistory(id, userDetails.getId()));
    }

    @DeleteMapping("/{id}/chat/history")
    @PreAuthorize("hasAuthority('ENROLL_AND_LEARN_COURSES')")
    public ResponseEntity<Void> clearChatHistory(
            @PathVariable Long id,
            @AuthenticationPrincipal UserDetailsImpl userDetails) {

        mentorChatService.clearChatHistory(id, userDetails.getId());
        return ResponseEntity.ok().build();
    }
}
