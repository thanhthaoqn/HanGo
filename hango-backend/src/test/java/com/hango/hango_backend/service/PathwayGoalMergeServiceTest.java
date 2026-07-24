package com.hango.hango_backend.service;

import java.util.List;
import java.util.Optional;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.mockito.Mockito;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.hango.hango_backend.dto.MergePreviewDTO;
import com.hango.hango_backend.dto.PathwayNodeDTO;
import com.hango.hango_backend.entity.Course;
import com.hango.hango_backend.entity.LearningPathway;
import com.hango.hango_backend.entity.PathwayNode;
import com.hango.hango_backend.entity.SystemParameter;
import com.hango.hango_backend.entity.User;
import com.hango.hango_backend.repository.CourseRepository;
import com.hango.hango_backend.repository.LearningPathwayGoalRepository;
import com.hango.hango_backend.repository.LearningPathwayRepository;

class PathwayGoalMergeServiceTest {

    private PathwayGoalMergeService service;
    private CourseRepository courseRepository;
    private LearningPathwayRepository pathwayRepository;
    private LearningPathwayGoalRepository goalRepository;
    private ObjectMapper objectMapper;

    @BeforeEach
    void setUp() {
        courseRepository = Mockito.mock(CourseRepository.class);
        pathwayRepository = Mockito.mock(LearningPathwayRepository.class);
        goalRepository = Mockito.mock(LearningPathwayGoalRepository.class);
        objectMapper = new ObjectMapper();
        
        service = new PathwayGoalMergeService(courseRepository, pathwayRepository, goalRepository, objectMapper);
    }

    private Course course(Long id, String title, String skill, String difficulty) {
        SystemParameter cat = new SystemParameter();
        cat.setParamValue(skill);
        SystemParameter diff = new SystemParameter();
        diff.setParamValue(difficulty);
        Course c = new Course();
        c.setId(id);
        c.setTitle(title);
        c.setCategory(cat);
        c.setDifficulty(diff);
        return c;
    }

    // =================================================================
    // mergePreview
    // =================================================================

    @Test
    void mergePreview_removesDuplicatesAndPreservesOrder() {
        com.hango.hango_backend.entity.SystemParameter cat1 = new com.hango.hango_backend.entity.SystemParameter(); cat1.setParamValue("Grammar");
        com.hango.hango_backend.entity.SystemParameter cat2 = new com.hango.hango_backend.entity.SystemParameter(); cat2.setParamValue("Reading");
        com.hango.hango_backend.entity.SystemParameter diff1 = new com.hango.hango_backend.entity.SystemParameter(); diff1.setParamValue("Beginner");

        Course c1 = new Course(); c1.setId(1L); c1.setTitle("C1"); c1.setCategory(cat1); c1.setDifficulty(diff1);
        Course c2 = new Course(); c2.setId(2L); c2.setTitle("C2"); c2.setCategory(cat2); c2.setDifficulty(diff1);

        // Input: c1, c2, c1
        when(courseRepository.findAllById(List.of(1L, 2L, 1L))).thenReturn(List.of(c1, c2, c1));

        MergePreviewDTO preview = service.mergePreview(List.of(1L, 2L, 1L));

        assertEquals(1, preview.getRemovedDuplicates()); // One duplicate c1 removed
        assertEquals(2, preview.getMergedNodes().size());
        assertEquals(1L, preview.getMergedNodes().get(0).getCourseId());
        assertEquals(2L, preview.getMergedNodes().get(1).getCourseId());
    }

    @Test
    void mergePreviewShouldReturnEmptyResultWhenNoCourseIdsProvided() {
        when(courseRepository.findAllById(List.of())).thenReturn(List.of());

        MergePreviewDTO preview = service.mergePreview(List.of());

        assertEquals(0, preview.getRemovedDuplicates());
        assertEquals(0, preview.getSharedSteps());
        assertEquals(0, preview.getEstimatedTimeSavedHours());
        assertTrue(preview.getMergedNodes().isEmpty());
    }

    @Test
    void mergePreviewShouldDeduplicateDifferentCoursesSharingSameSkillAndDifficulty() {
        Course c1 = course(1L, "C1", "Grammar", "Beginner");
        Course c2 = course(2L, "C2", "Grammar", "Beginner");
        when(courseRepository.findAllById(List.of(1L, 2L))).thenReturn(List.of(c1, c2));

        MergePreviewDTO preview = service.mergePreview(List.of(1L, 2L));

        assertEquals(1, preview.getRemovedDuplicates());
        assertEquals(1, preview.getSharedSteps());
        assertEquals(2, preview.getEstimatedTimeSavedHours());
        assertEquals(1, preview.getMergedNodes().size());
        assertEquals(1L, preview.getMergedNodes().get(0).getCourseId());
    }

    @Test
    void mergePreviewShouldFlagEveryThirdKeptNodeAsMergedWithSharedPrerequisiteReason() {
        Course c1 = course(1L, "C1", "Grammar", "Beginner");
        Course c2 = course(2L, "C2", "Reading", "Beginner");
        Course c3 = course(3L, "C3", "Listening", "Beginner");
        Course c4 = course(4L, "C4", "Writing", "Beginner");
        when(courseRepository.findAllById(List.of(1L, 2L, 3L, 4L))).thenReturn(List.of(c1, c2, c3, c4));

        MergePreviewDTO preview = service.mergePreview(List.of(1L, 2L, 3L, 4L));

        assertEquals(4, preview.getMergedNodes().size());
        assertEquals("NORMAL", preview.getMergedNodes().get(0).getNodeType());
        assertNull(preview.getMergedNodes().get(0).getMergeReason());
        assertEquals("MERGED", preview.getMergedNodes().get(3).getNodeType());
        assertEquals("Shared prerequisite across multiple goals.", preview.getMergedNodes().get(3).getMergeReason());
        assertEquals(1, preview.getSharedSteps());
    }

    // =================================================================
    // mergeConfirm
    // =================================================================

    @Test
    void mergeConfirmShouldThrowWhenPathwayNotFound() {
        when(pathwayRepository.findById(1L)).thenReturn(Optional.empty());
        MergePreviewDTO preview = MergePreviewDTO.builder().mergedNodes(List.of()).build();

        assertThrows(IllegalArgumentException.class, () -> service.mergeConfirm(1L, 1L, preview));
    }

    @Test
    void mergeConfirmShouldThrowWhenAccessedByDifferentStudent() {
        LearningPathway pathway = LearningPathway.builder().id(1L).student(User.builder().id(2L).build()).build();
        when(pathwayRepository.findById(1L)).thenReturn(Optional.of(pathway));
        MergePreviewDTO preview = MergePreviewDTO.builder().mergedNodes(List.of()).build();

        assertThrows(IllegalArgumentException.class, () -> service.mergeConfirm(1L, 1L, preview));
    }

    @Test
    void mergeConfirmShouldThrowWhenCourseInPreviewNotFound() {
        LearningPathway pathway = LearningPathway.builder().id(1L).student(User.builder().id(1L).build()).build();
        when(pathwayRepository.findById(1L)).thenReturn(Optional.of(pathway));
        when(courseRepository.findById(5L)).thenReturn(Optional.empty());

        PathwayNodeDTO nodeDto = PathwayNodeDTO.builder().step(1).courseId(5L).status("IN_PROGRESS").build();
        MergePreviewDTO preview = MergePreviewDTO.builder().mergedNodes(List.of(nodeDto)).build();

        assertThrows(IllegalArgumentException.class, () -> service.mergeConfirm(1L, 1L, preview));
    }

    @Test
    void mergeConfirmShouldRebuildNodesFromPreviewAndSave() {
        LearningPathway pathway = LearningPathway.builder().id(1L).student(User.builder().id(1L).build()).build();
        PathwayNode oldNode = PathwayNode.builder().id(50L).stepOrder(1).status("IN_PROGRESS").build();
        pathway.addNode(oldNode);
        when(pathwayRepository.findById(1L)).thenReturn(Optional.of(pathway));
        Course c1 = course(1L, "C1", "Grammar", "Beginner");
        when(courseRepository.findById(1L)).thenReturn(Optional.of(c1));

        PathwayNodeDTO nodeDto = PathwayNodeDTO.builder()
                .step(1).courseId(1L).status("IN_PROGRESS").progressPercent(0)
                .sourceGoalLabels(List.of("Goal_A")).nodeType("NORMAL").build();
        MergePreviewDTO preview = MergePreviewDTO.builder().mergedNodes(List.of(nodeDto)).build();

        service.mergeConfirm(1L, 1L, preview);

        assertEquals(1, pathway.getNodes().size());
        assertEquals(1L, pathway.getNodes().get(0).getCourse().getId());
        assertEquals("IN_PROGRESS", pathway.getNodes().get(0).getStatus());
        verify(pathwayRepository).save(pathway);
    }
}
