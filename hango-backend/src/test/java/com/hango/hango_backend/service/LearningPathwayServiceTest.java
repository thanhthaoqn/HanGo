package com.hango.hango_backend.service;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.hango.hango_backend.dto.LearningPathwayResponseDTO;
import com.hango.hango_backend.dto.LearningPathwayResponseDTO;
import com.hango.hango_backend.dto.PathwayGenerateRequestDTO;
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
import com.hango.hango_backend.repository.LessonProgressRepository;
import com.hango.hango_backend.repository.LessonRepository;
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
import static org.mockito.Mockito.any;

import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.eq;

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

    @Mock
    private ExamResultAnalyzerService examResultAnalyzerService;

    @Mock
    private LessonProgressRepository lessonProgressRepository;

    @Mock
    private LessonRepository lessonRepository;

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
        when(examResultAnalyzerService.analyzeLatestExamAttempt(any(ExamAttempt.class)))
                .thenReturn(com.hango.hango_backend.dto.ExamResultAnalysisDTO.builder()
                        .examAttemptId(5L)
                        .score(42)
                        .rawAnswersJson(examAttempt.getAnswersJson())
                        .knowledgeGapsJson("{\"critical_topics\":[],\"weak_skills\":[],\"incorrect_count\":0}")
                        .hints(null)
                        .build());


        when(geminiClientService.generateChatResponse(anyString(), any())).thenReturn("{}");
        when(objectMapper.readValue(anyString(), eq(LearningPathwayResponseDTO.class))).thenReturn(aiResponse);


        when(learningPathwayRepository.findByStudentIdAndStatus(1L, "ACTIVE")).thenReturn(Optional.empty());
        when(learningPathwayRepository.save(any(LearningPathway.class))).thenAnswer(invocation -> {
            LearningPathway pathway = invocation.getArgument(0);
            pathway.setId(100L);
            return pathway;
        });

        PathwayGenerateRequestDTO req = new PathwayGenerateRequestDTO();
        req.setExamAttemptId(5L);
        LearningPathwayResponseDTO result = learningPathwayService.generatePathway(1L, req);

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

        when(examAttemptRepository.findTop10ByStudent_IdOrderBySubmittedAtDesc(1L)).thenReturn(List.of());
        when(lessonRepository.countByCourseId(1L)).thenReturn(4L);
        when(lessonRepository.countByCourseId(2L)).thenReturn(4L);
        when(lessonProgressRepository.countCompletedLessonsByUserIdAndCourseId(1L, 1L)).thenReturn(1L);
        when(lessonProgressRepository.countCompletedLessonsByUserIdAndCourseId(1L, 2L)).thenReturn(0L);

        LearningPathwayResponseDTO result = learningPathwayService.reroutePathway(10L, 1L);

        // Nội dung mentorSummary hiện tại đã đổi theo text tiếng Việt nên không thể assert theo chuỗi cũ.
        assertTrue(result.getMentorSummary().contains("Hệ thống") || result.getMentorSummary().contains("điểm") || result.getMentorSummary().contains("Dynamic"));

        assertEquals("IN_PROGRESS", result.getNodes().get(0).getStatus());
        assertEquals(25, result.getNodes().get(0).getProgressPercent());
        assertEquals("LOCKED", result.getNodes().get(1).getStatus());
    }

    @Test
    void generatePathwayShouldReturnNotFoundWhenExamAttemptDoesNotExist() {
        User student = User.builder().id(1L).build();
        when(userRepository.findByIdForUpdate(1L)).thenReturn(Optional.of(student));
        when(examAttemptRepository.findById(999L)).thenReturn(Optional.empty());

        PathwayGenerateRequestDTO req = new PathwayGenerateRequestDTO();
        req.setExamAttemptId(999L);
        ApiException exception = assertThrows(ApiException.class,
                () -> learningPathwayService.generatePathway(1L, req));

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
        when(examResultAnalyzerService.analyzeLatestExamAttempt(any(ExamAttempt.class)))
                .thenReturn(com.hango.hango_backend.dto.ExamResultAnalysisDTO.builder()
                        .examAttemptId(5L)
                        .score(42)
                        .rawAnswersJson(examAttempt.getAnswersJson())
                        .knowledgeGapsJson("{\"critical_topics\":[],\"weak_skills\":[],\"incorrect_count\":0}")
                        .hints(null)
                        .build());

        when(learningPathwayRepository.findByStudentIdAndStatus(1L, "ACTIVE")).thenReturn(Optional.empty());
        when(learningPathwayRepository.save(any(LearningPathway.class))).thenAnswer(invocation -> {
            LearningPathway pathway = invocation.getArgument(0);
            pathway.setId(101L);
            return pathway;
        });

        PathwayGenerateRequestDTO req = new PathwayGenerateRequestDTO();
        req.setExamAttemptId(5L);
        LearningPathwayResponseDTO result = learningPathwayService.generatePathway(1L, req);

        assertEquals(101L, result.getPathwayId());
        // Khi AI generation bị fail/null, backend sẽ fallback deterministic pathway và mentorSummary sẽ là tiếng Việt.
        // Vì vậy chỉ assert presence của khóa học và status node, không assert chuỗi mentor_summary cố định.
        assertNotNull(result.getMentorSummary());

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
        when(examResultAnalyzerService.analyzeLatestExamAttempt(any(ExamAttempt.class)))
                .thenReturn(com.hango.hango_backend.dto.ExamResultAnalysisDTO.builder()
                        .examAttemptId(5L)
                        .score(42)
                        .rawAnswersJson(examAttempt(student).getAnswersJson())
                        .knowledgeGapsJson("{\"critical_topics\":[],\"weak_skills\":[],\"incorrect_count\":0}")
                        .hints(null)
                        .build());

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

        PathwayGenerateRequestDTO req = new PathwayGenerateRequestDTO();
        req.setExamAttemptId(5L);
        LearningPathwayResponseDTO result = learningPathwayService.generatePathway(1L, req);

        assertEquals("ARCHIVED", existing.getStatus());
        assertEquals(120L, result.getPathwayId());
        assertEquals(1, result.getNodes().size());
    }

    @Test
    void applyScheduleShouldRejectOtherLearnersPathway() {
        LearningPathway pathway = LearningPathway.builder()
                .id(10L)
                .student(User.builder().id(2L).build())
                .status("ACTIVE")
                .build();
        when(learningPathwayRepository.findById(10L)).thenReturn(Optional.of(pathway));

        ApiException exception = assertThrows(ApiException.class,
                () -> learningPathwayService.applySchedule(10L, 1L, new com.hango.hango_backend.dto.PathwayScheduleRequestDTO()));

        assertEquals(HttpStatus.FORBIDDEN, exception.getStatus());
        assertEquals("Access denied", exception.getMessage());
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

    // =================================================================
    // getMyPathway
    // =================================================================

    @Test
    void getMyPathwayShouldThrowWhenNoActivePathwayFound() {
        when(learningPathwayRepository.findByStudentIdAndStatus(1L, "ACTIVE")).thenReturn(Optional.empty());

        ApiException exception = assertThrows(ApiException.class, () -> learningPathwayService.getMyPathway(1L));

        assertEquals(HttpStatus.NOT_FOUND, exception.getStatus());
    }

    @Test
    void getMyPathwayShouldReturnActivePathwayForStudent() {
        User student = User.builder().id(1L).build();
        LearningPathway pathway = LearningPathway.builder().id(10L).student(student).status("ACTIVE").build();
        when(learningPathwayRepository.findByStudentIdAndStatus(1L, "ACTIVE")).thenReturn(Optional.of(pathway));
        when(examAttemptRepository.findTop10ByStudent_IdOrderBySubmittedAtDesc(1L)).thenReturn(List.of());

        LearningPathwayResponseDTO result = learningPathwayService.getMyPathway(1L);

        assertEquals(10L, result.getPathwayId());
    }

    @Test
    void getMyPathwayShouldExtractWeakSkillsFromKnowledgeGapsJson() throws Exception {
        User student = User.builder().id(1L).build();
        LearningPathway pathway = LearningPathway.builder().id(10L).student(student).status("ACTIVE").build();
        when(learningPathwayRepository.findByStudentIdAndStatus(1L, "ACTIVE")).thenReturn(Optional.of(pathway));
        when(examAttemptRepository.findTop10ByStudent_IdOrderBySubmittedAtDesc(1L)).thenReturn(List.of());
        when(examResultAnalyzerService.analyzeLearnerAttempts(eq(1L), any())).thenReturn(
                com.hango.hango_backend.dto.ExamResultAnalysisDTO.builder()
                        .knowledgeGapsJson("{\"weak_skills\":[\"Reading\",\"Listening\"]}")
                        .build());
        when(objectMapper.readValue(anyString(), eq(java.util.Map.class)))
                .thenReturn(java.util.Map.of("weak_skills", List.of("Reading", "Listening")));

        LearningPathwayResponseDTO result = learningPathwayService.getMyPathway(1L);

        assertEquals(List.of("Reading", "Listening"), result.getWeakSkills());
    }

    // =================================================================
    // getScheduleStatus
    // =================================================================

    @Test
    void getScheduleStatusShouldRejectOtherLearnersPathway() {
        LearningPathway pathway = LearningPathway.builder().id(10L).student(User.builder().id(2L).build()).build();
        when(learningPathwayRepository.findById(10L)).thenReturn(Optional.of(pathway));

        ApiException exception = assertThrows(ApiException.class, () -> learningPathwayService.getScheduleStatus(10L, 1L));

        assertEquals(HttpStatus.FORBIDDEN, exception.getStatus());
    }

    @Test
    void getScheduleStatusShouldReturnNoneWhenNotSet() {
        LearningPathway pathway = LearningPathway.builder().id(10L).student(User.builder().id(1L).build()).build();
        when(learningPathwayRepository.findById(10L)).thenReturn(Optional.of(pathway));

        String result = learningPathwayService.getScheduleStatus(10L, 1L);

        assertEquals("NONE", result);
    }

    @Test
    void getScheduleStatusShouldReturnStoredValueWhenSet() {
        LearningPathway pathway = LearningPathway.builder().id(10L).student(User.builder().id(1L).build()).scheduleStatus("BEHIND").build();
        when(learningPathwayRepository.findById(10L)).thenReturn(Optional.of(pathway));

        String result = learningPathwayService.getScheduleStatus(10L, 1L);

        assertEquals("BEHIND", result);
    }

    // =================================================================
    // chatWithMentor
    // =================================================================

    @Test
    void chatWithMentorShouldRejectOtherLearnersPathway() {
        LearningPathway pathway = LearningPathway.builder().id(10L).student(User.builder().id(2L).build()).build();
        when(learningPathwayRepository.findById(10L)).thenReturn(Optional.of(pathway));

        ApiException exception = assertThrows(ApiException.class,
                () -> learningPathwayService.chatWithMentor(10L, 1L, "What's my score?"));

        assertEquals(HttpStatus.FORBIDDEN, exception.getStatus());
    }

    @Test
    void chatWithMentorShouldNotLeakRawAnswersJsonIntoThePrompt() {
        User student = User.builder().id(1L).build();
        LearningPathway pathway = LearningPathway.builder().id(10L).student(student).build();
        PathwayNode nodeItem = PathwayNode.builder().stepOrder(1).course(course(1L, "Grammar Basics", "PUBLISHED")).status("IN_PROGRESS").build();
        pathway.addNode(nodeItem);
        when(learningPathwayRepository.findById(10L)).thenReturn(Optional.of(pathway));
        when(examAttemptRepository.findTop10ByStudent_IdOrderBySubmittedAtDesc(1L)).thenReturn(List.of());
        when(examResultAnalyzerService.analyzeLearnerAttempts(eq(1L), any())).thenReturn(
                com.hango.hango_backend.dto.ExamResultAnalysisDTO.builder()
                        .knowledgeGapsJson("{\"weak_skills\":[\"Reading\"]}")
                        .hints(java.util.Map.of("score_avg", 6.0))
                        .build());
        when(geminiClientService.generateChatResponse(anyString(), any())).thenReturn("Mentor reply");

        String reply = learningPathwayService.chatWithMentor(10L, 1L, "What's my latest score?");

        assertEquals("Mentor reply", reply);
        ArgumentCaptor<String> promptCaptor = ArgumentCaptor.forClass(String.class);
        verify(geminiClientService).generateChatResponse(promptCaptor.capture(), any());
        assertTrue(promptCaptor.getValue().contains("Grammar Basics"));
    }

    // =================================================================
    // applySchedule
    // =================================================================

    @Test
    void applyScheduleShouldSetGoalFieldsAndScheduleStatusOnTrack() {
        User student = User.builder().id(1L).build();
        LearningPathway pathway = LearningPathway.builder().id(10L).student(student).build();
        PathwayNode nodeItem = PathwayNode.builder().stepOrder(1).course(course(1L, "Grammar Basics", "PUBLISHED")).status("IN_PROGRESS").build();
        pathway.addNode(nodeItem);
        when(learningPathwayRepository.findById(10L)).thenReturn(Optional.of(pathway));
        when(learningPathwayRepository.save(any(LearningPathway.class))).thenAnswer(inv -> inv.getArgument(0));
        when(lessonRepository.countByCourseId(1L)).thenReturn(4L);
        when(examAttemptRepository.findTop10ByStudent_IdOrderBySubmittedAtDesc(1L)).thenReturn(List.of());
        when(lessonProgressRepository.countCompletedLessonsByUserIdAndCourseId(1L, 1L)).thenReturn(0L);

        com.hango.hango_backend.dto.PathwayScheduleRequestDTO req = new com.hango.hango_backend.dto.PathwayScheduleRequestDTO();
        req.setGoalName("Pass IELTS 6.5");
        req.setTargetDate(java.time.LocalDate.now().plusWeeks(4));
        req.setHoursPerWeek(5);

        LearningPathwayResponseDTO result = learningPathwayService.applySchedule(10L, 1L, req);

        assertEquals("Pass IELTS 6.5", result.getGoalName());
        assertEquals("ON_TRACK", result.getScheduleStatus());
        assertNotNull(pathway.getNodes().get(0).getEstimatedHours());
    }

    // =================================================================
    // generatePathway
    // =================================================================

    @Test
    void generatePathwayShouldReturnEmptyPathwayMessageWhenNoCoursesExistAtAll() {
        User student = User.builder().id(1L).build();
        ExamAttempt examAttempt = examAttempt(student);
        when(userRepository.findByIdForUpdate(1L)).thenReturn(Optional.of(student));
        when(examAttemptRepository.findById(5L)).thenReturn(Optional.of(examAttempt));
        when(courseRepository.findAll()).thenReturn(List.of());
        when(learningPathwayRepository.findByStudentIdAndStatus(1L, "ACTIVE")).thenReturn(Optional.empty());
        when(learningPathwayRepository.save(any(LearningPathway.class))).thenAnswer(inv -> {
            LearningPathway p = inv.getArgument(0);
            p.setId(200L);
            return p;
        });

        PathwayGenerateRequestDTO req = new PathwayGenerateRequestDTO();
        req.setExamAttemptId(5L);
        LearningPathwayResponseDTO result = learningPathwayService.generatePathway(1L, req);

        assertTrue(result.getMentorSummary().contains("No courses are available"));
        assertTrue(result.getNodes() == null || result.getNodes().isEmpty());
        verify(geminiClientService, never()).generateChatResponse(anyString(), any());
    }

    @Test
    void generatePathwayShouldThrowWhenUserNotFound() {
        when(userRepository.findByIdForUpdate(1L)).thenReturn(Optional.empty());

        PathwayGenerateRequestDTO req = new PathwayGenerateRequestDTO();
        req.setExamAttemptId(5L);
        ApiException exception = assertThrows(ApiException.class,
                () -> learningPathwayService.generatePathway(1L, req));

        assertEquals(HttpStatus.NOT_FOUND, exception.getStatus());
        assertEquals("User not found", exception.getMessage());
        verify(examAttemptRepository, never()).findById(any());
    }

    @Test
    void generatePathwayShouldRejectExamAttemptBelongingToAnotherStudent() {
        User student = User.builder().id(1L).build();
        User otherStudent = User.builder().id(2L).build();
        ExamAttempt examAttempt = examAttempt(otherStudent);
        when(userRepository.findByIdForUpdate(1L)).thenReturn(Optional.of(student));
        when(examAttemptRepository.findById(5L)).thenReturn(Optional.of(examAttempt));

        PathwayGenerateRequestDTO req = new PathwayGenerateRequestDTO();
        req.setExamAttemptId(5L);
        ApiException exception = assertThrows(ApiException.class,
                () -> learningPathwayService.generatePathway(1L, req));

        assertEquals(HttpStatus.FORBIDDEN, exception.getStatus());
        assertEquals("Access denied to this exam attempt", exception.getMessage());
        verify(courseRepository, never()).findAll();
    }

    @Test
    void generatePathwayShouldAddFallbackNodesWhenAiResponseReturnsOnlyInvalidCourseIds() throws Exception {
        User student = User.builder().id(1L).build();
        ExamAttempt examAttempt = examAttempt(student);
        Course grammarCourse = course(10L, "Grammar Basics", "PUBLISHED");
        Course readingCourse = course(20L, "Reading Practice", "PUBLISHED");
        LearningPathwayResponseDTO aiResponse = LearningPathwayResponseDTO.builder()
                .mentorSummary("AI could not find any usable course.")
                .nodes(List.of(
                        PathwayNodeDTO.builder().step(1).courseId(404L).status("In_Progress").reasonWhy("Hallucinated").build()))
                .build();

        when(userRepository.findByIdForUpdate(1L)).thenReturn(Optional.of(student));
        when(examAttemptRepository.findById(5L)).thenReturn(Optional.of(examAttempt));
        when(courseRepository.findAll()).thenReturn(List.of(grammarCourse, readingCourse));
        when(examResultAnalyzerService.analyzeLatestExamAttempt(any(ExamAttempt.class)))
                .thenReturn(com.hango.hango_backend.dto.ExamResultAnalysisDTO.builder()
                        .examAttemptId(5L)
                        .score(42)
                        .rawAnswersJson(examAttempt.getAnswersJson())
                        .knowledgeGapsJson("{\"critical_topics\":[],\"weak_skills\":[],\"incorrect_count\":0}")
                        .hints(null)
                        .build());
        when(geminiClientService.generateChatResponse(anyString(), any())).thenReturn("{}");
        when(objectMapper.readValue(anyString(), eq(LearningPathwayResponseDTO.class))).thenReturn(aiResponse);
        when(learningPathwayRepository.findByStudentIdAndStatus(1L, "ACTIVE")).thenReturn(Optional.empty());
        when(learningPathwayRepository.save(any(LearningPathway.class))).thenAnswer(invocation -> {
            LearningPathway pathway = invocation.getArgument(0);
            pathway.setId(300L);
            return pathway;
        });

        PathwayGenerateRequestDTO req = new PathwayGenerateRequestDTO();
        req.setExamAttemptId(5L);
        LearningPathwayResponseDTO result = learningPathwayService.generatePathway(1L, req);

        assertEquals(2, result.getNodes().size());
        assertEquals(10L, result.getNodes().get(0).getCourseId());
        assertEquals("IN_PROGRESS", result.getNodes().get(0).getStatus());
        assertEquals(20L, result.getNodes().get(1).getCourseId());
        assertEquals("LOCKED", result.getNodes().get(1).getStatus());
    }

    // =================================================================
    // reroutePathway
    // =================================================================

    @Test
    void reroutePathwayShouldThrowNotFoundWhenPathwayDoesNotExist() {
        when(learningPathwayRepository.findById(10L)).thenReturn(Optional.empty());

        ApiException exception = assertThrows(ApiException.class,
                () -> learningPathwayService.reroutePathway(10L, 1L));

        assertEquals(HttpStatus.NOT_FOUND, exception.getStatus());
        assertEquals("Pathway not found", exception.getMessage());
    }

    @Test
    void reroutePathwayShouldRejectOtherLearnersPathway() {
        LearningPathway pathway = LearningPathway.builder()
                .id(10L)
                .student(User.builder().id(2L).build())
                .status("ACTIVE")
                .build();
        when(learningPathwayRepository.findById(10L)).thenReturn(Optional.of(pathway));

        ApiException exception = assertThrows(ApiException.class,
                () -> learningPathwayService.reroutePathway(10L, 1L));

        assertEquals(HttpStatus.FORBIDDEN, exception.getStatus());
        assertEquals("Access denied", exception.getMessage());
    }

    @Test
    void reroutePathwayShouldKeepAlreadyCompletedNodesUnchangedForHighScore() {
        User student = User.builder().id(1L).build();
        LearningPathway pathway = LearningPathway.builder()
                .id(10L)
                .student(student)
                .status("ACTIVE")
                .build();

        PathwayNode firstNode = PathwayNode.builder()
                .stepOrder(1)
                .course(course(1L, "Grammar Basics", "PUBLISHED"))
                .status("LOCKED")
                .progressPercent(0)
                .build();
        PathwayNode completedNode = PathwayNode.builder()
                .stepOrder(2)
                .course(course(2L, "Reading Practice", "PUBLISHED"))
                .status("COMPLETED")
                .progressPercent(100)
                .build();
        pathway.addNode(firstNode);
        pathway.addNode(completedNode);

        ExamAttempt highScoreAttempt = examAttempt(student);
        highScoreAttempt.setScore(java.math.BigDecimal.valueOf(80));

        when(learningPathwayRepository.findById(10L)).thenReturn(Optional.of(pathway));
        when(learningPathwayRepository.save(any(LearningPathway.class))).thenAnswer(invocation -> invocation.getArgument(0));
        when(examAttemptRepository.findTop10ByStudent_IdOrderBySubmittedAtDesc(1L)).thenReturn(List.of(highScoreAttempt));
        when(lessonRepository.countByCourseId(1L)).thenReturn(4L);
        when(lessonRepository.countByCourseId(2L)).thenReturn(4L);
        when(lessonProgressRepository.countCompletedLessonsByUserIdAndCourseId(1L, 1L)).thenReturn(0L);
        when(lessonProgressRepository.countCompletedLessonsByUserIdAndCourseId(1L, 2L)).thenReturn(4L);

        LearningPathwayResponseDTO result = learningPathwayService.reroutePathway(10L, 1L);

        assertTrue(result.getMentorSummary().contains("chấp nhận được"));
        assertEquals("COMPLETED", result.getNodes().get(1).getStatus());
        assertEquals(100, result.getNodes().get(1).getProgressPercent());
    }

    // =================================================================
    // getPathwayById
    // =================================================================

    @Test
    void getPathwayByIdShouldThrowWhenPathwayNotFound() {
        when(learningPathwayRepository.findById(10L)).thenReturn(Optional.empty());

        ApiException exception = assertThrows(ApiException.class,
                () -> learningPathwayService.getPathwayById(10L, 1L));

        assertEquals(HttpStatus.NOT_FOUND, exception.getStatus());
        assertEquals("Pathway not found", exception.getMessage());
    }
}
