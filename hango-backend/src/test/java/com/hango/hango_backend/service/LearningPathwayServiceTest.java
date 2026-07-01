package com.hango.hango_backend.service;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.hango.hango_backend.dto.LearningPathwayResponseDTO;
import com.hango.hango_backend.entity.LearningPathway;
import com.hango.hango_backend.entity.PathwayNode;
import com.hango.hango_backend.entity.User;
import com.hango.hango_backend.repository.CourseRepository;
import com.hango.hango_backend.repository.ExamAttemptRepository;
import com.hango.hango_backend.repository.LearningPathwayRepository;
import com.hango.hango_backend.repository.UserRepository;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.util.Optional;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class LearningPathwayServiceTest {

    @Mock
    private LearningPathwayRepository learningPathwayRepository;

    @Mock
    private ExamAttemptRepository examAttemptRepository;

    @Mock
    private CourseRepository courseRepository;

    @Mock
    private UserRepository userRepository;

    @Mock
    private GeminiClientService geminiClientService;

    @Mock
    private ObjectMapper objectMapper;

    @InjectMocks
    private LearningPathwayService learningPathwayService;

    @Test
    void reroutePathwayShouldMarkFirstNodeInProgressForLowQuizScore() {
        User student = User.builder().id(1L).build();
        LearningPathway pathway = LearningPathway.builder()
                .id(10L)
                .student(student)
                .mentorSummary("Existing summary")
                .status("ACTIVE")
                .build();

        PathwayNode firstNode = PathwayNode.builder()
                .stepOrder(1)
                .status("LOCKED")
                .build();
        PathwayNode secondNode = PathwayNode.builder()
                .stepOrder(2)
                .status("LOCKED")
                .build();
        pathway.addNode(firstNode);
        pathway.addNode(secondNode);

        when(learningPathwayRepository.findById(10L)).thenReturn(Optional.of(pathway));
        when(learningPathwayRepository.save(any(LearningPathway.class))).thenAnswer(invocation -> invocation.getArgument(0));

        LearningPathwayResponseDTO result = learningPathwayService.reroutePathway(10L, 1L, 42);

        assertTrue(result.getMentorSummary().contains("Dynamic"));
        assertEquals("IN_PROGRESS", firstNode.getStatus());
        assertEquals("LOCKED", secondNode.getStatus());
    }
}
