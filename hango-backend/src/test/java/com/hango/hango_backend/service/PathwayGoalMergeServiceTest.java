package com.hango.hango_backend.service;

import java.util.List;

import static org.junit.jupiter.api.Assertions.assertEquals;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.mockito.Mockito;
import static org.mockito.Mockito.when;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.hango.hango_backend.dto.MergePreviewDTO;
import com.hango.hango_backend.entity.Course;
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
}
