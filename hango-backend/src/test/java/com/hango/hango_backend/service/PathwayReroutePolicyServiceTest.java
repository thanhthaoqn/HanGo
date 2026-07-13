package com.hango.hango_backend.service;

import com.hango.hango_backend.dto.ProgressSnapshotDTO;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

import java.util.List;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertTrue;

class PathwayReroutePolicyServiceTest {

    private PathwayReroutePolicyService service;

    @BeforeEach
    void setUp() {
        service = new PathwayReroutePolicyService();
    }

    @Test
    void fastTrack_onlySuggests_neverAutoSkips() {
        ProgressSnapshotDTO snapshot = new ProgressSnapshotDTO();
        
        ProgressSnapshotDTO.NodeSnapshotDTO node1 = new ProgressSnapshotDTO.NodeSnapshotDTO();
        node1.setStatus("COMPLETED");
        node1.setLatestScore(100.0);
        
        ProgressSnapshotDTO.NodeSnapshotDTO node2 = new ProgressSnapshotDTO.NodeSnapshotDTO();
        node2.setStatus("LOCKED");
        node2.setHasWeakSkillOverlap(false);
        
        snapshot.setNodesSnapshot(List.of(node1, node2));
        
        PathwayReroutePolicyService.PolicyDecision decision = service.evaluate(snapshot);
        
        assertEquals(PathwayReroutePolicyService.PolicyAction.FAST_TRACK_ELIGIBLE, decision.action);
        assertEquals(node2, decision.targetNode);
        assertTrue(decision.reason.contains("Eligible to skip"));
    }

    @Test
    void detour_insertsRemedialNode_afterTwoFailures() {
        ProgressSnapshotDTO snapshot = new ProgressSnapshotDTO();
        
        ProgressSnapshotDTO.NodeSnapshotDTO node1 = new ProgressSnapshotDTO.NodeSnapshotDTO();
        node1.setStatus("IN_PROGRESS");
        node1.setFailStreak(2);
        
        snapshot.setNodesSnapshot(List.of(node1));
        
        PathwayReroutePolicyService.PolicyDecision decision = service.evaluate(snapshot);
        
        assertEquals(PathwayReroutePolicyService.PolicyAction.DETOUR_REQUIRED, decision.action);
        assertEquals(node1, decision.targetNode);
        assertTrue(decision.reason.contains("2 times consecutively"));
    }

    @Test
    void noChange_whenNotEligible() {
        ProgressSnapshotDTO snapshot = new ProgressSnapshotDTO();
        
        ProgressSnapshotDTO.NodeSnapshotDTO node1 = new ProgressSnapshotDTO.NodeSnapshotDTO();
        node1.setStatus("IN_PROGRESS");
        node1.setFailStreak(1); // Only 1 failure, no detour
        
        snapshot.setNodesSnapshot(List.of(node1));
        
        PathwayReroutePolicyService.PolicyDecision decision = service.evaluate(snapshot);
        
        assertEquals(PathwayReroutePolicyService.PolicyAction.NO_CHANGE, decision.action);
        assertNull(decision.targetNode);
    }
}
