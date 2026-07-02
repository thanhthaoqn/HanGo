package com.hango.hango_backend.service;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.hango.hango_backend.dto.LearningPathwayResponseDTO;
import com.hango.hango_backend.dto.PathwayNodeDTO;
import com.hango.hango_backend.entity.Course;
import com.hango.hango_backend.entity.ExamAttempt;
import com.hango.hango_backend.entity.LearningPathway;
import com.hango.hango_backend.entity.PathwayNode;
import com.hango.hango_backend.entity.SystemParameter;
import com.hango.hango_backend.entity.User;
import com.hango.hango_backend.exeption.ApiException;
import com.hango.hango_backend.repository.CourseRepository;
import com.hango.hango_backend.repository.ExamAttemptRepository;
import com.hango.hango_backend.repository.LearningPathwayRepository;
import com.hango.hango_backend.repository.UserRepository;
import jakarta.persistence.LockModeType;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.data.jpa.repository.Lock;
import org.springframework.http.HttpStatus;

import java.lang.reflect.Method;
import java.util.List;
import java.util.Optional;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
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
    void pathwayDtoShouldDeserializeAiSnakeCaseJson() throws Exception {
        String json = """
                {
                  "roadmap_id": "AUTO_GEN",
                  "mentor_summary": "Focus on grammar first.",
                  "nodes": [
                    {
                      "step": 1,
                      "course_id": 7,
                      "course_title": "Grammar Basics",
                      "reason_why": "You missed tense questions.",
                      "status": "In_Progress",
                      "progress_percent": 25,
                      "tags": ["#Grammar"]
                    }
                  ]
                }
                """;

        LearningPathwayResponseDTO result = new ObjectMapper().readValue(json, LearningPathwayResponseDTO.class);

        assertEquals("AUTO_GEN", result.getRoadmapId());
        assertEquals("Focus on grammar first.", result.getMentorSummary());
        assertEquals(7L, result.getNodes().get(0).getCourseId());
        assertEquals("You missed tense questions.", result.getNodes().get(0).getReasonWhy());
        assertEquals(25, result.getNodes().get(0).getProgressPercent());
    }

    @Test
    void generatePathwayShouldFilterHallucinatedCourseIdsFromAiResponse() throws Exception {
        User student = User.builder().id(1L).build();
        ExamAttempt examAttempt = examAttempt(student);
        Course grammarCourse = course(10L, "Grammar Basics", "PUBLISHED");
        Course draftCourse = course(99L, "Draft Reading", "DRAFT");
        LearningPathwayResponseDTO aiResponse = LearningPathwayResponseDTO.builder()
                .mentorSummary("Use only valid courses.")
                .nodes(List.of(
                        PathwayNodeDTO.builder().step(1).courseId(10L).status("In_Progress").reasonWhy("Foundation").build(),
                        PathwayNodeDTO.builder().step(2).courseId(404L).status("Locked").reasonWhy("Hallucinated").build(),
                        PathwayNodeDTO.builder().step(3).courseId(99L).status("Locked").reasonWhy("Draft course").build()))
                .build();

        when(userRepository.findByIdForUpdate(1L)).thenReturn(Optional.of(student));
        when(examAttemptRepository.findById(5L)).thenReturn(Optional.of(examAttempt));
        when(courseRepository.findAll()).thenReturn(List.of(grammarCourse, draftCourse));
        when(geminiClientService.generateChatResponse(anyString(), any())).thenReturn("{}");
        when(objectMapper.readValue(anyString(), eq(LearningPathwayResponseDTO.class))).thenReturn(aiResponse);
        when(learningPathwayRepository.findByStudentIdAndStatus(1L, "ACTIVE")).thenReturn(Optional.empty());
        when(learningPathwayRepository.save(any(LearningPathway.class))).thenAnswer(invocation -> {
            LearningPathway pathway = invocation.getArgument(0);
            pathway.setId(100L);
            return pathway;
        });

        LearningPathwayResponseDTO result = learningPathwayService.generatePathway(1L, 5L);

        assertEquals(1, result.getNodes().size());
        assertEquals(10L, result.getNodes().get(0).getCourseId());
        assertEquals("Grammar Basics", result.getNodes().get(0).getCourseTitle());
        ArgumentCaptor<LearningPathway> savedPathway = ArgumentCaptor.forClass(LearningPathway.class);
        verify(learningPathwayRepository).save(savedPathway.capture());
        assertEquals(1, savedPathway.getValue().getNodes().size());
        assertEquals(10L, savedPathway.getValue().getNodes().get(0).getCourse().getId());
    }

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
                .course(course(1L, "Grammar Basics", "PUBLISHED"))
                .status("LOCKED")
                .progressPercent(0)
                .build();
        PathwayNode secondNode = PathwayNode.builder()
                .stepOrder(2)
                .course(course(2L, "Reading Practice", "PUBLISHED"))
                .status("LOCKED")
                .progressPercent(0)
                .build();
        pathway.addNode(firstNode);
        pathway.addNode(secondNode);

        when(learningPathwayRepository.findById(10L)).thenReturn(Optional.of(pathway));
        when(learningPathwayRepository.save(any(LearningPathway.class))).thenAnswer(invocation -> invocation.getArgument(0));

        LearningPathwayResponseDTO result = learningPathwayService.reroutePathway(10L, 1L, 42);

        assertTrue(result.getMentorSummary().contains("Dynamic rerouting"));
        assertEquals("IN_PROGRESS", result.getNodes().get(0).getStatus());
        assertEquals(25, result.getNodes().get(0).getProgressPercent());
        assertEquals("LOCKED", result.getNodes().get(1).getStatus());
    }

    @Test
    void generatePathwayShouldReturnNotFoundWhenExamAttemptDoesNotExist() {
        User student = User.builder().id(1L).build();
        when(userRepository.findByIdForUpdate(1L)).thenReturn(Optional.of(student));
        when(examAttemptRepository.findById(999L)).thenReturn(Optional.empty());

        ApiException exception = assertThrows(ApiException.class,
                () -> learningPathwayService.generatePathway(1L, 999L));

        assertEquals(HttpStatus.NOT_FOUND, exception.getStatus());
        assertEquals("Exam Attempt not found", exception.getMessage());
        verify(geminiClientService, never()).generateChatResponse(anyString(), any());
    }

    @Test
    void generatePathwayShouldUseExistingCoursesWhenNoPublishedCoursesExist() throws Exception {
        User student = User.builder().id(1L).build();
        ExamAttempt examAttempt = examAttempt(student);
        when(userRepository.findByIdForUpdate(1L)).thenReturn(Optional.of(student));
        when(examAttemptRepository.findById(5L)).thenReturn(Optional.of(examAttempt));
        when(courseRepository.findAll()).thenReturn(List.of(course(99L, "Draft Only", "DRAFT")));
        when(learningPathwayRepository.findByStudentIdAndStatus(1L, "ACTIVE")).thenReturn(Optional.empty());
        when(learningPathwayRepository.save(any(LearningPathway.class))).thenAnswer(invocation -> {
            LearningPathway pathway = invocation.getArgument(0);
            pathway.setId(101L);
            return pathway;
        });

        LearningPathwayResponseDTO result = learningPathwayService.generatePathway(1L, 5L);

        assertEquals(101L, result.getPathwayId());
        assertTrue(result.getMentorSummary().contains("currently available"));
        assertEquals(1, result.getNodes().size());
        assertEquals(99L, result.getNodes().get(0).getCourseId());
        assertEquals("IN_PROGRESS", result.getNodes().get(0).getStatus());
    }

    @Test
    void getPathwayByIdShouldRejectOtherLearnersPathway() {
        LearningPathway pathway = LearningPathway.builder()
                .id(10L)
                .student(User.builder().id(2L).build())
                .status("ACTIVE")
                .build();
        when(learningPathwayRepository.findById(10L)).thenReturn(Optional.of(pathway));

        ApiException exception = assertThrows(ApiException.class,
                () -> learningPathwayService.getPathwayById(10L, 1L));

        assertEquals(HttpStatus.FORBIDDEN, exception.getStatus());
        assertEquals("Access denied", exception.getMessage());
    }

    @Test
    void generatePathwayShouldArchiveExistingActivePathwayBeforeSavingReplacement() throws Exception {
        User student = User.builder().id(1L).build();
        ExamAttempt examAttempt = examAttempt(student);
        LearningPathway existing = LearningPathway.builder()
                .id(88L)
                .student(student)
                .status("ACTIVE")
                .build();
        LearningPathwayResponseDTO aiResponse = LearningPathwayResponseDTO.builder()
                .mentorSummary("Replacement pathway")
                .nodes(List.of(PathwayNodeDTO.builder()
                        .step(1)
                        .courseId(10L)
                        .status("In_Progress")
                        .reasonWhy("Start here")
                        .build()))
                .build();

        when(userRepository.findByIdForUpdate(1L)).thenReturn(Optional.of(student));
        when(examAttemptRepository.findById(5L)).thenReturn(Optional.of(examAttempt));
        when(courseRepository.findAll()).thenReturn(List.of(course(10L, "Grammar Basics", "PUBLISHED")));
        when(geminiClientService.generateChatResponse(anyString(), any())).thenReturn("{}");
        when(objectMapper.readValue(anyString(), eq(LearningPathwayResponseDTO.class))).thenReturn(aiResponse);
        when(learningPathwayRepository.findByStudentIdAndStatus(1L, "ACTIVE")).thenReturn(Optional.of(existing));
        when(learningPathwayRepository.save(any(LearningPathway.class))).thenAnswer(invocation -> {
            LearningPathway pathway = invocation.getArgument(0);
            if (pathway.getId() == null) {
                pathway.setId(120L);
            }
            return pathway;
        });

        LearningPathwayResponseDTO result = learningPathwayService.generatePathway(1L, 5L);

        assertEquals("ARCHIVED", existing.getStatus());
        assertEquals(120L, result.getPathwayId());
        assertEquals(1, result.getNodes().size());
    }

    @Test
    void userRepositoryGenerateLockShouldUsePessimisticWriteForConcurrentRequests() throws Exception {
        Method method = UserRepository.class.getMethod("findByIdForUpdate", Long.class);
        Lock lock = method.getAnnotation(Lock.class);

        assertNotNull(lock);
        assertEquals(LockModeType.PESSIMISTIC_WRITE, lock.value());
    }

    private ExamAttempt examAttempt(User student) {
        ExamAttempt examAttempt = new ExamAttempt();
        examAttempt.setId(5L);
        examAttempt.setStudent(student);
        examAttempt.setAnswersJson("{\"score\":42,\"weaknesses\":[\"tenses\"]}");
        return examAttempt;
    }

    private Course course(Long id, String title, String status) {
        return Course.builder()
                .id(id)
                .title(title)
                .status(status)
                .description("Course description")
                .category(SystemParameter.builder().paramValue("Grammar").build())
                .difficulty(SystemParameter.builder().paramValue("Beginner").build())
                .creator(User.builder().id(100L).build())
                .build();
    }
}
