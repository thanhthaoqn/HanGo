package com.hango.hango_backend.controller;

import org.apache.poi.ss.usermodel.Row;
import org.apache.poi.ss.usermodel.Sheet;
import org.apache.poi.xssf.usermodel.XSSFWorkbook;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.http.ResponseEntity;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jdbc.core.PreparedStatementCreator;
import org.springframework.jdbc.support.KeyHolder;
import org.springframework.mock.web.MockMultipartFile;
import org.springframework.security.core.userdetails.UserDetails;

import java.io.ByteArrayOutputStream;
import java.util.Collections;
import java.util.List;
import java.util.Map;
import java.util.concurrent.atomic.AtomicLong;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.lenient;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class ExamImportControllerTest {

    @Mock
    private JdbcTemplate jdbcTemplate;

    @InjectMocks
    private ExamImportController controller;

    private UserDetails principal(String email) {
        UserDetails p = mock(UserDetails.class);
        lenient().when(p.getUsername()).thenReturn(email);
        return p;
    }

    private void stubKeyGeneratingInserts() {
        AtomicLong nextId = new AtomicLong(100);
        lenient().when(jdbcTemplate.update(any(PreparedStatementCreator.class), any(KeyHolder.class)))
                .thenAnswer(inv -> {
                    KeyHolder kh = inv.getArgument(1);
                    kh.getKeyList().add(Collections.singletonMap("id", nextId.getAndIncrement()));
                    return 1;
                });
    }

    private void stubUserId(String email, long userId) {
        lenient().when(jdbcTemplate.query(anyString(), any(org.springframework.jdbc.core.RowMapper.class), eq(email)))
                .thenReturn(List.of(userId));
    }

    private void stubSystemParam(String searchValue, long id) {
        lenient().when(jdbcTemplate.query(anyString(), any(org.springframework.jdbc.core.RowMapper.class), eq(searchValue)))
                .thenReturn(List.of(id));
    }

    /** row[0]=ExamCode row[1]=Title row[2]=Description row[3]=QCount row[4]=PassingScore row[5]=Time row[6]=Thumbnail */
    /** questionRow[0]=ExamCode [1]=Order [2]=Passage [3]=QText [4-7]=OptA-D [8]=Correct [9]=Explanation [10]=Skill [11]=Difficulty [12]=GroupType */
    private MockMultipartFile workbook(List<String[]> examRows, List<String[]> questionRows) throws Exception {
        try (XSSFWorkbook wb = new XSSFWorkbook()) {
            wb.createSheet("INFO");
            Sheet examSheet = wb.createSheet("EXAM");
            writeRow(examSheet, 0, new String[] { "Exam Code", "Title", "Description", "Question Count",
                    "Passing Score", "Time", "Thumbnail URL" });
            int r = 1;
            for (String[] row : examRows) {
                writeRow(examSheet, r++, row);
            }
            Sheet questionSheet = wb.createSheet("QUESTIONS");
            writeRow(questionSheet, 0, new String[] { "Exam Code", "Order", "Passage", "Question Text", "A", "B",
                    "C", "D", "Correct", "Explanation", "Skill", "Difficulty", "Group Type" });
            int qr = 1;
            for (String[] row : questionRows) {
                writeRow(questionSheet, qr++, row);
            }
            ByteArrayOutputStream bos = new ByteArrayOutputStream();
            wb.write(bos);
            return new MockMultipartFile("file", "exams.xlsx",
                    "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet", bos.toByteArray());
        }
    }

    private void writeRow(Sheet sheet, int rowIndex, String[] values) {
        Row row = sheet.createRow(rowIndex);
        for (int c = 0; c < values.length; c++) {
            if (values[c] != null) {
                row.createCell(c).setCellValue(values[c]);
            }
        }
    }

    private String[] examRow(String code, String title, String desc, String qCount, String passingScore,
            String time) {
        return new String[] { code, title, desc, qCount, passingScore, time, null };
    }

    private String[] standaloneQuestionRow(String examCode, String qText, String correct, String skill,
            String difficulty) {
        return new String[] { examCode, "1", null, qText, "Opt A", "Opt B", "Opt C", "Opt D", correct, "expl",
                skill, difficulty, null };
    }

    private String[] groupedQuestionRow(String examCode, String passage, String qText, String correct,
            String skill, String difficulty, String groupType) {
        return new String[] { examCode, "1", passage, qText, "Opt A", "Opt B", "Opt C", "Opt D", correct, "expl",
                skill, difficulty, groupType };
    }

    // =================================================================
    // importExcelMultiple
    // =================================================================

    @Test
    void importExcelMultipleShouldReturn401WhenUserDetailsNull() throws Exception {
        MockMultipartFile file = workbook(List.of(), List.of());

        ResponseEntity<Map<String, Object>> response = controller.importExcelMultiple(null, file);

        assertEquals(401, response.getStatusCode().value());
    }

    @Test
    void importExcelMultipleShouldReturn401WhenUserNotFound() throws Exception {
        lenient().when(jdbcTemplate.query(anyString(), any(org.springframework.jdbc.core.RowMapper.class), eq("ghost@example.com")))
                .thenReturn(List.of());
        MockMultipartFile file = workbook(List.of(), List.of());

        ResponseEntity<Map<String, Object>> response = controller.importExcelMultiple(principal("ghost@example.com"), file);

        assertEquals(401, response.getStatusCode().value());
    }

    @Test
    void importExcelMultipleShouldReturnBadRequestWhenNoValidExamsInSheet() throws Exception {
        stubUserId("trainer@example.com", 1L);
        stubKeyGeneratingInserts();
        MockMultipartFile file = workbook(List.of(), List.of());

        ResponseEntity<Map<String, Object>> response = controller.importExcelMultiple(principal("trainer@example.com"), file);

        assertEquals(400, response.getStatusCode().value());
        assertTrue(response.getBody().get("error").toString().contains("No valid exams"));
    }

    @Test
    void importExcelMultipleShouldReturnBadRequestWhenTitleMissing() throws Exception {
        stubUserId("trainer@example.com", 1L);
        stubKeyGeneratingInserts();
        MockMultipartFile file = workbook(
                List.<String[]>of(examRow("E1", "", "Desc", "5", "5.0", "30")), List.of());

        ResponseEntity<Map<String, Object>> response = controller.importExcelMultiple(principal("trainer@example.com"), file);

        assertEquals(400, response.getStatusCode().value());
        assertTrue(response.getBody().get("error").toString().contains("Title is required"));
    }

    @Test
    void importExcelMultipleShouldReturnBadRequestWhenDurationNotPositive() throws Exception {
        stubUserId("trainer@example.com", 1L);
        stubKeyGeneratingInserts();
        MockMultipartFile file = workbook(
                List.<String[]>of(examRow("E1", "Exam 1", "Desc", "5", "5.0", "0")), List.of());

        ResponseEntity<Map<String, Object>> response = controller.importExcelMultiple(principal("trainer@example.com"), file);

        assertEquals(400, response.getStatusCode().value());
        assertTrue(response.getBody().get("error").toString().contains("Time must be greater than 0"));
    }

    @Test
    void importExcelMultipleShouldReturnBadRequestWhenQuestionReferencesUnknownExamCode() throws Exception {
        stubUserId("trainer@example.com", 1L);
        stubKeyGeneratingInserts();
        MockMultipartFile file = workbook(
                List.<String[]>of(examRow("E1", "Exam 1", "Desc", "2", "5.0", "30")),
                List.<String[]>of(standaloneQuestionRow("E-UNKNOWN", "2+2=?", "A", "Vocabulary", "Medium")));

        ResponseEntity<Map<String, Object>> response = controller.importExcelMultiple(principal("trainer@example.com"), file);

        assertEquals(400, response.getStatusCode().value());
        assertTrue(response.getBody().get("error").toString().contains("unknown Exam Code"));
    }

    @Test
    void importExcelMultipleShouldReturnBadRequestWhenSkillTypeUnresolvable() throws Exception {
        stubUserId("trainer@example.com", 1L);
        stubKeyGeneratingInserts();
        lenient().when(jdbcTemplate.query(anyString(), any(org.springframework.jdbc.core.RowMapper.class), eq("Nonexistent Skill")))
                .thenReturn(List.of());
        MockMultipartFile file = workbook(
                List.<String[]>of(examRow("E1", "Exam 1", "Desc", "2", "5.0", "30")),
                List.<String[]>of(standaloneQuestionRow("E1", "2+2=?", "A", "Nonexistent Skill", "Medium")));

        ResponseEntity<Map<String, Object>> response = controller.importExcelMultiple(principal("trainer@example.com"), file);

        assertEquals(400, response.getStatusCode().value());
        assertTrue(response.getBody().get("error").toString().contains("Invalid Skill Type"));
    }

    @Test
    void importExcelMultipleShouldReturnBadRequestWhenCorrectAnswerNotAToD() throws Exception {
        stubUserId("trainer@example.com", 1L);
        stubKeyGeneratingInserts();
        stubSystemParam("Vocabulary", 1L);
        stubSystemParam("Medium", 2L);
        MockMultipartFile file = workbook(
                List.<String[]>of(examRow("E1", "Exam 1", "Desc", "2", "5.0", "30")),
                List.<String[]>of(standaloneQuestionRow("E1", "2+2=?", "Z", "Vocabulary", "Medium")));

        ResponseEntity<Map<String, Object>> response = controller.importExcelMultiple(principal("trainer@example.com"), file);

        assertEquals(400, response.getStatusCode().value());
        assertTrue(response.getBody().get("error").toString().contains("Correct Answer must be A, B, C, or D"));
    }

    @Test
    void importExcelMultipleShouldCreateStandaloneQuestionWithOptionsOnHappyPath() throws Exception {
        stubUserId("trainer@example.com", 1L);
        stubKeyGeneratingInserts();
        stubSystemParam("Vocabulary", 1L);
        stubSystemParam("Medium", 2L);
        MockMultipartFile file = workbook(
                List.<String[]>of(examRow("E1", "Exam 1", "Desc", "2", "5.0", "30")),
                List.of(
                        standaloneQuestionRow("E1", "2+2=?", "A", "Vocabulary", "Medium"),
                        new String[] { "E1", "2", null, "3+3=?", "Opt A", "Opt B", "Opt C", "Opt D", "A", "expl",
                                "Vocabulary", "Medium", null }));

        ResponseEntity<Map<String, Object>> response = controller.importExcelMultiple(principal("trainer@example.com"), file);

        assertEquals(200, response.getStatusCode().value());
        assertEquals(1, response.getBody().get("totalExamsCreated"));
        assertEquals(2, response.getBody().get("totalQuestionsImported"));
    }

    @Test
    void importExcelMultipleShouldCreateQuestionGroupForPassageBasedQuestions() throws Exception {
        stubUserId("trainer@example.com", 1L);
        stubKeyGeneratingInserts();
        stubSystemParam("Vocabulary", 1L);
        stubSystemParam("Medium", 2L);
        stubSystemParam("Passage Type A", 3L);
        MockMultipartFile file = workbook(
                List.<String[]>of(examRow("E1", "Exam 1", "Desc", "2", "5.0", "30")),
                List.of(
                        groupedQuestionRow("E1", "Shared passage text", "Q1 about passage", "A", "Vocabulary", "Medium", "Passage Type A"),
                        new String[] { "E1", "2", "Shared passage text", "Q2 about passage", "Opt A", "Opt B",
                                "Opt C", "Opt D", "B", "expl", "Vocabulary", "Medium", "Passage Type A" }));

        ResponseEntity<Map<String, Object>> response = controller.importExcelMultiple(principal("trainer@example.com"), file);

        assertEquals(200, response.getStatusCode().value());
        assertEquals(2, response.getBody().get("totalQuestionsImported"));
    }
}
