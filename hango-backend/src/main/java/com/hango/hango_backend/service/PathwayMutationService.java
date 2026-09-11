package com.hango.hango_backend.service;

import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.hango.hango_backend.entity.Course;
import com.hango.hango_backend.entity.LearningPathway;
import com.hango.hango_backend.entity.PathwayEvent;
import com.hango.hango_backend.entity.PathwayNode;
import com.hango.hango_backend.repository.PathwayEventRepository;
import com.hango.hango_backend.repository.PathwayNodeRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDateTime;
import java.util.List;

@Service
@RequiredArgsConstructor
@Slf4j
public class PathwayMutationService {

    private final PathwayEventRepository eventRepository;
    private final PathwayNodeRepository nodeRepository;
    private final ObjectMapper objectMapper;

    @Transactional
    public void applyFastTrackSkip(LearningPathway pathway, Long targetNodeId, String reason) {
        // Skip node: danh dau COMPLETED + luu ly do, dong thoi mo khoa node ke tiep
        PathwayNode nodeToSkip = pathway.getNodes().stream()
                .filter(n -> n.getId().equals(targetNodeId))
                .findFirst()
                .orElseThrow(() -> new IllegalArgumentException("Node not found in pathway"));

        String beforeJson = toJson(pathway.getNodes());

        nodeToSkip.setNodeType("FAST_TRACK_SKIPPED");
        nodeToSkip.setRerouteReason(reason);
        nodeToSkip.setIsOptional(true);
        nodeToSkip.setSkippedAt(LocalDateTime.now());
        nodeToSkip.setStatus("COMPLETED");

        // Unlock next node
        pathway.getNodes().stream()
                .filter(n -> n.getStepOrder() == nodeToSkip.getStepOrder() + 1)
                .findFirst()
                .ifPresent(next -> {
                    if ("LOCKED".equalsIgnoreCase(next.getStatus())) {
                        next.setStatus("IN_PROGRESS");
                        nodeRepository.save(next);
                    }
                });

        nodeRepository.save(nodeToSkip);

        logEvent(pathway.getId(), pathway.getStudent().getId(), "FAST_TRACK_SKIP", beforeJson, toJson(pathway.getNodes()), reason);
    }

    @Transactional
    public void applyDetourInsertion(LearningPathway pathway, Long targetNodeId, Course remedialCourse, String reason) {
        // P0 phanh detour: toi da 3 detour/pathway, 1 detour/parent
        long detourCount = pathway.getNodes().stream().filter(n -> "DETOUR_REMEDIAL".equals(n.getNodeType())).count();
        if (detourCount >= 3) throw new IllegalStateException("Pathway already has maximum 3 remedial courses. Please seek tutor support.");
        if (remedialCourse == null) throw new IllegalArgumentException("No remedial course available");
        // Detour: chen 1 node remedial ngay sau node that bai, cac node phia sau
        // bi day xuong (stepOrder +1) va khoa lai
        PathwayNode failedNode = pathway.getNodes().stream()
                .filter(n -> n.getId().equals(targetNodeId))
                .findFirst()
                .orElseThrow(() -> new IllegalArgumentException("Node not found in pathway"));

        boolean alreadyDetoured = pathway.getNodes().stream().anyMatch(n -> targetNodeId.equals(n.getParentNodeId()));
        if (alreadyDetoured) throw new IllegalStateException("A remedial course already exists for this node.");

        String beforeJson = toJson(pathway.getNodes());

        // Shift subsequent nodes down
        int newStepOrder = failedNode.getStepOrder() + 1;
        
        pathway.getNodes().stream()
                .filter(n -> n.getStepOrder() >= newStepOrder)
                .forEach(n -> {
                    n.setStepOrder(n.getStepOrder() + 1);
                    n.setStatus("LOCKED"); // Lock future nodes
                    nodeRepository.save(n);
                });

        PathwayNode detourNode = PathwayNode.builder()
                .learningPathway(pathway)
                .stepOrder(newStepOrder)
                .course(remedialCourse)
                .status("IN_PROGRESS")
                .reasonWhy(reason)
                .progressPercent(0)
                .nodeType("DETOUR_REMEDIAL")
                .rerouteReason(reason)
                .parentNodeId(failedNode.getId())
                .build();

        pathway.addNode(detourNode);
        nodeRepository.save(detourNode);

        logEvent(pathway.getId(), pathway.getStudent().getId(), "DETOUR_INSERT", beforeJson, toJson(pathway.getNodes()), reason);
    }

    private void logEvent(Long pathwayId, Long learnerId, String eventType, String beforeJson, String afterJson, String reason) {
        PathwayEvent event = PathwayEvent.builder()
                .pathwayId(pathwayId)
                .learnerId(learnerId)
                .eventType(eventType)
                .beforeJson(beforeJson)
                .afterJson(afterJson)
                .reason(reason)
                .build();
        eventRepository.save(event);
    }

    private String toJson(Object obj) {
        try {
            // Simplified JSON mapping for audit trail to avoid recursion (could map to DTOs first in production)
            return objectMapper.writeValueAsString(obj.toString()); 
        } catch (JsonProcessingException e) {
            log.error("Failed to serialize to JSON for audit", e);
            return "{}";
        }
    }
}
