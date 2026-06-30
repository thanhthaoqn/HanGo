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
        Assertions.assertEquals(200, response.getStatusCode().value());
    }
}
