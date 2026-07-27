package com.hango.hango_backend.service;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import static org.mockito.ArgumentMatchers.any;
import org.mockito.Mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.times;
import static org.mockito.Mockito.verify;
import org.mockito.junit.jupiter.MockitoExtension;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.hango.hango_backend.entity.Course;
import com.hango.hango_backend.entity.LearningPathway;
import com.hango.hango_backend.entity.PathwayEvent;
import com.hango.hango_backend.entity.PathwayNode;
import com.hango.hango_backend.entity.User;
import com.hango.hango_backend.repository.PathwayEventRepository;
import com.hango.hango_backend.repository.PathwayNodeRepository;

@ExtendWith(MockitoExtension.class)
class PathwayMutationServiceTest {

    @Mock
    private PathwayEventRepository eventRepository;
    @Mock
    private PathwayNodeRepository nodeRepository;

    private PathwayMutationService service;

    @BeforeEach
    void setUp() {
        service = new PathwayMutationService(eventRepository, nodeRepository, new ObjectMapper());
    }

    private LearningPathway pathwayWithNodes(PathwayNode... nodes) {
        LearningPathway pathway = LearningPathway.builder()
                .id(1L)
                .student(User.builder().id(1L).build())
                .build();
        for (PathwayNode n : nodes) {
            pathway.addNode(n);
        }
        return pathway;
    }

    private PathwayNode node(Long id, int stepOrder, String status) {
        return PathwayNode.builder()
                .id(id)
                .stepOrder(stepOrder)
                .status(status)
                .course(Course.builder().id(100L + id).build())
                .progressPercent(0)
                .build();
    }

    // =================================================================
    // applyFastTrackSkip
    // =================================================================

    @Test
    void applyFastTrackSkipShouldThrowWhenNodeNotFoundInPathway() {
        LearningPathway pathway = pathwayWithNodes(node(1L, 1, "IN_PROGRESS"));

        assertThrows(IllegalArgumentException.class,
                () -> service.applyFastTrackSkip(pathway, 999L, "too easy"));
    }

    @Test
    void applyFastTrackSkipShouldMarkNodeCompletedAndSkippedWithReason() {
        PathwayNode target = node(1L, 1, "IN_PROGRESS");
        LearningPathway pathway = pathwayWithNodes(target);

        service.applyFastTrackSkip(pathway, 1L, "Already knows this");

        assertEquals("COMPLETED", target.getStatus());
        assertEquals("FAST_TRACK_SKIPPED", target.getNodeType());
        assertEquals("Already knows this", target.getRerouteReason());
        assertTrue(target.getIsOptional());
        assertNotNull(target.getSkippedAt());
    }

    @Test
    void applyFastTrackSkipShouldUnlockNextNodeWhenCurrentlyLocked() {
        PathwayNode target = node(1L, 1, "IN_PROGRESS");
        PathwayNode next = node(2L, 2, "LOCKED");
        LearningPathway pathway = pathwayWithNodes(target, next);

        service.applyFastTrackSkip(pathway, 1L, "skip");

        assertEquals("IN_PROGRESS", next.getStatus());
        verify(nodeRepository).save(next);
    }

    @Test
    void applyFastTrackSkipShouldNotTouchNextNodeWhenAlreadyInProgress() {
        PathwayNode target = node(1L, 1, "IN_PROGRESS");
        PathwayNode next = node(2L, 2, "IN_PROGRESS");
        LearningPathway pathway = pathwayWithNodes(target, next);

        service.applyFastTrackSkip(pathway, 1L, "skip");

        verify(nodeRepository, never()).save(next);
        verify(nodeRepository, times(1)).save(any(PathwayNode.class));
    }

    @Test
    void applyFastTrackSkipShouldLogPathwayEventWithReason() {
        LearningPathway pathway = pathwayWithNodes(node(1L, 1, "IN_PROGRESS"));

        service.applyFastTrackSkip(pathway, 1L, "Already mastered");

        ArgumentCaptor<PathwayEvent> captor = ArgumentCaptor.forClass(PathwayEvent.class);
        verify(eventRepository).save(captor.capture());
        assertEquals("FAST_TRACK_SKIP", captor.getValue().getEventType());
        assertEquals(1L, captor.getValue().getPathwayId());
        assertEquals(1L, captor.getValue().getLearnerId());
        assertEquals("Already mastered", captor.getValue().getReason());
        assertNotNull(captor.getValue().getBeforeJson());
        assertNotNull(captor.getValue().getAfterJson());
    }

    // =================================================================
    // applyDetourInsertion
    // =================================================================

    @Test
    void applyDetourInsertionShouldThrowWhenNodeNotFoundInPathway() {
        LearningPathway pathway = pathwayWithNodes(node(1L, 1, "IN_PROGRESS"));
        Course remedial = Course.builder().id(200L).build();

        assertThrows(IllegalArgumentException.class,
                () -> service.applyDetourInsertion(pathway, 999L, remedial, "failed quiz"));
    }

    @Test
    void applyDetourInsertionShouldShiftSubsequentNodesDownAndLockThem() {
        PathwayNode failed = node(1L, 1, "IN_PROGRESS");
        PathwayNode nextNode = node(2L, 2, "LOCKED");
        LearningPathway pathway = pathwayWithNodes(failed, nextNode);
        Course remedial = Course.builder().id(200L).build();

        service.applyDetourInsertion(pathway, 1L, remedial, "failed quiz");

        assertEquals(3, nextNode.getStepOrder());
        assertEquals("LOCKED", nextNode.getStatus());
        verify(nodeRepository).save(nextNode);
    }

    @Test
    void applyDetourInsertionShouldInsertNewNodeAtFailedNodeStepOrderPlusOne() {
        PathwayNode failed = node(1L, 1, "IN_PROGRESS");
        LearningPathway pathway = pathwayWithNodes(failed);
        Course remedial = Course.builder().id(200L).build();

        service.applyDetourInsertion(pathway, 1L, remedial, "failed quiz");

        PathwayNode inserted = pathway.getNodes().get(pathway.getNodes().size() - 1);
        assertEquals(2, inserted.getStepOrder());
        assertEquals("IN_PROGRESS", inserted.getStatus());
        assertEquals("DETOUR_REMEDIAL", inserted.getNodeType());
        assertEquals(200L, inserted.getCourse().getId());
    }

    @Test
    void applyDetourInsertionShouldLinkDetourNodeToFailedNodeViaParentNodeId() {
        PathwayNode failed = node(1L, 1, "IN_PROGRESS");
        LearningPathway pathway = pathwayWithNodes(failed);
        Course remedial = Course.builder().id(200L).build();

        service.applyDetourInsertion(pathway, 1L, remedial, "failed quiz");

        PathwayNode inserted = pathway.getNodes().get(pathway.getNodes().size() - 1);
        assertEquals(1L, inserted.getParentNodeId());
    }

    @Test
    void applyDetourInsertionShouldLogPathwayEventWithReason() {
        PathwayNode failed = node(1L, 1, "IN_PROGRESS");
        LearningPathway pathway = pathwayWithNodes(failed);
        Course remedial = Course.builder().id(200L).build();

        service.applyDetourInsertion(pathway, 1L, remedial, "failed quiz twice");

        ArgumentCaptor<PathwayEvent> captor = ArgumentCaptor.forClass(PathwayEvent.class);
        verify(eventRepository).save(captor.capture());
        assertEquals("DETOUR_INSERT", captor.getValue().getEventType());
        assertEquals("failed quiz twice", captor.getValue().getReason());
    }
}
