package com.hango.hango_backend.controller;

import com.hango.hango_backend.dto.QuizQuestionSelectionRequestDTO;
import com.hango.hango_backend.dto.SectionQuestionCountDTO;
import com.hango.hango_backend.entity.Section;
import com.hango.hango_backend.repository.SectionRepository;
import org.junit.jupiter.api.Assertions;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.mockito.Mockito;
import org.springframework.http.ResponseEntity;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jdbc.core.RowMapper;

import java.util.ArrayList;
import java.util.Arrays;
import java.util.List;
import java.util.Map;

public class SectionQuestionControllerTest {

    private SectionRepository sectionRepository;
    private JdbcTemplate jdbcTemplate;
    private SectionQuestionController sectionQuestionController;

    @BeforeEach
    public void setUp() {
        sectionRepository = Mockito.mock(SectionRepository.class);
        jdbcTemplate = Mockito.mock(JdbcTemplate.class);
        sectionQuestionController = new SectionQuestionController(sectionRepository, jdbcTemplate);
    }

    @Test
    public void testGetCourseSections() {
        Section section = new Section();
        section.setId(1L);
        section.setTitle("Section 1");
        section.setDisplayOrder(1);

        Mockito.when(sectionRepository.findByCourseIdOrderByDisplayOrderAsc(1L))
                .thenReturn(Arrays.asList(section));

        Mockito.when(jdbcTemplate.queryForObject(Mockito.anyString(), Mockito.eq(Integer.class), Mockito.eq(1L)))
                .thenReturn(15);

        ResponseEntity<List<SectionQuestionCountDTO>> response = sectionQuestionController.getCourseSections(1L);
        Assertions.assertNotNull(response);
        Assertions.assertEquals(200, response.getStatusCode().value());
        Assertions.assertEquals(1, response.getBody().size());
        Assertions.assertEquals("Section 1", response.getBody().get(0).getTitle());
    }

    @Test
    public void testGetSectionQuestions() {
        Mockito.when(jdbcTemplate.queryForObject(Mockito.anyString(), Mockito.eq(Integer.class), Mockito.any()))
                .thenReturn(10);

        Mockito.when(jdbcTemplate.query(Mockito.anyString(), Mockito.any(RowMapper.class), Mockito.any()))
                .thenReturn(new ArrayList<>());

        ResponseEntity<Map<String, Object>> response = sectionQuestionController.getSectionQuestions(1L, 0, 5, "test");
        Assertions.assertNotNull(response);
        Assertions.assertEquals(200, response.getStatusCode().value());
    }

    @Test
    public void testSelectSectionQuestions() {
        Mockito.when(jdbcTemplate.query(Mockito.anyString(), Mockito.any(RowMapper.class), Mockito.any()))
                .thenReturn(Arrays.asList(1L, 2L));

        ResponseEntity<List<Long>> response = sectionQuestionController.selectSectionQuestions(1L, 5, "RANDOM");
        Assertions.assertNotNull(response);
        Assertions.assertEquals(200, response.getStatusCode().value());
    }

    @Test
    public void testSaveQuizQuestions() {
        QuizQuestionSelectionRequestDTO request = QuizQuestionSelectionRequestDTO.builder()
                .questionIds(Arrays.asList(1L, 2L))
                .build();

        ResponseEntity<?> response = sectionQuestionController.saveQuizQuestions(1L, request);
        Assertions.assertNotNull(response);
    }

    @Test
    public void testCreateQuestionUnauthorized() {
        org.springframework.security.core.context.SecurityContextHolder.clearContext();

        com.hango.hango_backend.dto.CreateQuestionRequestDTO request = com.hango.hango_backend.dto.CreateQuestionRequestDTO.builder()
                .sectionId(1L)
                .questionText("Sample Question")
                .options(Arrays.asList(com.hango.hango_backend.dto.CreateOptionDTO.builder().optionText("Opt 1").isCorrect(true).build()))
                .build();

        ResponseEntity<?> response = sectionQuestionController.createQuestion(request);
        Assertions.assertEquals(401, response.getStatusCode().value());
    }

    @Test
    public void testCreateQuestionSuccess() {
        org.springframework.security.core.Authentication auth = Mockito.mock(org.springframework.security.core.Authentication.class);
        com.hango.hango_backend.security.UserDetailsImpl userDetails = Mockito.mock(com.hango.hango_backend.security.UserDetailsImpl.class);
        Mockito.when(userDetails.getId()).thenReturn(1L);
        Mockito.when(auth.getPrincipal()).thenReturn(userDetails);
        
        org.springframework.security.core.context.SecurityContext securityContext = Mockito.mock(org.springframework.security.core.context.SecurityContext.class);
        Mockito.when(securityContext.getAuthentication()).thenReturn(auth);
        org.springframework.security.core.context.SecurityContextHolder.setContext(securityContext);

        Mockito.when(jdbcTemplate.update(Mockito.any(org.springframework.jdbc.core.PreparedStatementCreator.class), Mockito.any(org.springframework.jdbc.support.KeyHolder.class)))
                .thenAnswer(invocation -> {
                    org.springframework.jdbc.support.KeyHolder kh = invocation.getArgument(1);
                    kh.getKeyList().add(java.util.Collections.singletonMap("id", 123L));
                    return 1;
                });

        com.hango.hango_backend.dto.CreateQuestionRequestDTO request = com.hango.hango_backend.dto.CreateQuestionRequestDTO.builder()
                .sectionId(1L)
                .questionText("Sample Question")
                .options(Arrays.asList(com.hango.hango_backend.dto.CreateOptionDTO.builder().optionText("Opt 1").isCorrect(true).build()))
                .build();

        ResponseEntity<?> response = sectionQuestionController.createQuestion(request);
        Assertions.assertEquals(200, response.getStatusCode().value());
    }

    @Test
    public void testCreateGroupQuestionSuccess() {
        org.springframework.security.core.Authentication auth = Mockito.mock(org.springframework.security.core.Authentication.class);
        com.hango.hango_backend.security.UserDetailsImpl userDetails = Mockito.mock(com.hango.hango_backend.security.UserDetailsImpl.class);
        Mockito.when(userDetails.getId()).thenReturn(1L);
        Mockito.when(auth.getPrincipal()).thenReturn(userDetails);
        
        org.springframework.security.core.context.SecurityContext securityContext = Mockito.mock(org.springframework.security.core.context.SecurityContext.class);
        Mockito.when(securityContext.getAuthentication()).thenReturn(auth);
        org.springframework.security.core.context.SecurityContextHolder.setContext(securityContext);

        Mockito.when(jdbcTemplate.update(Mockito.any(org.springframework.jdbc.core.PreparedStatementCreator.class), Mockito.any(org.springframework.jdbc.support.KeyHolder.class)))
                .thenAnswer(invocation -> {
                    org.springframework.jdbc.support.KeyHolder kh = invocation.getArgument(1);
                    kh.getKeyList().add(java.util.Collections.singletonMap("id", 123L));
                    return 1;
                });

        com.hango.hango_backend.dto.CreateSubQuestionDTO subQ = com.hango.hango_backend.dto.CreateSubQuestionDTO.builder()
                .questionText("Sub Q1")
                .explanation("Exp")
                .options(Arrays.asList(com.hango.hango_backend.dto.CreateOptionDTO.builder().optionText("A").isCorrect(true).build()))
                .build();

        com.hango.hango_backend.dto.CreateGroupQuestionRequestDTO request = com.hango.hango_backend.dto.CreateGroupQuestionRequestDTO.builder()
                .sectionId(1L)
                .passageText("Sample Passage")
                .subQuestions(Arrays.asList(subQ))
                .build();

        ResponseEntity<?> response = sectionQuestionController.createGroupQuestion(request);
        Assertions.assertNotNull(response);
        Assertions.assertEquals(200, response.getStatusCode().value());
    }

    private void mockAuthenticatedUser(Long userId) {
        org.springframework.security.core.Authentication auth = Mockito.mock(org.springframework.security.core.Authentication.class);
        com.hango.hango_backend.security.UserDetailsImpl userDetails = Mockito.mock(com.hango.hango_backend.security.UserDetailsImpl.class);
        Mockito.when(userDetails.getId()).thenReturn(userId);
        Mockito.when(auth.getPrincipal()).thenReturn(userDetails);

        org.springframework.security.core.context.SecurityContext securityContext = Mockito.mock(org.springframework.security.core.context.SecurityContext.class);
        Mockito.when(securityContext.getAuthentication()).thenReturn(auth);
        org.springframework.security.core.context.SecurityContextHolder.setContext(securityContext);
    }

    @Test
    public void testUpdateQuestionUnauthorized() {
        org.springframework.security.core.context.SecurityContextHolder.clearContext();

        com.hango.hango_backend.dto.CreateQuestionRequestDTO request = com.hango.hango_backend.dto.CreateQuestionRequestDTO.builder()
                .questionText("Updated text")
                .build();

        ResponseEntity<?> response = sectionQuestionController.updateQuestion(1L, request);
        Assertions.assertEquals(401, response.getStatusCode().value());
    }

    @Test
    public void testUpdateQuestionNotFound() {
        mockAuthenticatedUser(1L);
        Mockito.when(jdbcTemplate.queryForObject(Mockito.anyString(), Mockito.eq(Integer.class), Mockito.any()))
                .thenReturn(0);

        com.hango.hango_backend.dto.CreateQuestionRequestDTO request = com.hango.hango_backend.dto.CreateQuestionRequestDTO.builder()
                .questionText("Updated text")
                .build();

        ResponseEntity<?> response = sectionQuestionController.updateQuestion(10L, request);
        Assertions.assertEquals(404, response.getStatusCode().value());
    }

    @Test
    public void testUpdateQuestionSuccess() {
        mockAuthenticatedUser(1L);
        Mockito.when(jdbcTemplate.queryForObject(Mockito.anyString(), Mockito.eq(Integer.class), Mockito.any()))
                .thenReturn(1);

        com.hango.hango_backend.dto.CreateQuestionRequestDTO request = com.hango.hango_backend.dto.CreateQuestionRequestDTO.builder()
                .questionText("Updated text")
                .explanation("Updated explanation")
                .skillParamId(2L)
                .difficultyId(3L)
                .options(Arrays.asList(com.hango.hango_backend.dto.CreateOptionDTO.builder().optionText("A").isCorrect(true).build()))
                .build();

        ResponseEntity<?> response = sectionQuestionController.updateQuestion(10L, request);
        Assertions.assertEquals(200, response.getStatusCode().value());
    }

    @Test
    public void testUpdateQuestionUpdatesGroupPassageAndTypeWhenGroupIdProvided() {
        mockAuthenticatedUser(1L);
        Mockito.when(jdbcTemplate.queryForObject(Mockito.anyString(), Mockito.eq(Integer.class), Mockito.any()))
                .thenReturn(1);

        com.hango.hango_backend.dto.CreateQuestionRequestDTO request = com.hango.hango_backend.dto.CreateQuestionRequestDTO.builder()
                .questionText("Updated text")
                .groupId(500L)
                .passageText("Updated passage")
                .groupTypeParamId(7L)
                .build();

        ResponseEntity<?> response = sectionQuestionController.updateQuestion(10L, request);

        Assertions.assertEquals(200, response.getStatusCode().value());
        Mockito.verify(jdbcTemplate).update(
                Mockito.eq("UPDATE question_groups SET context_text = ? WHERE id = ?"),
                Mockito.eq("Updated passage"), Mockito.eq(500L));
        Mockito.verify(jdbcTemplate).update(
                Mockito.eq("UPDATE question_groups SET group_type_param_id = ? WHERE id = ?"),
                Mockito.eq(7L), Mockito.eq(500L));
    }

    @Test
    public void testUpdateQuestionBadRequestWhenExceptionThrown() {
        mockAuthenticatedUser(1L);
        Mockito.when(jdbcTemplate.update(Mockito.anyString(), Mockito.any(Object[].class)))
                .thenThrow(new RuntimeException("DB error"));

        com.hango.hango_backend.dto.CreateQuestionRequestDTO request = com.hango.hango_backend.dto.CreateQuestionRequestDTO.builder()
                .questionText("Updated text")
                .build();

        ResponseEntity<?> response = sectionQuestionController.updateQuestion(10L, request);
        Assertions.assertEquals(400, response.getStatusCode().value());
    }

    @Test
    public void testGetLessonQuestions() {
        Mockito.when(jdbcTemplate.queryForObject(Mockito.anyString(), Mockito.eq(Integer.class), Mockito.any(Object[].class)))
                .thenReturn(10);

        List<Map<String, Object>> mockQuestions = new ArrayList<>();
        Map<String, Object> qMap = new java.util.HashMap<>();
        qMap.put("id", 1L);
        qMap.put("question_text", "Q1");
        qMap.put("explanation", "Exp1");
        qMap.put("category_name", "Single Choice");
        qMap.put("difficulty_name", "EASY");
        mockQuestions.add(qMap);

        Mockito.when(jdbcTemplate.query(Mockito.anyString(), Mockito.any(org.springframework.jdbc.core.RowMapper.class), Mockito.any(Object[].class)))
                .thenReturn(mockQuestions);

        ResponseEntity<Map<String, Object>> response = sectionQuestionController.getLessonQuestions(1L, 0, 10);
        Assertions.assertNotNull(response);
        Assertions.assertEquals(200, response.getStatusCode().value());
        Assertions.assertNotNull(response.getBody());
        Assertions.assertEquals(10, response.getBody().get("totalElements"));
    }
}
