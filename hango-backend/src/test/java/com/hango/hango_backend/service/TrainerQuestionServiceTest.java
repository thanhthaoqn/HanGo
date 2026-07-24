package com.hango.hango_backend.service;

import com.hango.hango_backend.dto.CreateGroupQuestionRequestDTO;
import com.hango.hango_backend.dto.CreateOptionDTO;
import com.hango.hango_backend.dto.CreateSubQuestionDTO;
import com.hango.hango_backend.dto.QuestionDTO;
import com.hango.hango_backend.entity.Question;
import com.hango.hango_backend.entity.QuestionCategory;
import com.hango.hango_backend.entity.QuestionGroup;
import com.hango.hango_backend.entity.QuestionOption;
import com.hango.hango_backend.entity.SystemParameter;
import com.hango.hango_backend.entity.User;
import com.hango.hango_backend.repository.QuestionCategoryRepository;
import com.hango.hango_backend.repository.QuestionGroupRepository;
import com.hango.hango_backend.repository.QuestionRepository;
import com.hango.hango_backend.repository.SystemParameterRepository;
import com.hango.hango_backend.repository.UserRepository;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jdbc.core.RowMapper;

import java.sql.ResultSet;
import java.sql.Timestamp;
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
class TrainerQuestionServiceTest {

    @Mock
    private JdbcTemplate jdbcTemplate;
    @Mock
    private UserRepository userRepository;
    @Mock
    private QuestionGroupRepository questionGroupRepository;
    @Mock
    private QuestionRepository questionRepository;
    @Mock
    private QuestionCategoryRepository categoryRepository;
    @Mock
    private SystemParameterRepository systemParameterRepository;

    @InjectMocks
    private TrainerQuestionServiceImpl service;

    private User trainer(Long id, String email) {
        return User.builder().id(id).email(email).build();
    }

    private CreateGroupQuestionRequestDTO groupRequest(String passageText, List<CreateSubQuestionDTO> subQuestions) {
        return CreateGroupQuestionRequestDTO.builder()
                .passageText(passageText)
                .categoryId(1L)
                .skillParamId(2L)
                .difficultyId(3L)
                .subQuestions(subQuestions)
                .build();
    }

    private CreateSubQuestionDTO subQuestion(String text, Long difficultyIdOverride, List<CreateOptionDTO> options) {
        return CreateSubQuestionDTO.builder()
                .questionText(text)
                .explanation("exp")
                .difficultyId(difficultyIdOverride)
                .options(options)
                .build();
    }

    // =================================================================
    // getTrainerQuestions
    // =================================================================

    @Test
    void getTrainerQuestionsShouldThrowWhenUserNotFound() {
        when(userRepository.findByEmail("unknown@example.com")).thenReturn(Optional.empty());

        assertThrows(RuntimeException.class, () -> service.getTrainerQuestions("unknown@example.com", "ALL", null, null));
    }

    @Test
    @SuppressWarnings("unchecked")
    void getTrainerQuestionsShouldMapResultSetRowsToQuestionDTO() throws Exception {
        when(userRepository.findByEmail("trainer@example.com")).thenReturn(Optional.of(trainer(1L, "trainer@example.com")));
        ArgumentCaptor<RowMapper<QuestionDTO>> mapperCaptor = ArgumentCaptor.forClass(RowMapper.class);
        when(jdbcTemplate.query(anyString(), mapperCaptor.capture(), any(Object[].class))).thenReturn(List.of());

        service.getTrainerQuestions("trainer@example.com", "ALL", null, null);

        ResultSet rs = mock(ResultSet.class);
        when(rs.getLong("item_id")).thenReturn(42L);
        when(rs.getBoolean("is_group")).thenReturn(true);
        when(rs.getString("question_text")).thenReturn("Passage text");
        when(rs.getString("category_name")).thenReturn("Reading");
        when(rs.getString("difficulty_name")).thenReturn(null);
        when(rs.getString("status")).thenReturn("PUBLIC");
        when(rs.getString("creator_name")).thenReturn("Trainer A");
        when(rs.getTimestamp("created_at")).thenReturn(Timestamp.valueOf(LocalDateTime.of(2026, 1, 1, 0, 0)));
        when(rs.getTimestamp("updated_at")).thenReturn(null);

        QuestionDTO mapped = mapperCaptor.getValue().mapRow(rs, 0);

        assertEquals(42L, mapped.getId());
        assertTrue(mapped.getIsGroup());
        assertEquals("Reading", mapped.getCategoryName());
        assertEquals("PUBLIC", mapped.getStatus());
        assertNull(mapped.getDifficultyName());
    }

    @Test
    void getTrainerQuestionsShouldNotApplyStatusFilterWhenTypeIsAll() {
        when(userRepository.findByEmail("trainer@example.com")).thenReturn(Optional.of(trainer(1L, "trainer@example.com")));
        ArgumentCaptor<String> sqlCaptor = ArgumentCaptor.forClass(String.class);
        when(jdbcTemplate.query(sqlCaptor.capture(), any(RowMapper.class), any(Object[].class))).thenReturn(List.of());

        service.getTrainerQuestions("trainer@example.com", "ALL", null, null);

        assertTrue(!sqlCaptor.getValue().contains("AND q.status = ?"));
    }

    @Test
    void getTrainerQuestionsShouldApplyStatusFilterForOtherTypeValues() {
        when(userRepository.findByEmail("trainer@example.com")).thenReturn(Optional.of(trainer(1L, "trainer@example.com")));
        ArgumentCaptor<String> sqlCaptor = ArgumentCaptor.forClass(String.class);
        when(jdbcTemplate.query(sqlCaptor.capture(), any(RowMapper.class), any(Object[].class))).thenReturn(List.of());

        service.getTrainerQuestions("trainer@example.com", "PUBLIC", null, null);

        assertTrue(sqlCaptor.getValue().contains("AND q.status = ?"));
    }

    @Test
    void getTrainerQuestionsShouldOrderByUpdatedAtAscWhenSortByOldest() {
        when(userRepository.findByEmail("trainer@example.com")).thenReturn(Optional.of(trainer(1L, "trainer@example.com")));
        ArgumentCaptor<String> sqlCaptor = ArgumentCaptor.forClass(String.class);
        when(jdbcTemplate.query(sqlCaptor.capture(), any(RowMapper.class), any(Object[].class))).thenReturn(List.of());

        service.getTrainerQuestions("trainer@example.com", "ALL", null, "OLDEST");

        assertTrue(sqlCaptor.getValue().endsWith("ORDER BY updated_at ASC"));
    }

    @Test
    void getTrainerQuestionsShouldDefaultToDescendingOrderWhenSortByNull() {
        when(userRepository.findByEmail("trainer@example.com")).thenReturn(Optional.of(trainer(1L, "trainer@example.com")));
        ArgumentCaptor<String> sqlCaptor = ArgumentCaptor.forClass(String.class);
        when(jdbcTemplate.query(sqlCaptor.capture(), any(RowMapper.class), any(Object[].class))).thenReturn(List.of());

        service.getTrainerQuestions("trainer@example.com", "ALL", null, null);

        assertTrue(sqlCaptor.getValue().endsWith("ORDER BY updated_at DESC"));
    }

    @Test
    void getTrainerQuestionsShouldAddSearchConditionWhenSearchProvided() {
        when(userRepository.findByEmail("trainer@example.com")).thenReturn(Optional.of(trainer(1L, "trainer@example.com")));
        ArgumentCaptor<String> sqlCaptor = ArgumentCaptor.forClass(String.class);
        when(jdbcTemplate.query(sqlCaptor.capture(), any(RowMapper.class), any(Object[].class))).thenReturn(List.of());

        service.getTrainerQuestions("trainer@example.com", "ALL", "grammar", null);

        assertTrue(sqlCaptor.getValue().contains("q.question_text LIKE ?"));
    }

    // =================================================================
    // createQuestionBankGroup
    // =================================================================

    @Test
    void createQuestionBankGroupShouldThrowWhenUserNotFound() {
        when(userRepository.findByEmail("unknown@example.com")).thenReturn(Optional.empty());

        assertThrows(RuntimeException.class,
                () -> service.createQuestionBankGroup("unknown@example.com", groupRequest(null, List.of())));
    }

    @Test
    void createQuestionBankGroupShouldCreateGroupWhenPassageTextProvided() {
        when(userRepository.findByEmail("trainer@example.com")).thenReturn(Optional.of(trainer(1L, "trainer@example.com")));
        when(categoryRepository.findById(1L)).thenReturn(Optional.of(new QuestionCategory()));
        when(systemParameterRepository.findById(2L)).thenReturn(Optional.of(SystemParameter.builder().id(2L).build()));
        when(systemParameterRepository.findById(3L)).thenReturn(Optional.of(SystemParameter.builder().id(3L).build()));
        when(systemParameterRepository.findById(17L)).thenReturn(Optional.of(SystemParameter.builder().id(17L).build()));
        when(questionGroupRepository.save(any(QuestionGroup.class))).thenAnswer(inv -> {
            QuestionGroup g = inv.getArgument(0);
            g.setId(500L);
            return g;
        });
        when(questionRepository.save(any(Question.class))).thenAnswer(inv -> inv.getArgument(0));

        Map<String, Object> result = service.createQuestionBankGroup("trainer@example.com",
                groupRequest("Reading passage", List.of(subQuestion("Q1", null, List.of()))));

        assertEquals(500L, result.get("groupId"));
        verify(questionGroupRepository).save(any(QuestionGroup.class));
    }

    @Test
    void createQuestionBankGroupShouldNotCreateGroupWhenPassageTextBlank() {
        when(userRepository.findByEmail("trainer@example.com")).thenReturn(Optional.of(trainer(1L, "trainer@example.com")));
        when(categoryRepository.findById(1L)).thenReturn(Optional.of(new QuestionCategory()));
        when(systemParameterRepository.findById(2L)).thenReturn(Optional.of(SystemParameter.builder().id(2L).build()));
        when(systemParameterRepository.findById(3L)).thenReturn(Optional.of(SystemParameter.builder().id(3L).build()));
        when(questionRepository.save(any(Question.class))).thenAnswer(inv -> inv.getArgument(0));

        Map<String, Object> result = service.createQuestionBankGroup("trainer@example.com",
                groupRequest("   ", List.of(subQuestion("Q1", null, List.of()))));

        assertNull(result.get("groupId"));
        verify(questionGroupRepository, never()).save(any());
    }

    @Test
    void createQuestionBankGroupShouldDefaultStatusToPrivateWhenNotProvided() {
        when(userRepository.findByEmail("trainer@example.com")).thenReturn(Optional.of(trainer(1L, "trainer@example.com")));
        when(categoryRepository.findById(1L)).thenReturn(Optional.of(new QuestionCategory()));
        when(systemParameterRepository.findById(2L)).thenReturn(Optional.of(SystemParameter.builder().id(2L).build()));
        when(systemParameterRepository.findById(3L)).thenReturn(Optional.of(SystemParameter.builder().id(3L).build()));
        ArgumentCaptor<Question> captor = ArgumentCaptor.forClass(Question.class);
        when(questionRepository.save(captor.capture())).thenAnswer(inv -> inv.getArgument(0));

        service.createQuestionBankGroup("trainer@example.com", groupRequest(null, List.of(subQuestion("Q1", null, List.of()))));

        assertEquals("PRIVATE", captor.getValue().getStatus());
    }

    @Test
    void createQuestionBankGroupShouldUseSubQuestionDifficultyOverrideWhenProvided() {
        when(userRepository.findByEmail("trainer@example.com")).thenReturn(Optional.of(trainer(1L, "trainer@example.com")));
        when(categoryRepository.findById(1L)).thenReturn(Optional.of(new QuestionCategory()));
        when(systemParameterRepository.findById(2L)).thenReturn(Optional.of(SystemParameter.builder().id(2L).build()));
        when(systemParameterRepository.findById(3L)).thenReturn(Optional.of(SystemParameter.builder().id(3L).build()));
        when(systemParameterRepository.findById(99L)).thenReturn(Optional.of(SystemParameter.builder().id(99L).paramValue("Hard").build()));
        ArgumentCaptor<Question> captor = ArgumentCaptor.forClass(Question.class);
        when(questionRepository.save(captor.capture())).thenAnswer(inv -> inv.getArgument(0));

        service.createQuestionBankGroup("trainer@example.com", groupRequest(null, List.of(subQuestion("Q1", 99L, List.of()))));

        assertEquals(99L, captor.getValue().getDifficulty().getId());
    }

    @Test
    void createQuestionBankGroupShouldPersistOptionsForEachSubQuestion() {
        when(userRepository.findByEmail("trainer@example.com")).thenReturn(Optional.of(trainer(1L, "trainer@example.com")));
        when(categoryRepository.findById(1L)).thenReturn(Optional.of(new QuestionCategory()));
        when(systemParameterRepository.findById(2L)).thenReturn(Optional.of(SystemParameter.builder().id(2L).build()));
        when(systemParameterRepository.findById(3L)).thenReturn(Optional.of(SystemParameter.builder().id(3L).build()));
        when(questionRepository.save(any(Question.class))).thenAnswer(inv -> inv.getArgument(0));

        List<CreateOptionDTO> options = List.of(
                CreateOptionDTO.builder().optionText("A").isCorrect(true).build(),
                CreateOptionDTO.builder().optionText("B").isCorrect(null).build());
        service.createQuestionBankGroup("trainer@example.com", groupRequest(null, List.of(subQuestion("Q1", null, options))));

        verify(questionRepository, times(2)).save(any(Question.class));
    }

    @Test
    void createQuestionBankGroupShouldReturnQuestionIdsInResponse() {
        when(userRepository.findByEmail("trainer@example.com")).thenReturn(Optional.of(trainer(1L, "trainer@example.com")));
        when(categoryRepository.findById(1L)).thenReturn(Optional.of(new QuestionCategory()));
        when(systemParameterRepository.findById(2L)).thenReturn(Optional.of(SystemParameter.builder().id(2L).build()));
        when(systemParameterRepository.findById(3L)).thenReturn(Optional.of(SystemParameter.builder().id(3L).build()));
        when(questionRepository.save(any(Question.class))).thenAnswer(inv -> {
            Question q = inv.getArgument(0);
            if (q.getId() == null) q.setId(77L);
            return q;
        });

        Map<String, Object> result = service.createQuestionBankGroup("trainer@example.com",
                groupRequest(null, List.of(subQuestion("Q1", null, List.of()))));

        assertEquals(List.of(77L), result.get("questionIds"));
    }

    // =================================================================
    // getQuestionDetail
    // =================================================================

    @Test
    void getQuestionDetailShouldThrowWhenUserNotFound() {
        when(userRepository.findByEmail("unknown@example.com")).thenReturn(Optional.empty());

        assertThrows(RuntimeException.class, () -> service.getQuestionDetail("unknown@example.com", 1L, false));
    }

    @Test
    void getQuestionDetailGroupShouldThrowWhenGroupNotFound() {
        when(userRepository.findByEmail("trainer@example.com")).thenReturn(Optional.of(trainer(1L, "trainer@example.com")));
        when(questionGroupRepository.findById(500L)).thenReturn(Optional.empty());

        assertThrows(RuntimeException.class, () -> service.getQuestionDetail("trainer@example.com", 500L, true));
    }

    @Test
    void getQuestionDetailGroupShouldThrowWhenNotOwner() {
        when(userRepository.findByEmail("intruder@example.com")).thenReturn(Optional.of(trainer(2L, "intruder@example.com")));
        QuestionGroup group = new QuestionGroup();
        group.setId(500L);
        when(questionGroupRepository.findById(500L)).thenReturn(Optional.of(group));
        Question q = new Question();
        q.setCreatedBy(trainer(1L, "owner@example.com"));
        when(questionRepository.findByQuestionGroup(group)).thenReturn(List.of(q));

        assertThrows(RuntimeException.class, () -> service.getQuestionDetail("intruder@example.com", 500L, true));
    }

    @Test
    void getQuestionDetailGroupShouldMapPassageAndSubQuestions() {
        User owner = trainer(1L, "trainer@example.com");
        when(userRepository.findByEmail("trainer@example.com")).thenReturn(Optional.of(owner));
        QuestionGroup group = new QuestionGroup();
        group.setId(500L);
        group.setContextText("Passage text");
        when(questionGroupRepository.findById(500L)).thenReturn(Optional.of(group));
        Question q = new Question();
        q.setId(10L);
        q.setCreatedBy(owner);
        q.setQuestionText("Q1");
        q.setStatus("PUBLIC");
        q.setOptions(List.of());
        when(questionRepository.findByQuestionGroup(group)).thenReturn(List.of(q));

        CreateGroupQuestionRequestDTO result = service.getQuestionDetail("trainer@example.com", 500L, true);

        assertEquals("Passage text", result.getPassageText());
        assertEquals(1, result.getSubQuestions().size());
        assertEquals("PUBLIC", result.getStatus());
    }

    @Test
    void getQuestionDetailSingleShouldThrowWhenQuestionNotFound() {
        when(userRepository.findByEmail("trainer@example.com")).thenReturn(Optional.of(trainer(1L, "trainer@example.com")));
        when(questionRepository.findById(10L)).thenReturn(Optional.empty());

        assertThrows(RuntimeException.class, () -> service.getQuestionDetail("trainer@example.com", 10L, false));
    }

    @Test
    void getQuestionDetailSingleShouldThrowWhenNotOwner() {
        when(userRepository.findByEmail("intruder@example.com")).thenReturn(Optional.of(trainer(2L, "intruder@example.com")));
        Question q = new Question();
        q.setId(10L);
        q.setCreatedBy(trainer(1L, "owner@example.com"));
        when(questionRepository.findById(10L)).thenReturn(Optional.of(q));

        assertThrows(RuntimeException.class, () -> service.getQuestionDetail("intruder@example.com", 10L, false));
    }

    @Test
    void getQuestionDetailSingleShouldMapFields() {
        User owner = trainer(1L, "trainer@example.com");
        when(userRepository.findByEmail("trainer@example.com")).thenReturn(Optional.of(owner));
        Question q = new Question();
        q.setId(10L);
        q.setCreatedBy(owner);
        q.setQuestionText("Q1");
        q.setStatus("PRIVATE");
        q.setOptions(List.of());
        when(questionRepository.findById(10L)).thenReturn(Optional.of(q));

        CreateGroupQuestionRequestDTO result = service.getQuestionDetail("trainer@example.com", 10L, false);

        assertEquals("PRIVATE", result.getStatus());
        assertEquals(1, result.getSubQuestions().size());
        assertEquals("Q1", result.getSubQuestions().get(0).getQuestionText());
    }

    // =================================================================
    // updateQuestionBankGroup
    // =================================================================

    @Test
    void updateQuestionBankGroupShouldThrowWhenUserNotFound() {
        when(userRepository.findByEmail("unknown@example.com")).thenReturn(Optional.empty());

        assertThrows(RuntimeException.class,
                () -> service.updateQuestionBankGroup("unknown@example.com", 1L, false, groupRequest(null, List.of())));
    }

    @Test
    void updateQuestionBankGroupGroupShouldThrowWhenGroupNotFound() {
        when(userRepository.findByEmail("trainer@example.com")).thenReturn(Optional.of(trainer(1L, "trainer@example.com")));
        when(questionGroupRepository.findById(500L)).thenReturn(Optional.empty());

        assertThrows(RuntimeException.class,
                () -> service.updateQuestionBankGroup("trainer@example.com", 500L, true, groupRequest("New passage", List.of())));
    }

    @Test
    void updateQuestionBankGroupGroupShouldThrowWhenNotOwner() {
        when(userRepository.findByEmail("intruder@example.com")).thenReturn(Optional.of(trainer(2L, "intruder@example.com")));
        QuestionGroup group = new QuestionGroup();
        group.setId(500L);
        when(questionGroupRepository.findById(500L)).thenReturn(Optional.of(group));
        Question oldQ = new Question();
        oldQ.setCreatedBy(trainer(1L, "owner@example.com"));
        when(questionRepository.findByQuestionGroup(group)).thenReturn(List.of(oldQ));

        assertThrows(RuntimeException.class,
                () -> service.updateQuestionBankGroup("intruder@example.com", 500L, true, groupRequest("New passage", List.of())));
    }

    @Test
    void updateQuestionBankGroupGroupShouldDeleteOldQuestionsAndRecreate() {
        User owner = trainer(1L, "trainer@example.com");
        when(userRepository.findByEmail("trainer@example.com")).thenReturn(Optional.of(owner));
        QuestionGroup group = new QuestionGroup();
        group.setId(500L);
        when(questionGroupRepository.findById(500L)).thenReturn(Optional.of(group));
        Question oldQ = new Question();
        oldQ.setCreatedBy(owner);
        List<Question> oldQuestions = List.of(oldQ);
        when(questionRepository.findByQuestionGroup(group)).thenReturn(oldQuestions);
        when(questionRepository.save(any(Question.class))).thenAnswer(inv -> inv.getArgument(0));

        service.updateQuestionBankGroup("trainer@example.com", 500L, true,
                groupRequest("Updated passage", List.of(subQuestion("New Q1", null, null))));

        verify(questionRepository).deleteAll(oldQuestions);
        assertEquals("Updated passage", group.getContextText());
        verify(questionRepository).save(any(Question.class));
    }

    @Test
    void updateQuestionBankGroupSingleShouldThrowWhenQuestionNotFound() {
        when(userRepository.findByEmail("trainer@example.com")).thenReturn(Optional.of(trainer(1L, "trainer@example.com")));
        when(questionRepository.findById(10L)).thenReturn(Optional.empty());

        assertThrows(RuntimeException.class,
                () -> service.updateQuestionBankGroup("trainer@example.com", 10L, false, groupRequest(null, List.of())));
    }

    @Test
    void updateQuestionBankGroupSingleShouldThrowWhenNotOwner() {
        when(userRepository.findByEmail("intruder@example.com")).thenReturn(Optional.of(trainer(2L, "intruder@example.com")));
        Question oldQ = new Question();
        oldQ.setCreatedBy(trainer(1L, "owner@example.com"));
        when(questionRepository.findById(10L)).thenReturn(Optional.of(oldQ));

        assertThrows(RuntimeException.class,
                () -> service.updateQuestionBankGroup("intruder@example.com", 10L, false, groupRequest(null, List.of())));
    }

    @Test
    void updateQuestionBankGroupSingleShouldDeleteOldAndRecreate() {
        User owner = trainer(1L, "trainer@example.com");
        when(userRepository.findByEmail("trainer@example.com")).thenReturn(Optional.of(owner));
        Question oldQ = new Question();
        oldQ.setId(10L);
        oldQ.setCreatedBy(owner);
        when(questionRepository.findById(10L)).thenReturn(Optional.of(oldQ));
        when(questionRepository.save(any(Question.class))).thenAnswer(inv -> inv.getArgument(0));

        service.updateQuestionBankGroup("trainer@example.com", 10L, false,
                groupRequest(null, List.of(subQuestion("Updated Q", null, null))));

        verify(questionRepository).delete(oldQ);
        verify(questionRepository).save(any(Question.class));
    }

    // =================================================================
    // updateQuestionStatus
    // =================================================================

    @Test
    void updateQuestionStatusGroupShouldThrowWhenGroupNotFound() {
        when(userRepository.findByEmail("trainer@example.com")).thenReturn(Optional.of(trainer(1L, "trainer@example.com")));
        when(questionGroupRepository.findById(500L)).thenReturn(Optional.empty());

        assertThrows(RuntimeException.class,
                () -> service.updateQuestionStatus("trainer@example.com", 500L, "PUBLIC", true));
    }

    @Test
    void updateQuestionStatusGroupShouldThrowWhenAnyQuestionNotOwnedByCaller() {
        when(userRepository.findByEmail("intruder@example.com")).thenReturn(Optional.of(trainer(2L, "intruder@example.com")));
        QuestionGroup group = new QuestionGroup();
        group.setId(500L);
        when(questionGroupRepository.findById(500L)).thenReturn(Optional.of(group));
        Question q = new Question();
        q.setCreatedBy(trainer(1L, "owner@example.com"));
        when(questionRepository.findByQuestionGroup(group)).thenReturn(List.of(q));

        assertThrows(RuntimeException.class,
                () -> service.updateQuestionStatus("intruder@example.com", 500L, "PUBLIC", true));
    }

    @Test
    void updateQuestionStatusGroupShouldUpdateAllQuestionsInGroup() {
        User owner = trainer(1L, "trainer@example.com");
        when(userRepository.findByEmail("trainer@example.com")).thenReturn(Optional.of(owner));
        QuestionGroup group = new QuestionGroup();
        group.setId(500L);
        when(questionGroupRepository.findById(500L)).thenReturn(Optional.of(group));
        Question q1 = new Question();
        q1.setCreatedBy(owner);
        Question q2 = new Question();
        q2.setCreatedBy(owner);
        when(questionRepository.findByQuestionGroup(group)).thenReturn(List.of(q1, q2));

        service.updateQuestionStatus("trainer@example.com", 500L, "PUBLIC", true);

        assertEquals("PUBLIC", q1.getStatus());
        assertEquals("PUBLIC", q2.getStatus());
        verify(questionRepository, times(2)).save(any(Question.class));
    }

    @Test
    void updateQuestionStatusSingleShouldThrowWhenQuestionNotFound() {
        when(userRepository.findByEmail("trainer@example.com")).thenReturn(Optional.of(trainer(1L, "trainer@example.com")));
        when(questionRepository.findById(10L)).thenReturn(Optional.empty());

        assertThrows(RuntimeException.class,
                () -> service.updateQuestionStatus("trainer@example.com", 10L, "PUBLIC", false));
    }

    @Test
    void updateQuestionStatusSingleShouldThrowWhenNotOwner() {
        when(userRepository.findByEmail("intruder@example.com")).thenReturn(Optional.of(trainer(2L, "intruder@example.com")));
        Question q = new Question();
        q.setCreatedBy(trainer(1L, "owner@example.com"));
        when(questionRepository.findById(10L)).thenReturn(Optional.of(q));

        assertThrows(RuntimeException.class,
                () -> service.updateQuestionStatus("intruder@example.com", 10L, "PUBLIC", false));
    }

    @Test
    void updateQuestionStatusSingleShouldUpdateStatus() {
        User owner = trainer(1L, "trainer@example.com");
        when(userRepository.findByEmail("trainer@example.com")).thenReturn(Optional.of(owner));
        Question q = new Question();
        q.setCreatedBy(owner);
        when(questionRepository.findById(10L)).thenReturn(Optional.of(q));

        service.updateQuestionStatus("trainer@example.com", 10L, "PUBLIC", false);

        assertEquals("PUBLIC", q.getStatus());
        verify(questionRepository).save(q);
    }
}
