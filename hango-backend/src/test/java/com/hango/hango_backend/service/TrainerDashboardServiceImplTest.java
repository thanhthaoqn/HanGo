package com.hango.hango_backend.service;

import com.hango.hango_backend.dto.CourseLessonDTO;
import com.hango.hango_backend.dto.CourseSessionDTO;
import com.hango.hango_backend.dto.CreateGroupQuestionRequestDTO;
import com.hango.hango_backend.dto.TrainerCourseDetailDTO;
import com.hango.hango_backend.dto.TrainerCoursesResponseDTO;
import com.hango.hango_backend.dto.TrainerCreateCourseRequestDTO;
import com.hango.hango_backend.dto.TrainerCreateExamRequestDTO;
import com.hango.hango_backend.dto.TrainerDashboardSummaryDTO;
import com.hango.hango_backend.dto.TrainerExamResponseDTO;
import com.hango.hango_backend.dto.TrainerSaveExamQuestionsRequestDTO;
import com.hango.hango_backend.entity.Course;
import com.hango.hango_backend.entity.Exam;
import com.hango.hango_backend.entity.ExamQuestion;
import com.hango.hango_backend.entity.Lesson;
import com.hango.hango_backend.entity.Question;
import com.hango.hango_backend.entity.QuestionGroup;
import com.hango.hango_backend.entity.QuestionOption;
import com.hango.hango_backend.entity.Role;
import com.hango.hango_backend.entity.Section;
import com.hango.hango_backend.entity.SystemParameter;
import com.hango.hango_backend.entity.TrainerProfile;
import com.hango.hango_backend.entity.User;
import com.hango.hango_backend.repository.CourseRepository;
import com.hango.hango_backend.repository.EnrollmentRepository;
import com.hango.hango_backend.repository.ExamQuestionRepository;
import com.hango.hango_backend.repository.ExamRepository;
import com.hango.hango_backend.repository.LessonRepository;
import com.hango.hango_backend.repository.QuestionRepository;
import com.hango.hango_backend.repository.SectionRepository;
import com.hango.hango_backend.repository.SystemParameterRepository;
import com.hango.hango_backend.repository.TrainerCourseDetailProjection;
import com.hango.hango_backend.repository.TrainerCourseProjection;
import com.hango.hango_backend.repository.TrainerProfileRepository;
import com.hango.hango_backend.repository.UserRepository;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.mockito.junit.jupiter.MockitoSettings;
import org.mockito.quality.Strictness;

import java.time.LocalDateTime;
import java.util.List;
import java.util.Map;
import java.util.Optional;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.times;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
@MockitoSettings(strictness = Strictness.LENIENT)
class TrainerDashboardServiceImplTest {

    @Mock
    private UserRepository userRepository;
    @Mock
    private CourseRepository courseRepository;
    @Mock
    private EnrollmentRepository enrollmentRepository;
    @Mock
    private ExamRepository examRepository;
    @Mock
    private ExamQuestionRepository examQuestionRepository;
    @Mock
    private SystemParameterRepository systemParameterRepository;
    @Mock
    private SectionRepository sectionRepository;
    @Mock
    private LessonRepository lessonRepository;
    @Mock
    private TrainerQuestionService trainerQuestionService;
    @Mock
    private QuestionRepository questionRepository;
    @Mock
    private TrainerProfileRepository trainerProfileRepository;
    @Mock
    private com.hango.hango_backend.repository.PaymentRepository paymentRepository;
    @Mock
    private com.hango.hango_backend.repository.CourseRatingRepository courseRatingRepository;
    @Mock
    private ExamHistoryService examHistoryService;
    @Mock
    private NotificationService notificationService;

    @InjectMocks
    private TrainerDashboardServiceImpl service;

    private User trainer(Long id, String email) {
        return User.builder().id(id).email(email).build();
    }

    private SystemParameter param(Long id, String value) {
        return SystemParameter.builder().id(id).paramValue(value).build();
    }

    private TrainerCreateCourseRequestDTO createCourseRequest(String categoryKey, String difficultyKey) {
        return TrainerCreateCourseRequestDTO.builder()
                .title("New Course")
                .description("desc")
                .categoryKey(categoryKey)
                .difficultyKey(difficultyKey)
                .build();
    }

    // =================================================================
    // getTrainerDashboardSummary
    // =================================================================

    @Test
    void getTrainerDashboardSummaryShouldThrowWhenUserNotFound() {
        when(userRepository.findByEmail("unknown@example.com")).thenReturn(Optional.empty());

        assertThrows(RuntimeException.class, () -> service.getTrainerDashboardSummary("unknown@example.com"));
    }

    @Test
    void getTrainerDashboardSummaryShouldMapCountsAndCourses() {
        User user = trainer(1L, "trainer@example.com");
        when(userRepository.findByEmail("trainer@example.com")).thenReturn(Optional.of(user));
        when(enrollmentRepository.countDistinctStudentsByCourseCreatorId(1L)).thenReturn(20L);
        when(examRepository.countByCreatedByIdAndDeletedAtIsNull(1L)).thenReturn(2L);
        when(paymentRepository.sumRevenueByTrainerId(1L)).thenReturn(new java.math.BigDecimal("1000000"));
        when(courseRatingRepository.getAverageRatingByTrainerId(1L)).thenReturn(4.5);
        TrainerCourseDetailProjection projectionA = detailProjection(10L, "Course A", LocalDateTime.now());
        when(projectionA.getStatus()).thenReturn("PUBLISHED");
        when(projectionA.getLearnersCount()).thenReturn(null);
        when(projectionA.getLessonsCount()).thenReturn(5L);
        TrainerCourseDetailProjection projectionB = detailProjection(11L, "Course B", LocalDateTime.now());
        when(projectionB.getStatus()).thenReturn("PUBLISHED");
        TrainerCourseDetailProjection projectionC = detailProjection(12L, "Course C", LocalDateTime.now());
        when(projectionC.getStatus()).thenReturn("PUBLISHED");
        when(courseRepository.findTrainerCoursesDetailBase(1L, "ALL", null))
                .thenReturn(List.of(projectionA, projectionB, projectionC));
        when(paymentRepository.getRevenueByMonthForCurrentYear(1L)).thenReturn(List.of());
        when(paymentRepository.findTop5ByCourseCreatorIdAndStatusOrderByCreatedAtDesc(1L, "SUCCESS")).thenReturn(List.of());
        when(enrollmentRepository.findTop5ByCourseCreatorIdOrderByEnrolledAtDesc(1L)).thenReturn(List.of());
        when(courseRatingRepository.findTop5ByCourseCreatorIdOrderByCreatedAtDesc(1L)).thenReturn(List.of());

        TrainerDashboardSummaryDTO result = service.getTrainerDashboardSummary("trainer@example.com");

        assertEquals(3L, result.getCoursesCount());
        assertEquals(20L, result.getLearnersCount());
        assertEquals(2L, result.getExamsCount());
        assertEquals(new java.math.BigDecimal("1000000"), result.getTotalRevenue());
        assertEquals(4.5, result.getAverageRating());
        assertEquals(3, result.getCourses().size());
        assertEquals(0L, result.getCourses().get(0).getLearnersCount());
    }

    // =================================================================
    // getTrainerCourses
    // =================================================================

    @Test
    void getTrainerCoursesShouldThrowWhenUserNotFound() {
        when(userRepository.findByEmail("unknown@example.com")).thenReturn(Optional.empty());

        assertThrows(RuntimeException.class, () -> service.getTrainerCourses("unknown@example.com", "ALL", null, null, null));
    }

    private TrainerCourseDetailProjection detailProjection(Long id, String title, LocalDateTime createdAt) {
        TrainerCourseDetailProjection p = mock(TrainerCourseDetailProjection.class);
        org.mockito.Mockito.lenient().when(p.getId()).thenReturn(id);
        org.mockito.Mockito.lenient().when(p.getTitle()).thenReturn(title);
        org.mockito.Mockito.lenient().when(p.getCreatedAt()).thenReturn(createdAt);
        // Mockito defaults unstubbed boxed Long getters to 0L (not null), which would otherwise
        // collapse every projection into a single "version group" (see getTrainerCourses grouping-by-
        // parentId logic) — stub it explicitly so each projection here is treated as its own course.
        org.mockito.Mockito.lenient().when(p.getParentId()).thenReturn(null);
        return p;
    }

    @Test
    void getTrainerCoursesShouldReturnStatusCountsAndMappedCourses() {
        User user = trainer(1L, "trainer@example.com");
        when(userRepository.findByEmail("trainer@example.com")).thenReturn(Optional.of(user));
        TrainerCourseDetailProjection projectionA = detailProjection(1L, "Course A", LocalDateTime.now());
        when(courseRepository.findTrainerCoursesDetailBase(1L, "ALL", null)).thenReturn(List.of(projectionA));

        TrainerCoursesResponseDTO result = service.getTrainerCourses("trainer@example.com", "ALL", null, null, "ALL");

        assertEquals(1L, result.getAllCount());
        assertEquals(0L, result.getPublishedCount());
        assertEquals(1, result.getCourses().size());
    }

    @Test
    void getTrainerCoursesShouldTrimBlankSearchToNull() {
        User user = trainer(1L, "trainer@example.com");
        when(userRepository.findByEmail("trainer@example.com")).thenReturn(Optional.of(user));
        when(courseRepository.findTrainerCoursesDetailBase(1L, "ALL", null)).thenReturn(List.of());

        service.getTrainerCourses("trainer@example.com", "ALL", "   ", null, "ALL");

        verify(courseRepository).findTrainerCoursesDetailBase(1L, "ALL", null);
    }

    @Test
    void getTrainerCoursesShouldFilterOutCoursesOlderThanOneWeekWhenTimePeriodThisWeek() {
        User user = trainer(1L, "trainer@example.com");
        when(userRepository.findByEmail("trainer@example.com")).thenReturn(Optional.of(user));
        TrainerCourseDetailProjection recent = detailProjection(1L, "Recent", LocalDateTime.now());
        TrainerCourseDetailProjection old = detailProjection(2L, "Old", LocalDateTime.now().minusWeeks(2));
        when(courseRepository.findTrainerCoursesDetailBase(1L, "ALL", null)).thenReturn(List.of(recent, old));

        TrainerCoursesResponseDTO result = service.getTrainerCourses("trainer@example.com", "ALL", null, null, "THIS_WEEK");

        assertEquals(1, result.getCourses().size());
        assertEquals(1L, result.getCourses().get(0).getId());
    }

    @Test
    void getTrainerCoursesShouldSortAlphabeticallyWhenRequested() {
        User user = trainer(1L, "trainer@example.com");
        when(userRepository.findByEmail("trainer@example.com")).thenReturn(Optional.of(user));
        TrainerCourseDetailProjection zebra = detailProjection(1L, "Zebra Course", LocalDateTime.now());
        TrainerCourseDetailProjection alpha = detailProjection(2L, "Alpha Course", LocalDateTime.now());
        when(courseRepository.findTrainerCoursesDetailBase(1L, "ALL", null)).thenReturn(List.of(zebra, alpha));

        TrainerCoursesResponseDTO result = service.getTrainerCourses("trainer@example.com", "ALL", null, "ALPHABETICAL", "ALL");

        assertEquals("Alpha Course", result.getCourses().get(0).getTitle());
        assertEquals("Zebra Course", result.getCourses().get(1).getTitle());
    }

    @Test
    void getTrainerCoursesShouldSortOldestFirstWhenRequested() {
        User user = trainer(1L, "trainer@example.com");
        when(userRepository.findByEmail("trainer@example.com")).thenReturn(Optional.of(user));
        TrainerCourseDetailProjection newer = detailProjection(1L, "Newer", LocalDateTime.now());
        TrainerCourseDetailProjection older = detailProjection(2L, "Older", LocalDateTime.now().minusDays(5));
        when(courseRepository.findTrainerCoursesDetailBase(1L, "ALL", null)).thenReturn(List.of(newer, older));

        TrainerCoursesResponseDTO result = service.getTrainerCourses("trainer@example.com", "ALL", null, "OLDEST", "ALL");

        assertEquals(2L, result.getCourses().get(0).getId());
    }

    @Test
    void getTrainerCoursesShouldDefaultToNewestFirstWhenSortByNull() {
        User user = trainer(1L, "trainer@example.com");
        when(userRepository.findByEmail("trainer@example.com")).thenReturn(Optional.of(user));
        TrainerCourseDetailProjection older2 = detailProjection(1L, "Older", LocalDateTime.now().minusDays(5));
        TrainerCourseDetailProjection newer2 = detailProjection(2L, "Newer", LocalDateTime.now());
        when(courseRepository.findTrainerCoursesDetailBase(1L, "ALL", null)).thenReturn(List.of(older2, newer2));

        TrainerCoursesResponseDTO result = service.getTrainerCourses("trainer@example.com", "ALL", null, null, "ALL");

        assertEquals(2L, result.getCourses().get(0).getId());
    }

    // =================================================================
    // createTrainerCourse
    // =================================================================

    @Test
    void createTrainerCourseShouldThrowWhenUserNotFound() {
        when(userRepository.findByEmail("unknown@example.com")).thenReturn(Optional.empty());

        assertThrows(RuntimeException.class,
                () -> service.createTrainerCourse("unknown@example.com", createCourseRequest("GRAMMAR", "MEDIUM")));
    }

    @Test
    void createTrainerCourseShouldThrowWhenCategoryNotFound() {
        when(userRepository.findByEmail("trainer@example.com")).thenReturn(Optional.of(trainer(1L, "trainer@example.com")));
        when(systemParameterRepository.findByParamTypeAndParamKey("COURSE_CATEGORY", "GRAMMAR")).thenReturn(Optional.empty());

        assertThrows(RuntimeException.class,
                () -> service.createTrainerCourse("trainer@example.com", createCourseRequest("GRAMMAR", "MEDIUM")));
    }

    @Test
    void createTrainerCourseShouldThrowWhenDifficultyNotFound() {
        when(userRepository.findByEmail("trainer@example.com")).thenReturn(Optional.of(trainer(1L, "trainer@example.com")));
        when(systemParameterRepository.findByParamTypeAndParamKey("COURSE_CATEGORY", "GRAMMAR"))
                .thenReturn(Optional.of(param(1L, "Grammar")));
        when(systemParameterRepository.findByParamTypeAndParamKey("ACADEMIC_LEVEL", "MEDIUM")).thenReturn(Optional.empty());

        assertThrows(RuntimeException.class,
                () -> service.createTrainerCourse("trainer@example.com", createCourseRequest("GRAMMAR", "MEDIUM")));
    }

    @Test
    void createTrainerCourseShouldNormalizeReadingCategoryKey() {
        when(userRepository.findByEmail("trainer@example.com")).thenReturn(Optional.of(trainer(1L, "trainer@example.com")));
        when(systemParameterRepository.findByParamTypeAndParamKey("COURSE_CATEGORY", "READING_COMPREHENSION"))
                .thenReturn(Optional.of(param(1L, "Reading")));
        when(systemParameterRepository.findByParamTypeAndParamKey("ACADEMIC_LEVEL", "MEDIUM"))
                .thenReturn(Optional.of(param(2L, "Medium")));

        service.createTrainerCourse("trainer@example.com", createCourseRequest("READING", "MEDIUM"));

        verify(systemParameterRepository).findByParamTypeAndParamKey("COURSE_CATEGORY", "READING_COMPREHENSION");
    }

    @Test
    void createTrainerCourseShouldNormalizeSpeakingCategoryKeyToPronunciation() {
        when(userRepository.findByEmail("trainer@example.com")).thenReturn(Optional.of(trainer(1L, "trainer@example.com")));
        when(systemParameterRepository.findByParamTypeAndParamKey("COURSE_CATEGORY", "PRONUNCIATION"))
                .thenReturn(Optional.of(param(1L, "Pronunciation")));
        when(systemParameterRepository.findByParamTypeAndParamKey("ACADEMIC_LEVEL", "MEDIUM"))
                .thenReturn(Optional.of(param(2L, "Medium")));

        service.createTrainerCourse("trainer@example.com", createCourseRequest("SPEAKING", "MEDIUM"));

        verify(systemParameterRepository).findByParamTypeAndParamKey("COURSE_CATEGORY", "PRONUNCIATION");
    }

    @Test
    void createTrainerCourseShouldNormalizeWritingCategoryKeyToGrammar() {
        when(userRepository.findByEmail("trainer@example.com")).thenReturn(Optional.of(trainer(1L, "trainer@example.com")));
        when(systemParameterRepository.findByParamTypeAndParamKey("COURSE_CATEGORY", "GRAMMAR"))
                .thenReturn(Optional.of(param(1L, "Grammar")));
        when(systemParameterRepository.findByParamTypeAndParamKey("ACADEMIC_LEVEL", "MEDIUM"))
                .thenReturn(Optional.of(param(2L, "Medium")));

        service.createTrainerCourse("trainer@example.com", createCourseRequest("WRITING", "MEDIUM"));

        verify(systemParameterRepository).findByParamTypeAndParamKey("COURSE_CATEGORY", "GRAMMAR");
    }

    @Test
    void createTrainerCourseShouldNormalizeBeginnerDifficultyKeyToBasic() {
        when(userRepository.findByEmail("trainer@example.com")).thenReturn(Optional.of(trainer(1L, "trainer@example.com")));
        when(systemParameterRepository.findByParamTypeAndParamKey("COURSE_CATEGORY", "GRAMMAR"))
                .thenReturn(Optional.of(param(1L, "Grammar")));
        when(systemParameterRepository.findByParamTypeAndParamKey("ACADEMIC_LEVEL", "BASIC"))
                .thenReturn(Optional.of(param(2L, "Basic")));

        service.createTrainerCourse("trainer@example.com", createCourseRequest("WRITING", "BEGINNER"));

        verify(systemParameterRepository).findByParamTypeAndParamKey("ACADEMIC_LEVEL", "BASIC");
    }

    @Test
    void createTrainerCourseShouldSaveNewCourseAsDraft() {
        when(userRepository.findByEmail("trainer@example.com")).thenReturn(Optional.of(trainer(1L, "trainer@example.com")));
        when(systemParameterRepository.findByParamTypeAndParamKey("COURSE_CATEGORY", "GRAMMAR"))
                .thenReturn(Optional.of(param(1L, "Grammar")));
        when(systemParameterRepository.findByParamTypeAndParamKey("ACADEMIC_LEVEL", "MEDIUM"))
                .thenReturn(Optional.of(param(2L, "Medium")));

        service.createTrainerCourse("trainer@example.com", createCourseRequest("GRAMMAR", "MEDIUM"));

        ArgumentCaptor<Course> captor = ArgumentCaptor.forClass(Course.class);
        verify(courseRepository).save(captor.capture());
        assertEquals("DRAFT", captor.getValue().getStatus());
        assertEquals("New Course", captor.getValue().getTitle());
    }

    @Test
    void createTrainerCourseShouldThrowWhenMoreThanThreeCategoriesProvided() {
        when(userRepository.findByEmail("trainer@example.com")).thenReturn(Optional.of(trainer(1L, "trainer@example.com")));
        TrainerCreateCourseRequestDTO request = createCourseRequest(null, "MEDIUM");
        request.setCategoryKeys(List.of("GRAMMAR", "READING", "SPEAKING", "WRITING"));

        assertThrows(IllegalArgumentException.class,
                () -> service.createTrainerCourse("trainer@example.com", request));
    }

    @Test
    void createTrainerCourseShouldThrowWhenNoCategoryProvided() {
        when(userRepository.findByEmail("trainer@example.com")).thenReturn(Optional.of(trainer(1L, "trainer@example.com")));
        TrainerCreateCourseRequestDTO request = createCourseRequest(null, "MEDIUM");

        assertThrows(IllegalArgumentException.class,
                () -> service.createTrainerCourse("trainer@example.com", request));
    }

    @Test
    void createTrainerCourseShouldAcceptUpToThreeCategoryKeys() {
        when(userRepository.findByEmail("trainer@example.com")).thenReturn(Optional.of(trainer(1L, "trainer@example.com")));
        when(systemParameterRepository.findByParamTypeAndParamKey("COURSE_CATEGORY", "GRAMMAR"))
                .thenReturn(Optional.of(param(1L, "Grammar")));
        when(systemParameterRepository.findByParamTypeAndParamKey("COURSE_CATEGORY", "READING_COMPREHENSION"))
                .thenReturn(Optional.of(param(2L, "Reading")));
        when(systemParameterRepository.findByParamTypeAndParamKey("COURSE_CATEGORY", "PRONUNCIATION"))
                .thenReturn(Optional.of(param(3L, "Pronunciation")));
        when(systemParameterRepository.findByParamTypeAndParamKey("ACADEMIC_LEVEL", "MEDIUM"))
                .thenReturn(Optional.of(param(4L, "Medium")));
        TrainerCreateCourseRequestDTO request = createCourseRequest(null, "MEDIUM");
        request.setCategoryKeys(List.of("GRAMMAR", "READING", "SPEAKING"));

        service.createTrainerCourse("trainer@example.com", request);

        ArgumentCaptor<Course> captor = ArgumentCaptor.forClass(Course.class);
        verify(courseRepository).save(captor.capture());
        assertEquals(3, captor.getValue().getCategories().size());
    }

    // =================================================================
    // getSystemParametersByType
    // =================================================================

    @Test
    void getSystemParametersByTypeShouldUppercaseParamType() {
        when(systemParameterRepository.findByParamTypeAndIsActiveTrue("COURSE_CATEGORY")).thenReturn(List.of());

        service.getSystemParametersByType("course_category");

        verify(systemParameterRepository).findByParamTypeAndIsActiveTrue("COURSE_CATEGORY");
    }

    // =================================================================
    // updateTrainerCourse
    // =================================================================

    private Course course(Long id, User creator) {
        return Course.builder().id(id).creator(creator).build();
    }

    @Test
    void updateTrainerCourseShouldThrowWhenCourseNotFound() {
        when(courseRepository.findById(1L)).thenReturn(Optional.empty());

        assertThrows(RuntimeException.class,
                () -> service.updateTrainerCourse(1L, "trainer@example.com", createCourseRequest("GRAMMAR", "MEDIUM")));
    }

    @Test
    void updateTrainerCourseShouldThrowWhenNotAuthorized() {
        Course c = course(1L, trainer(1L, "owner@example.com"));
        when(courseRepository.findById(1L)).thenReturn(Optional.of(c));

        assertThrows(RuntimeException.class,
                () -> service.updateTrainerCourse(1L, "intruder@example.com", createCourseRequest("GRAMMAR", "MEDIUM")));
    }

    @Test
    void updateTrainerCourseShouldDeleteSectionsNotPresentInRequest() {
        Course c = course(1L, trainer(1L, "trainer@example.com"));
        when(courseRepository.findById(1L)).thenReturn(Optional.of(c));
        when(systemParameterRepository.findByParamTypeAndParamKey("COURSE_CATEGORY", "GRAMMAR")).thenReturn(Optional.of(param(1L, "Grammar")));
        when(systemParameterRepository.findByParamTypeAndParamKey("ACADEMIC_LEVEL", "MEDIUM")).thenReturn(Optional.of(param(2L, "Medium")));
        when(courseRepository.save(any(Course.class))).thenReturn(c);
        Section obsoleteSection = Section.builder().id(50L).course(c).build();
        when(sectionRepository.findByCourseIdOrderByDisplayOrderAsc(1L)).thenReturn(List.of(obsoleteSection));

        service.updateTrainerCourse(1L, "trainer@example.com", createCourseRequest("GRAMMAR", "MEDIUM"));

        verify(sectionRepository).delete(obsoleteSection);
    }

    @Test
    void updateTrainerCourseShouldCreateNewSectionAndLessonWhenNoIdsProvided() {
        Course c = course(1L, trainer(1L, "trainer@example.com"));
        when(courseRepository.findById(1L)).thenReturn(Optional.of(c));
        when(systemParameterRepository.findByParamTypeAndParamKey("COURSE_CATEGORY", "GRAMMAR")).thenReturn(Optional.of(param(1L, "Grammar")));
        when(systemParameterRepository.findByParamTypeAndParamKey("ACADEMIC_LEVEL", "MEDIUM")).thenReturn(Optional.of(param(2L, "Medium")));
        when(courseRepository.save(any(Course.class))).thenReturn(c);
        when(sectionRepository.findByCourseIdOrderByDisplayOrderAsc(1L)).thenReturn(List.of());
        when(sectionRepository.save(any(Section.class))).thenAnswer(inv -> {
            Section s = inv.getArgument(0);
            s.setId(100L);
            return s;
        });
        when(lessonRepository.findBySectionIdOrderByDisplayOrderAsc(100L)).thenReturn(List.of());

        CourseLessonDTO lessonDto = CourseLessonDTO.builder().title("Lesson 1").build();
        CourseSessionDTO sessionDto = CourseSessionDTO.builder().title("Section 1").lessons(List.of(lessonDto)).build();
        TrainerCreateCourseRequestDTO req = createCourseRequest("GRAMMAR", "MEDIUM");
        req.setSessions(List.of(sessionDto));

        service.updateTrainerCourse(1L, "trainer@example.com", req);

        ArgumentCaptor<Lesson> lessonCaptor = ArgumentCaptor.forClass(Lesson.class);
        verify(lessonRepository).save(lessonCaptor.capture());
        assertEquals("video", lessonCaptor.getValue().getLessonType());
        assertEquals("Grammar", lessonCaptor.getValue().getSkill().getParamValue());
    }

    @Test
    void updateTrainerCourseShouldDeleteLessonsNotPresentInSectionRequest() {
        Course c = course(1L, trainer(1L, "trainer@example.com"));
        when(courseRepository.findById(1L)).thenReturn(Optional.of(c));
        when(systemParameterRepository.findByParamTypeAndParamKey("COURSE_CATEGORY", "GRAMMAR")).thenReturn(Optional.of(param(1L, "Grammar")));
        when(systemParameterRepository.findByParamTypeAndParamKey("ACADEMIC_LEVEL", "MEDIUM")).thenReturn(Optional.of(param(2L, "Medium")));
        when(courseRepository.save(any(Course.class))).thenReturn(c);
        Section existingSection = Section.builder().id(50L).course(c).build();
        when(sectionRepository.findByCourseIdOrderByDisplayOrderAsc(1L)).thenReturn(List.of(existingSection));
        when(sectionRepository.findById(50L)).thenReturn(Optional.of(existingSection));
        when(sectionRepository.save(any(Section.class))).thenAnswer(inv -> inv.getArgument(0));
        Lesson obsoleteLesson = Lesson.builder().id(500L).section(existingSection).build();
        when(lessonRepository.findBySectionIdOrderByDisplayOrderAsc(50L)).thenReturn(List.of(obsoleteLesson));

        CourseSessionDTO sessionDto = CourseSessionDTO.builder().id(50L).title("Section 1").lessons(List.of()).build();
        TrainerCreateCourseRequestDTO req = createCourseRequest("GRAMMAR", "MEDIUM");
        req.setSessions(List.of(sessionDto));

        service.updateTrainerCourse(1L, "trainer@example.com", req);

        verify(lessonRepository).delete(obsoleteLesson);
    }

    @Test
    void updateTrainerCourseShouldCreateNewDraftVersionWhenPublishedCourseHasEnrollments() {
        Course c = course(1L, trainer(1L, "trainer@example.com"));
        c.setStatus("PUBLISHED");
        c.setVersion("v1");
        c.setCode("ENG-101");
        when(courseRepository.findById(1L)).thenReturn(Optional.of(c));
        when(systemParameterRepository.findByParamTypeAndParamKey("COURSE_CATEGORY", "GRAMMAR")).thenReturn(Optional.of(param(1L, "Grammar")));
        when(systemParameterRepository.findByParamTypeAndParamKey("ACADEMIC_LEVEL", "MEDIUM")).thenReturn(Optional.of(param(2L, "Medium")));
        when(enrollmentRepository.countByCourseId(1L)).thenReturn(3);
        when(courseRepository.existsByCodeIgnoreCase(any())).thenReturn(false);
        when(courseRepository.save(any(Course.class))).thenAnswer(inv -> {
            Course saved = inv.getArgument(0);
            if (saved.getId() == null) {
                saved.setId(2L);
            }
            return saved;
        });

        Long resultId = service.updateTrainerCourse(1L, "trainer@example.com", createCourseRequest("GRAMMAR", "MEDIUM"));

        ArgumentCaptor<Course> captor = ArgumentCaptor.forClass(Course.class);
        verify(courseRepository, times(1)).save(captor.capture());
        assertEquals("DRAFT", captor.getValue().getStatus());
        assertEquals(1L, captor.getValue().getParentId());
        assertEquals("v2", captor.getValue().getVersion());
        assertEquals(2L, resultId);
    }

    @Test
    void updateTrainerCourseShouldThrowWhenNewCodeAlreadyUsedByAnotherCourse() {
        Course c = course(1L, trainer(1L, "trainer@example.com"));
        c.setCode("ENG-101");
        when(courseRepository.findById(1L)).thenReturn(Optional.of(c));
        when(systemParameterRepository.findByParamTypeAndParamKey("COURSE_CATEGORY", "GRAMMAR")).thenReturn(Optional.of(param(1L, "Grammar")));
        when(systemParameterRepository.findByParamTypeAndParamKey("ACADEMIC_LEVEL", "MEDIUM")).thenReturn(Optional.of(param(2L, "Medium")));
        when(courseRepository.existsByCodeIgnoreCaseAndIdNot("ENG-202", 1L)).thenReturn(true);
        TrainerCreateCourseRequestDTO request = createCourseRequest("GRAMMAR", "MEDIUM");
        request.setCode("ENG-202");

        assertThrows(RuntimeException.class,
                () -> service.updateTrainerCourse(1L, "trainer@example.com", request));
        verify(courseRepository, never()).save(any());
    }

    // =================================================================
    // getTrainerExams
    // =================================================================

    @Test
    void getTrainerExamsShouldThrowWhenUserNotFound() {
        when(userRepository.findByEmail("unknown@example.com")).thenReturn(Optional.empty());

        assertThrows(RuntimeException.class, () -> service.getTrainerExams("unknown@example.com"));
    }

    @Test
    void getTrainerExamsShouldDefaultStatusAndVisibilityWhenNull() {
        User user = trainer(1L, "trainer@example.com");
        Exam exam = new Exam();
        exam.setId(1L);
        exam.setTitle("Exam A");
        when(userRepository.findByEmail("trainer@example.com")).thenReturn(Optional.of(user));
        when(examRepository.findByCreatedByIdAndDeletedAtIsNullOrderByCreatedAtDesc(1L))
                .thenReturn(new java.util.ArrayList<>(List.of(exam)));
        when(examQuestionRepository.countQuestionsByExamIds(List.of(1L)))
                .thenReturn(List.<Object[]>of(new Object[] { 1L, 5 }));

        List<TrainerExamResponseDTO> result = service.getTrainerExams("trainer@example.com");

        assertEquals("private", result.get(0).getStatus());
        assertEquals("PRIVATE", result.get(0).getVisibility());
        assertEquals(5, result.get(0).getQuestionCount());
    }

    @Test
    void getTrainerExamsShouldIncludeAllExamsButFilterOutOtherUsersDraftsWhenCallerIsManager() {
        User manager = trainer(1L, "manager@example.com");
        manager.setRoles(java.util.Set.of(Role.builder().roleName("COURSE_MANAGER").build()));
        when(userRepository.findByEmail("manager@example.com")).thenReturn(Optional.of(manager));

        Exam ownDraft = new Exam();
        ownDraft.setId(1L);
        ownDraft.setStatus("DRAFT");
        ownDraft.setCreatedBy(manager);

        Exam othersDraft = new Exam();
        othersDraft.setId(2L);
        othersDraft.setStatus("DRAFT");
        othersDraft.setCreatedBy(trainer(2L, "other@example.com"));

        Exam published = new Exam();
        published.setId(3L);
        published.setStatus("PUBLISHED");
        published.setCreatedBy(trainer(2L, "other@example.com"));

        when(examRepository.findByDeletedAtIsNullOrderByCreatedAtDesc())
                .thenReturn(new java.util.ArrayList<>(List.of(ownDraft, othersDraft, published)));
        when(examQuestionRepository.countByIdExamId(any())).thenReturn(0);

        List<TrainerExamResponseDTO> result = service.getTrainerExams("manager@example.com");

        assertEquals(2, result.size());
        assertTrue(result.stream().noneMatch(e -> e.getId().equals(2L)));
    }

    // =================================================================
    // createTrainerExam
    // =================================================================

    @Test
    void createTrainerExamShouldThrowWhenUserNotFound() {
        when(userRepository.findByEmail("unknown@example.com")).thenReturn(Optional.empty());

        assertThrows(RuntimeException.class, () -> service.createTrainerExam("unknown@example.com",
                TrainerCreateExamRequestDTO.builder().title("Exam").build()));
    }

    @Test
    void createTrainerExamShouldSaveAsDraftAndPrivate() {
        when(userRepository.findByEmail("trainer@example.com")).thenReturn(Optional.of(trainer(1L, "trainer@example.com")));
        when(examRepository.save(any(Exam.class))).thenAnswer(inv -> {
            Exam saved = inv.getArgument(0);
            saved.setId(99L);
            return saved;
        });

        service.createTrainerExam("trainer@example.com", TrainerCreateExamRequestDTO.builder().title("Exam A").build());

        ArgumentCaptor<Exam> captor = ArgumentCaptor.forClass(Exam.class);
        verify(examRepository).save(captor.capture());
        assertEquals("DRAFT", captor.getValue().getStatus());
        assertEquals("PRIVATE", captor.getValue().getVisibility());
    }

    // =================================================================
    // saveExamQuestions
    // =================================================================

    @Test
    void saveExamQuestionsShouldThrowWhenExamNotFound() {
        when(examRepository.findById(1L)).thenReturn(Optional.empty());

        assertThrows(RuntimeException.class,
                () -> service.saveExamQuestions(1L, "trainer@example.com", new TrainerSaveExamQuestionsRequestDTO()));
    }

    @Test
    void saveExamQuestionsShouldThrowWhenNotOwner() {
        Exam exam = new Exam();
        exam.setId(1L);
        exam.setCreatedBy(trainer(1L, "owner@example.com"));
        when(examRepository.findById(1L)).thenReturn(Optional.of(exam));

        assertThrows(RuntimeException.class,
                () -> service.saveExamQuestions(1L, "intruder@example.com", new TrainerSaveExamQuestionsRequestDTO()));
    }

    @Test
    void saveExamQuestionsShouldDeleteExistingThenRecreateFromBlocks() {
        Exam exam = new Exam();
        exam.setId(1L);
        exam.setCreatedBy(trainer(1L, "trainer@example.com"));
        when(examRepository.findById(1L)).thenReturn(Optional.of(exam));
        CreateGroupQuestionRequestDTO block = CreateGroupQuestionRequestDTO.builder().build();
        when(trainerQuestionService.createQuestionBankGroup("trainer@example.com", block))
                .thenReturn(Map.of("questionIds", List.of(11L, 12L)));

        TrainerSaveExamQuestionsRequestDTO req = new TrainerSaveExamQuestionsRequestDTO();
        req.setBlocks(List.of(block));
        service.saveExamQuestions(1L, "trainer@example.com", req);

        verify(examQuestionRepository).deleteByIdExamId(1L);
        ArgumentCaptor<ExamQuestion> captor = ArgumentCaptor.forClass(ExamQuestion.class);
        verify(examQuestionRepository, times(2)).save(captor.capture());
        assertEquals(1, captor.getAllValues().get(0).getQuestionOrder());
        assertEquals(2, captor.getAllValues().get(1).getQuestionOrder());
    }

    @Test
    void saveExamQuestionsShouldSkipBlockWhenNoQuestionIdsReturned() {
        Exam exam = new Exam();
        exam.setId(1L);
        exam.setCreatedBy(trainer(1L, "trainer@example.com"));
        when(examRepository.findById(1L)).thenReturn(Optional.of(exam));
        CreateGroupQuestionRequestDTO block = CreateGroupQuestionRequestDTO.builder().build();
        when(trainerQuestionService.createQuestionBankGroup("trainer@example.com", block)).thenReturn(Map.of());

        TrainerSaveExamQuestionsRequestDTO req = new TrainerSaveExamQuestionsRequestDTO();
        req.setBlocks(List.of(block));
        service.saveExamQuestions(1L, "trainer@example.com", req);

        verify(examQuestionRepository, never()).save(any());
    }

    // =================================================================
    // getExamQuestions
    // =================================================================

    @Test
    void getExamQuestionsShouldThrowWhenExamNotFound() {
        when(examRepository.findById(1L)).thenReturn(Optional.empty());

        assertThrows(RuntimeException.class, () -> service.getExamQuestions(1L, "trainer@example.com"));
    }

    @Test
    void getExamQuestionsShouldGroupSubQuestionsByQuestionGroup() {
        Exam exam = new Exam();
        exam.setId(1L);
        when(examRepository.findById(1L)).thenReturn(Optional.of(exam));

        QuestionGroup group = new QuestionGroup();
        group.setId(500L);
        group.setContextText("Reading passage");

        Question q1 = new Question();
        q1.setQuestionText("Q1");
        q1.setQuestionGroup(group);
        q1.setOptions(List.of());

        Question q2 = new Question();
        q2.setQuestionText("Q2");
        q2.setQuestionGroup(group);
        q2.setOptions(List.of());

        Question q3 = new Question();
        q3.setQuestionText("Q3 standalone");
        q3.setQuestionGroup(null);
        QuestionOption opt = new QuestionOption();
        opt.setOptionText("A");
        opt.setIsCorrect(true);
        q3.setOptions(List.of(opt));

        when(questionRepository.findByExamIdOrderByQuestionOrder(1L)).thenReturn(List.of(q1, q2, q3));

        TrainerSaveExamQuestionsRequestDTO result = service.getExamQuestions(1L, "trainer@example.com");

        assertEquals(2, result.getBlocks().size());
        assertEquals(2, result.getBlocks().get(0).getSubQuestions().size());
        assertEquals("Reading passage", result.getBlocks().get(0).getPassageText());
        assertEquals(1, result.getBlocks().get(1).getSubQuestions().size());
        assertNull(result.getBlocks().get(1).getPassageText());
    }

    // =================================================================
    // updateExamStatus
    // =================================================================

    @Test
    void updateExamStatusShouldThrowWhenUserNotFound() {
        when(userRepository.findByEmail("unknown@example.com")).thenReturn(Optional.empty());

        assertThrows(RuntimeException.class, () -> service.updateExamStatus(1L, "unknown@example.com", "PUBLISHED"));
    }

    @Test
    void updateExamStatusShouldThrowWhenExamNotFound() {
        when(userRepository.findByEmail("trainer@example.com")).thenReturn(Optional.of(trainer(1L, "trainer@example.com")));
        when(examRepository.findById(1L)).thenReturn(Optional.empty());

        assertThrows(RuntimeException.class, () -> service.updateExamStatus(1L, "trainer@example.com", "PUBLISHED"));
    }

    @Test
    void updateExamStatusShouldThrowWhenNotOwner() {
        when(userRepository.findByEmail("intruder@example.com")).thenReturn(Optional.of(trainer(2L, "intruder@example.com")));
        Exam exam = new Exam();
        exam.setId(1L);
        exam.setCreatedBy(trainer(1L, "owner@example.com"));
        when(examRepository.findById(1L)).thenReturn(Optional.of(exam));

        assertThrows(RuntimeException.class, () -> service.updateExamStatus(1L, "intruder@example.com", "PUBLISHED"));
    }

    @Test
    void updateExamStatusShouldThrowWhenTrainerTriesToPublishOwnExam() {
        when(userRepository.findByEmail("trainer@example.com")).thenReturn(Optional.of(trainer(1L, "trainer@example.com")));
        Exam exam = new Exam();
        exam.setId(1L);
        exam.setCreatedBy(trainer(1L, "trainer@example.com"));
        when(examRepository.findById(1L)).thenReturn(Optional.of(exam));

        assertThrows(org.springframework.security.access.AccessDeniedException.class,
                () -> service.updateExamStatus(1L, "trainer@example.com", "PUBLISHED"));
        verify(examRepository, never()).save(any());
    }

    @Test
    void updateExamStatusShouldThrowWhenTrainerTriesToRejectOwnExam() {
        when(userRepository.findByEmail("trainer@example.com")).thenReturn(Optional.of(trainer(1L, "trainer@example.com")));
        Exam exam = new Exam();
        exam.setId(1L);
        exam.setCreatedBy(trainer(1L, "trainer@example.com"));
        when(examRepository.findById(1L)).thenReturn(Optional.of(exam));

        assertThrows(org.springframework.security.access.AccessDeniedException.class,
                () -> service.updateExamStatus(1L, "trainer@example.com", "REJECTED"));
        verify(examRepository, never()).save(any());
    }

    @Test
    void updateExamStatusShouldAllowTrainerToSubmitOwnExamForReview() {
        when(userRepository.findByEmail("trainer@example.com")).thenReturn(Optional.of(trainer(1L, "trainer@example.com")));
        Exam exam = new Exam();
        exam.setId(1L);
        exam.setStatus("DRAFT");
        exam.setCreatedBy(trainer(1L, "trainer@example.com"));
        when(examRepository.findById(1L)).thenReturn(Optional.of(exam));

        service.updateExamStatus(1L, "trainer@example.com", "SUBMITTED");

        assertEquals("SUBMITTED", exam.getStatus());
        verify(examRepository).save(exam);
    }

    @Test
    void updateExamStatusShouldAllowManagerToPublishAnotherTrainersSubmittedExam() {
        User manager = trainer(2L, "manager@example.com");
        manager.setRoles(java.util.Set.of(Role.builder().roleName("COURSE_MANAGER").build()));
        when(userRepository.findByEmail("manager@example.com")).thenReturn(Optional.of(manager));

        Exam exam = new Exam();
        exam.setId(1L);
        exam.setStatus("SUBMITTED");
        exam.setCreatedBy(trainer(1L, "trainer@example.com"));
        when(examRepository.findById(1L)).thenReturn(Optional.of(exam));

        service.updateExamStatus(1L, "manager@example.com", "PUBLISHED");

        assertEquals("PUBLISHED", exam.getStatus());
        verify(examRepository).save(exam);
    }

    @Test
    void updateExamStatusShouldAllowManagerToRejectAnotherTrainersSubmittedExam() {
        User manager = trainer(2L, "manager@example.com");
        manager.setRoles(java.util.Set.of(Role.builder().roleName("COURSE_MANAGER").build()));
        when(userRepository.findByEmail("manager@example.com")).thenReturn(Optional.of(manager));

        Exam exam = new Exam();
        exam.setId(1L);
        exam.setStatus("SUBMITTED");
        exam.setCreatedBy(trainer(1L, "trainer@example.com"));
        when(examRepository.findById(1L)).thenReturn(Optional.of(exam));

        service.updateExamStatus(1L, "manager@example.com", "REJECTED");

        assertEquals("REJECTED", exam.getStatus());
        verify(examRepository).save(exam);
    }

    @Test
    void updateExamStatusShouldSetNewStatusForNonPrivilegedStatusWhenOwnerIsNotManager() {
        when(userRepository.findByEmail("trainer@example.com")).thenReturn(Optional.of(trainer(1L, "trainer@example.com")));
        Exam exam = new Exam();
        exam.setId(1L);
        exam.setCreatedBy(trainer(1L, "trainer@example.com"));
        when(examRepository.findById(1L)).thenReturn(Optional.of(exam));

        service.updateExamStatus(1L, "trainer@example.com", "DRAFT");

        assertEquals("DRAFT", exam.getStatus());
        verify(examRepository).save(exam);
    }

    @Test
    void updateExamStatusShouldThrowWhenNonManagerOwnerTriesToPublish() {
        when(userRepository.findByEmail("trainer@example.com")).thenReturn(Optional.of(trainer(1L, "trainer@example.com")));
        Exam exam = new Exam();
        exam.setId(1L);
        exam.setCreatedBy(trainer(1L, "trainer@example.com"));
        when(examRepository.findById(1L)).thenReturn(Optional.of(exam));

        assertThrows(org.springframework.security.access.AccessDeniedException.class,
                () -> service.updateExamStatus(1L, "trainer@example.com", "PUBLISHED"));
        verify(examRepository, never()).save(any());
    }

    @Test
    void updateExamStatusShouldThrowWhenNonManagerOwnerTriesToApprove() {
        when(userRepository.findByEmail("trainer@example.com")).thenReturn(Optional.of(trainer(1L, "trainer@example.com")));
        Exam exam = new Exam();
        exam.setId(1L);
        exam.setCreatedBy(trainer(1L, "trainer@example.com"));
        when(examRepository.findById(1L)).thenReturn(Optional.of(exam));

        assertThrows(org.springframework.security.access.AccessDeniedException.class,
                () -> service.updateExamStatus(1L, "trainer@example.com", "APPROVED"));
        verify(examRepository, never()).save(any());
    }

    @Test
    void updateExamStatusShouldAllowManagerToPublishAnotherTrainersExamDirectly() {
        User manager = trainer(1L, "manager@example.com");
        manager.setRoles(java.util.Set.of(Role.builder().roleName("COURSE_MANAGER").build()));
        when(userRepository.findByEmail("manager@example.com")).thenReturn(Optional.of(manager));
        Exam exam = new Exam();
        exam.setId(2L);
        exam.setCreatedBy(trainer(2L, "trainer@example.com"));
        when(examRepository.findById(2L)).thenReturn(Optional.of(exam));

        service.updateExamStatus(2L, "manager@example.com", "PUBLISHED");

        assertEquals("PUBLISHED", exam.getStatus());
        verify(examRepository).save(exam);
    }

    // =================================================================
    // deleteTrainerExam
    // =================================================================

    @Test
    void deleteTrainerExamShouldThrowWhenNotOwner() {
        when(userRepository.findByEmail("intruder@example.com")).thenReturn(Optional.of(trainer(2L, "intruder@example.com")));
        Exam exam = new Exam();
        exam.setId(1L);
        exam.setCreatedBy(trainer(1L, "owner@example.com"));
        when(examRepository.findById(1L)).thenReturn(Optional.of(exam));

        assertThrows(RuntimeException.class, () -> service.deleteTrainerExam(1L, "intruder@example.com"));
    }

    @Test
    void deleteTrainerExamShouldSetDeletedAt() {
        when(userRepository.findByEmail("trainer@example.com")).thenReturn(Optional.of(trainer(1L, "trainer@example.com")));
        Exam exam = new Exam();
        exam.setId(1L);
        exam.setCreatedBy(trainer(1L, "trainer@example.com"));
        when(examRepository.findById(1L)).thenReturn(Optional.of(exam));

        service.deleteTrainerExam(1L, "trainer@example.com");

        assertTrue(exam.getDeletedAt() != null);
        verify(examRepository).save(exam);
    }

    // =================================================================
    // publishTrainerCourse
    // =================================================================

    @Test
    void publishTrainerCourseShouldThrowWhenCourseNotFound() {
        when(courseRepository.findById(1L)).thenReturn(Optional.empty());

        assertThrows(RuntimeException.class, () -> service.publishTrainerCourse(1L, "trainer@example.com"));
    }

    @Test
    void publishTrainerCourseShouldThrowWhenNotOwner() {
        Course c = course(1L, trainer(1L, "owner@example.com"));
        when(courseRepository.findById(1L)).thenReturn(Optional.of(c));

        assertThrows(RuntimeException.class, () -> service.publishTrainerCourse(1L, "intruder@example.com"));
    }

    @Test
    void publishTrainerCourseShouldThrowWhenTrainerProfileNotVerified() {
        Course c = course(1L, trainer(1L, "trainer@example.com"));
        when(courseRepository.findById(1L)).thenReturn(Optional.of(c));
        when(trainerProfileRepository.findById(1L)).thenReturn(Optional.of(
                TrainerProfile.builder().userId(1L).status("AWAITING_APPROVAL").build()));

        assertThrows(IllegalStateException.class, () -> service.publishTrainerCourse(1L, "trainer@example.com"));
        verify(courseRepository, never()).save(any());
    }

    @Test
    void publishTrainerCourseShouldSetPublishedWhenTrainerVerified() {
        Course c = course(1L, trainer(1L, "trainer@example.com"));
        when(courseRepository.findById(1L)).thenReturn(Optional.of(c));
        when(trainerProfileRepository.findById(1L)).thenReturn(Optional.of(
                TrainerProfile.builder().userId(1L).status("VERIFIED").build()));

        service.publishTrainerCourse(1L, "trainer@example.com");

        assertEquals("PUBLISHED", c.getStatus());
        verify(courseRepository).save(c);
    }

    // =================================================================
    // submitTrainerCourse
    // =================================================================

    @Test
    void submitTrainerCourseShouldThrowWhenCourseNotFound() {
        when(courseRepository.findById(1L)).thenReturn(Optional.empty());

        assertThrows(RuntimeException.class, () -> service.submitTrainerCourse(1L, "trainer@example.com"));
    }

    @Test
    void submitTrainerCourseShouldThrowWhenNotAuthorized() {
        Course c = course(1L, trainer(1L, "owner@example.com"));
        when(courseRepository.findById(1L)).thenReturn(Optional.of(c));

        assertThrows(RuntimeException.class, () -> service.submitTrainerCourse(1L, "intruder@example.com"));
    }

    @Test
    void submitTrainerCourseShouldThrowWhenCourseNotDraft() {
        Course c = course(1L, trainer(1L, "trainer@example.com"));
        c.setStatus("PUBLISHED");
        when(courseRepository.findById(1L)).thenReturn(Optional.of(c));

        assertThrows(RuntimeException.class, () -> service.submitTrainerCourse(1L, "trainer@example.com"));
    }

    @Test
    void submitTrainerCourseShouldSetPendingApprovalWhenDraft() {
        Course c = course(1L, trainer(1L, "trainer@example.com"));
        when(courseRepository.findById(1L)).thenReturn(Optional.of(c));

        service.submitTrainerCourse(1L, "trainer@example.com");

        assertEquals("PENDING_APPROVAL", c.getStatus());
        verify(courseRepository).save(c);
    }

    // =================================================================
    // updateExamVisibility
    // =================================================================

    @Test
    void updateExamVisibilityShouldThrowWhenUserNotFound() {
        when(userRepository.findByEmail("unknown@example.com")).thenReturn(Optional.empty());

        assertThrows(RuntimeException.class, () -> service.updateExamVisibility(1L, "unknown@example.com", "PUBLIC"));
    }

    @Test
    void updateExamVisibilityShouldThrowWhenExamNotFound() {
        when(userRepository.findByEmail("trainer@example.com")).thenReturn(Optional.of(trainer(1L, "trainer@example.com")));
        when(examRepository.findById(1L)).thenReturn(Optional.empty());

        assertThrows(RuntimeException.class, () -> service.updateExamVisibility(1L, "trainer@example.com", "PUBLIC"));
    }

    @Test
    void updateExamVisibilityShouldThrowWhenNotOwner() {
        when(userRepository.findByEmail("intruder@example.com")).thenReturn(Optional.of(trainer(2L, "intruder@example.com")));
        Exam exam = new Exam();
        exam.setId(1L);
        exam.setCreatedBy(trainer(1L, "owner@example.com"));
        when(examRepository.findById(1L)).thenReturn(Optional.of(exam));

        assertThrows(RuntimeException.class, () -> service.updateExamVisibility(1L, "intruder@example.com", "PUBLIC"));
    }

    @Test
    void updateExamVisibilityShouldSetNewVisibility() {
        when(userRepository.findByEmail("trainer@example.com")).thenReturn(Optional.of(trainer(1L, "trainer@example.com")));
        Exam exam = new Exam();
        exam.setId(1L);
        exam.setCreatedBy(trainer(1L, "trainer@example.com"));
        when(examRepository.findById(1L)).thenReturn(Optional.of(exam));

        service.updateExamVisibility(1L, "trainer@example.com", "PUBLIC");

        assertEquals("PUBLIC", exam.getVisibility());
        verify(examRepository).save(exam);
    }

    // =================================================================
    // deleteTrainerCourse
    // =================================================================

    @Test
    void deleteTrainerCourseShouldThrowWhenUserNotFound() {
        when(userRepository.findByEmail("unknown@example.com")).thenReturn(Optional.empty());

        assertThrows(RuntimeException.class, () -> service.deleteTrainerCourse(1L, "unknown@example.com"));
    }

    @Test
    void deleteTrainerCourseShouldThrowWhenCourseNotFound() {
        when(userRepository.findByEmail("trainer@example.com")).thenReturn(Optional.of(trainer(1L, "trainer@example.com")));
        when(courseRepository.findById(1L)).thenReturn(Optional.empty());

        assertThrows(RuntimeException.class, () -> service.deleteTrainerCourse(1L, "trainer@example.com"));
    }

    @Test
    void deleteTrainerCourseShouldThrowWhenNotOwner() {
        when(userRepository.findByEmail("intruder@example.com")).thenReturn(Optional.of(trainer(2L, "intruder@example.com")));
        Course c = course(1L, trainer(1L, "owner@example.com"));
        when(courseRepository.findById(1L)).thenReturn(Optional.of(c));

        assertThrows(RuntimeException.class, () -> service.deleteTrainerCourse(1L, "intruder@example.com"));
    }

    @Test
    void deleteTrainerCourseShouldThrowWhenStatusNotDraftOrRejected() {
        when(userRepository.findByEmail("trainer@example.com")).thenReturn(Optional.of(trainer(1L, "trainer@example.com")));
        Course c = course(1L, trainer(1L, "trainer@example.com"));
        c.setStatus("PUBLISHED");
        when(courseRepository.findById(1L)).thenReturn(Optional.of(c));

        assertThrows(RuntimeException.class, () -> service.deleteTrainerCourse(1L, "trainer@example.com"));
        verify(courseRepository, never()).delete(any());
    }

    @Test
    void deleteTrainerCourseShouldHardDeleteSectionsAndCourseWhenOwnerAndDraft() {
        when(userRepository.findByEmail("trainer@example.com")).thenReturn(Optional.of(trainer(1L, "trainer@example.com")));
        Course c = course(1L, trainer(1L, "trainer@example.com"));
        c.setStatus("DRAFT");
        when(courseRepository.findById(1L)).thenReturn(Optional.of(c));
        Section section = Section.builder().id(50L).course(c).build();
        when(sectionRepository.findByCourseIdOrderByDisplayOrderAsc(1L)).thenReturn(List.of(section));

        service.deleteTrainerCourse(1L, "trainer@example.com");

        verify(sectionRepository).deleteAll(List.of(section));
        verify(courseRepository).delete(c);
    }

    // =================================================================
    // reEvaluateCoursePrice
    // =================================================================

    @Test
    void reEvaluateCoursePriceShouldThrowWhenCourseNotFound() {
        when(courseRepository.findById(1L)).thenReturn(Optional.empty());

        assertThrows(RuntimeException.class, () -> service.reEvaluateCoursePrice(1L, "trainer@example.com"));
    }

    @Test
    void reEvaluateCoursePriceShouldThrowWhenNotOwner() {
        Course c = course(1L, trainer(1L, "owner@example.com"));
        when(courseRepository.findById(1L)).thenReturn(Optional.of(c));

        assertThrows(RuntimeException.class, () -> service.reEvaluateCoursePrice(1L, "intruder@example.com"));
    }

    @Test
    void reEvaluateCoursePriceShouldSumProfessionalCertifiedTrainerAdvancedDifficultyAndLessonCount() {
        User owner = trainer(1L, "trainer@example.com");
        Course c = course(1L, owner);
        c.setDifficulty(SystemParameter.builder().id(9L).paramKey("ADVANCED").build());
        when(courseRepository.findById(1L)).thenReturn(Optional.of(c));
        TrainerProfile profile = TrainerProfile.builder().userId(1L).trainerType("PROFESSIONAL")
                .scoreReportUrl("https://example.com/ielts.pdf").build();
        when(trainerProfileRepository.findById(1L)).thenReturn(Optional.of(profile));
        Section section = Section.builder().id(20L).build();
        when(sectionRepository.findByCourseIdOrderByDisplayOrderAsc(1L)).thenReturn(List.of(section));
        when(lessonRepository.findBySectionIdOrderByDisplayOrderAsc(20L))
                .thenReturn(List.of(new Lesson(), new Lesson()));

        service.reEvaluateCoursePrice(1L, "trainer@example.com");

        assertEquals(0, java.math.BigDecimal.valueOf(670000).compareTo(c.getSuggestedPrice()));
        verify(courseRepository).save(c);
    }

    @Test
    void reEvaluateCoursePriceShouldTreatMissingTrainerProfileAndDifficultyAsZeroBaseContribution() {
        User owner = trainer(1L, "trainer@example.com");
        Course c = course(1L, owner);
        when(courseRepository.findById(1L)).thenReturn(Optional.of(c));
        when(trainerProfileRepository.findById(1L)).thenReturn(Optional.empty());
        when(sectionRepository.findByCourseIdOrderByDisplayOrderAsc(1L)).thenReturn(List.of());

        service.reEvaluateCoursePrice(1L, "trainer@example.com");

        assertEquals(0, java.math.BigDecimal.ZERO.compareTo(c.getSuggestedPrice()));
        verify(courseRepository).save(c);
    }

}
