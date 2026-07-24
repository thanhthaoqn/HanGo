package com.hango.hango_backend.service;

import java.util.List;
import java.util.Optional;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyInt;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.times;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;
import org.mockito.junit.jupiter.MockitoExtension;

import com.hango.hango_backend.dto.ExamMatrixCreateRequestDTO;
import com.hango.hango_backend.dto.ExamMatrixDTO;
import com.hango.hango_backend.entity.Exam;
import com.hango.hango_backend.entity.ExamMatrix;
import com.hango.hango_backend.entity.ExamMatrixDetail;
import com.hango.hango_backend.entity.Question;
import com.hango.hango_backend.entity.QuestionCategory;
import com.hango.hango_backend.entity.SystemParameter;
import com.hango.hango_backend.entity.User;
import com.hango.hango_backend.repository.ExamMatrixDetailRepository;
import com.hango.hango_backend.repository.ExamMatrixRepository;
import com.hango.hango_backend.repository.ExamQuestionRepository;
import com.hango.hango_backend.repository.ExamRepository;
import com.hango.hango_backend.repository.QuestionCategoryRepository;
import com.hango.hango_backend.repository.QuestionRepository;
import com.hango.hango_backend.repository.SystemParameterRepository;
import com.hango.hango_backend.repository.UserRepository;

@ExtendWith(MockitoExtension.class)
class TrainerExamMatrixServiceTest {

    @Mock
    private ExamMatrixRepository examMatrixRepository;
    @Mock
    private ExamMatrixDetailRepository examMatrixDetailRepository;
    @Mock
    private UserRepository userRepository;
    @Mock
    private SystemParameterRepository systemParameterRepository;
    @Mock
    private QuestionCategoryRepository questionCategoryRepository;
    @Mock
    private QuestionRepository questionRepository;
    @Mock
    private ExamRepository examRepository;
    @Mock
    private ExamQuestionRepository examQuestionRepository;

    @InjectMocks
    private TrainerExamMatrixServiceImpl service;

    private User user(Long id, String email) {
        return User.builder().id(id).email(email).fullName("Trainer").build();
    }

    private SystemParameter param(Long id, String value) {
        return SystemParameter.builder().id(id).paramType("SKILL").paramKey("k").paramValue(value).build();
    }

    private QuestionCategory category(Long id, String name) {
        QuestionCategory c = new QuestionCategory();
        c.setId(id);
        c.setName(name);
        return c;
    }

    private ExamMatrix matrix(Long id, String title, User creator) {
        ExamMatrix m = new ExamMatrix();
        m.setId(id);
        m.setTitle(title);
        m.setCreatedBy(creator);
        return m;
    }

    private ExamMatrixDetail detail(Long id, ExamMatrix m, SystemParameter skill, SystemParameter diff, QuestionCategory cat, int qty) {
        ExamMatrixDetail d = new ExamMatrixDetail();
        d.setId(id);
        d.setMatrix(m);
        d.setSkillParam(skill);
        d.setDifficultyParam(diff);
        d.setCategory(cat);
        d.setQuantity(qty);
        return d;
    }

    private Question question(Long id) {
        Question q = new Question();
        q.setId(id);
        return q;
    }

    // =================================================================
    // getAllExamMatrices
    // =================================================================

    @Test
    void getAllExamMatricesShouldMapMatricesWithTheirDetails() {
        User creator = user(1L, "trainer@example.com");
        ExamMatrix m = matrix(1L, "IELTS Matrix", creator);
        SystemParameter skill = param(1L, "Reading");
        SystemParameter diff = param(2L, "Medium");
        QuestionCategory cat = category(1L, "Multiple Choice");
        when(examMatrixRepository.findAllByOrderByCreatedAtDesc()).thenReturn(List.of(m));
        when(examMatrixDetailRepository.findByMatrixId(1L)).thenReturn(List.of(detail(1L, m, skill, diff, cat, 5)));

        List<ExamMatrixDTO> result = service.getAllExamMatrices();

        assertEquals(1, result.size());
        assertEquals("IELTS Matrix", result.get(0).getTitle());
        assertEquals(1, result.get(0).getDetails().size());
        assertEquals("Reading", result.get(0).getDetails().get(0).getSkillParamName());
        assertEquals(5, result.get(0).getDetails().get(0).getQuantity());
    }

    @Test
    void getAllExamMatricesShouldReturnEmptyListWhenNoMatrices() {
        when(examMatrixRepository.findAllByOrderByCreatedAtDesc()).thenReturn(List.of());

        List<ExamMatrixDTO> result = service.getAllExamMatrices();

        assertTrue(result.isEmpty());
    }

    // =================================================================
    // createExamMatrix
    // =================================================================

    private ExamMatrixCreateRequestDTO.DetailRequest detailRequest(Long skillId, Long diffId, Long catId, int qty) {
        ExamMatrixCreateRequestDTO.DetailRequest d = new ExamMatrixCreateRequestDTO.DetailRequest();
        d.setSkillParamId(skillId);
        d.setDifficultyParamId(diffId);
        d.setCategoryId(catId);
        d.setQuantity(qty);
        return d;
    }

    private ExamMatrixCreateRequestDTO createRequest(String title, List<ExamMatrixCreateRequestDTO.DetailRequest> details) {
        ExamMatrixCreateRequestDTO req = new ExamMatrixCreateRequestDTO();
        req.setTitle(title);
        req.setDescription("desc");
        req.setDetails(details);
        return req;
    }

    @Test
    void createExamMatrixShouldThrowWhenUserNotFound() {
        when(userRepository.findByEmail("unknown@example.com")).thenReturn(Optional.empty());

        assertThrows(RuntimeException.class,
                () -> service.createExamMatrix("unknown@example.com", createRequest("Matrix", List.of())));
    }

    @Test
    void createExamMatrixShouldPersistMatrixAndAllDetailsWhenValid() {
        User creator = user(1L, "trainer@example.com");
        when(userRepository.findByEmail("trainer@example.com")).thenReturn(Optional.of(creator));
        ExamMatrix saved = matrix(1L, "Matrix", creator);
        when(examMatrixRepository.save(any(ExamMatrix.class))).thenReturn(saved);
        when(systemParameterRepository.findById(1L)).thenReturn(Optional.of(param(1L, "Reading")));
        when(systemParameterRepository.findById(2L)).thenReturn(Optional.of(param(2L, "Medium")));
        when(questionCategoryRepository.findById(1L)).thenReturn(Optional.of(category(1L, "MCQ")));

        service.createExamMatrix("trainer@example.com", createRequest("Matrix", List.of(detailRequest(1L, 2L, 1L, 5))));

        ArgumentCaptor<ExamMatrixDetail> captor = ArgumentCaptor.forClass(ExamMatrixDetail.class);
        verify(examMatrixDetailRepository).save(captor.capture());
        assertEquals(5, captor.getValue().getQuantity());
        assertEquals(saved, captor.getValue().getMatrix());
    }

    @Test
    void createExamMatrixShouldThrowWhenSkillParamNotFound() {
        User creator = user(1L, "trainer@example.com");
        when(userRepository.findByEmail("trainer@example.com")).thenReturn(Optional.of(creator));
        when(examMatrixRepository.save(any(ExamMatrix.class))).thenReturn(matrix(1L, "Matrix", creator));
        when(systemParameterRepository.findById(99L)).thenReturn(Optional.empty());

        assertThrows(RuntimeException.class,
                () -> service.createExamMatrix("trainer@example.com", createRequest("Matrix", List.of(detailRequest(99L, 2L, 1L, 5)))));
    }

    @Test
    void createExamMatrixShouldThrowWhenCategoryNotFound() {
        User creator = user(1L, "trainer@example.com");
        when(userRepository.findByEmail("trainer@example.com")).thenReturn(Optional.of(creator));
        when(examMatrixRepository.save(any(ExamMatrix.class))).thenReturn(matrix(1L, "Matrix", creator));
        when(systemParameterRepository.findById(1L)).thenReturn(Optional.of(param(1L, "Reading")));
        when(systemParameterRepository.findById(2L)).thenReturn(Optional.of(param(2L, "Medium")));
        when(questionCategoryRepository.findById(99L)).thenReturn(Optional.empty());

        assertThrows(RuntimeException.class,
                () -> service.createExamMatrix("trainer@example.com", createRequest("Matrix", List.of(detailRequest(1L, 2L, 99L, 5)))));
    }

    @Test
    void createExamMatrixShouldPersistMatrixWithNoDetailsWhenDetailsListIsNull() {
        User creator = user(1L, "trainer@example.com");
        when(userRepository.findByEmail("trainer@example.com")).thenReturn(Optional.of(creator));
        when(examMatrixRepository.save(any(ExamMatrix.class))).thenReturn(matrix(1L, "Matrix", creator));

        service.createExamMatrix("trainer@example.com", createRequest("Matrix", null));

        verify(examMatrixDetailRepository, never()).save(any());
    }

    // =================================================================
    // generateExamFromMatrix
    // =================================================================

    @Test
    void generateExamFromMatrixShouldThrowWhenUserNotFound() {
        when(userRepository.findByEmail("unknown@example.com")).thenReturn(Optional.empty());

        assertThrows(RuntimeException.class,
                () -> service.generateExamFromMatrix(1L, "My Exam", "unknown@example.com"));
    }

    @Test
    void generateExamFromMatrixShouldThrowWhenMatrixNotFound() {
        when(userRepository.findByEmail("trainer@example.com")).thenReturn(Optional.of(user(1L, "trainer@example.com")));
        when(examMatrixRepository.findById(99L)).thenReturn(Optional.empty());

        assertThrows(RuntimeException.class,
                () -> service.generateExamFromMatrix(99L, "My Exam", "trainer@example.com"));
    }

    @Test
    void generateExamFromMatrixShouldCreateDraftExamWithExpectedQuestionCountSummedFromDetails() {
        User creator = user(1L, "trainer@example.com");
        ExamMatrix m = matrix(1L, "IELTS Matrix", creator);
        SystemParameter skill = param(1L, "Reading");
        SystemParameter diff = param(2L, "Medium");
        QuestionCategory cat = category(1L, "MCQ");
        when(userRepository.findByEmail("trainer@example.com")).thenReturn(Optional.of(creator));
        when(examMatrixRepository.findById(1L)).thenReturn(Optional.of(m));
        when(examMatrixDetailRepository.findByMatrixId(1L))
                .thenReturn(List.of(detail(1L, m, skill, diff, cat, 3), detail(2L, m, skill, diff, cat, 2)));
        when(examRepository.save(any(Exam.class))).thenAnswer(inv -> {
            Exam e = inv.getArgument(0);
            e.setId(500L);
            return e;
        });
        when(questionRepository.findRandomQuestionsByCriteria(1L, 2L, 1L, 3))
                .thenReturn(List.of(question(11L), question(12L), question(13L)));
        when(questionRepository.findRandomQuestionsByCriteria(1L, 2L, 1L, 2))
                .thenReturn(List.of(question(14L), question(15L)));

        Long examId = service.generateExamFromMatrix(1L, "My Custom Exam", "trainer@example.com");

        assertEquals(500L, examId);
        ArgumentCaptor<Exam> captor = ArgumentCaptor.forClass(Exam.class);
        verify(examRepository).save(captor.capture());
        assertEquals("My Custom Exam", captor.getValue().getTitle());
        assertEquals("DRAFT", captor.getValue().getStatus());
        assertEquals("PRIVATE", captor.getValue().getVisibility());
        assertEquals(5, captor.getValue().getExpectedQuestionCount());
        verify(examQuestionRepository, times(5)).save(any());
    }

    @Test
    void generateExamFromMatrixShouldUseMatrixTitleSuffixWhenExamTitleBlank() {
        User creator = user(1L, "trainer@example.com");
        ExamMatrix m = matrix(1L, "IELTS Matrix", creator);
        when(userRepository.findByEmail("trainer@example.com")).thenReturn(Optional.of(creator));
        when(examMatrixRepository.findById(1L)).thenReturn(Optional.of(m));
        when(examMatrixDetailRepository.findByMatrixId(1L)).thenReturn(List.of());
        when(examRepository.save(any(Exam.class))).thenAnswer(inv -> inv.getArgument(0));

        service.generateExamFromMatrix(1L, "  ", "trainer@example.com");

        ArgumentCaptor<Exam> captor = ArgumentCaptor.forClass(Exam.class);
        verify(examRepository).save(captor.capture());
        assertEquals("IELTS Matrix - Generated", captor.getValue().getTitle());
    }

    @Test
    void generateExamFromMatrixShouldThrowWhenNotEnoughQuestionsInBankForCriteria() {
        User creator = user(1L, "trainer@example.com");
        ExamMatrix m = matrix(1L, "IELTS Matrix", creator);
        SystemParameter skill = param(1L, "Reading");
        SystemParameter diff = param(2L, "Medium");
        QuestionCategory cat = category(1L, "MCQ");
        when(userRepository.findByEmail("trainer@example.com")).thenReturn(Optional.of(creator));
        when(examMatrixRepository.findById(1L)).thenReturn(Optional.of(m));
        when(examMatrixDetailRepository.findByMatrixId(1L)).thenReturn(List.of(detail(1L, m, skill, diff, cat, 5)));
        when(examRepository.save(any(Exam.class))).thenAnswer(inv -> {
            Exam e = inv.getArgument(0);
            e.setId(500L);
            return e;
        });
        when(questionRepository.findRandomQuestionsByCriteria(1L, 2L, 1L, 5))
                .thenReturn(List.of(question(11L), question(12L)));

        RuntimeException ex = assertThrows(RuntimeException.class,
                () -> service.generateExamFromMatrix(1L, "My Exam", "trainer@example.com"));
        assertTrue(ex.getMessage().contains("Not enough questions"));
        verify(examQuestionRepository, never()).save(any());
    }

    @Test
    void generateExamFromMatrixShouldSkipDetailWithZeroOrNegativeQuantity() {
        User creator = user(1L, "trainer@example.com");
        ExamMatrix m = matrix(1L, "IELTS Matrix", creator);
        SystemParameter skill = param(1L, "Reading");
        SystemParameter diff = param(2L, "Medium");
        QuestionCategory cat = category(1L, "MCQ");
        when(userRepository.findByEmail("trainer@example.com")).thenReturn(Optional.of(creator));
        when(examMatrixRepository.findById(1L)).thenReturn(Optional.of(m));
        when(examMatrixDetailRepository.findByMatrixId(1L)).thenReturn(List.of(detail(1L, m, skill, diff, cat, 0)));
        when(examRepository.save(any(Exam.class))).thenAnswer(inv -> inv.getArgument(0));

        service.generateExamFromMatrix(1L, "My Exam", "trainer@example.com");

        verify(questionRepository, never()).findRandomQuestionsByCriteria(any(), any(), any(), anyInt());
        verify(examQuestionRepository, never()).save(any());
    }
}
