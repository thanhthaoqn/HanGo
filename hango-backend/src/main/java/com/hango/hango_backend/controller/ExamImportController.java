package com.hango.hango_backend.controller;

import lombok.RequiredArgsConstructor;
import org.apache.poi.ss.usermodel.*;
import org.apache.poi.xssf.usermodel.XSSFWorkbook;
import org.springframework.http.ResponseEntity;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jdbc.support.GeneratedKeyHolder;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.multipart.MultipartFile;

import java.io.InputStream;
import java.util.*;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;

@CrossOrigin(origins = "*", maxAge = 3600)
@RestController
@RequestMapping("/api/v1/trainer/exams")
@RequiredArgsConstructor
public class ExamImportController {

    private final JdbcTemplate jdbcTemplate;

    @PostMapping("/import-excel-multiple")
    @PreAuthorize("hasAnyRole('TRAINER', 'ADMINISTRATOR', 'TRAINER_LEAD')")
    @Transactional
    public ResponseEntity<Map<String, Object>> importExcelMultiple(
            @AuthenticationPrincipal UserDetails userDetails,
            @RequestParam("file") MultipartFile file) {

        if (userDetails == null)
            return ResponseEntity.status(401).build();
        Long userId = resolveUserId(userDetails.getUsername());
        if (userId == null)
            return ResponseEntity.status(401).build();

        int totalExamsCreated = 0;
        int totalQuestionsImported = 0;

        try (InputStream is = file.getInputStream();
                Workbook workbook = new XSSFWorkbook(is)) {

            // --- 1. PARSE SHEET: EXAM ---
            Sheet examSheet = workbook.getSheetAt(1); // Sheet 2 is EXAM
            Map<String, Long> examCodeToId = new HashMap<>();

            for (int i = 1; i <= examSheet.getLastRowNum(); i++) {
                Row row = examSheet.getRow(i);
                if (row == null)
                    continue;

                String examCode = getCellString(row, 0);
                if (examCode == null || examCode.isBlank() || examCode.equals("Exam Code"))
                    continue; // Skip header or empty

                String title = getCellString(row, 1);
                String description = getCellString(row, 2);
                String qCountStr = getCellString(row, 3);
                String passingScoreStr = getCellString(row, 4);
                String timeStr = getCellString(row, 5);
                String thumbnailUrl = getCellString(row, 6);

                if (title == null || title.isBlank())
                    throw new IllegalArgumentException("Title is required at row " + (i + 1));
                if (description == null || description.isBlank())
                    throw new IllegalArgumentException("Description is required at row " + (i + 1));
                if (qCountStr == null || qCountStr.isBlank())
                    throw new IllegalArgumentException("Question Count is required at row " + (i + 1));
                if (passingScoreStr == null || passingScoreStr.isBlank())
                    throw new IllegalArgumentException("Passing Score is required at row " + (i + 1));
                if (timeStr == null || timeStr.isBlank())
                    throw new IllegalArgumentException("Time is required at row " + (i + 1));

                Integer qCount = Integer.parseInt(qCountStr);
                Double passingScore = Double.parseDouble(passingScoreStr);
                Integer durationMinutes = Integer.parseInt(timeStr);
                
                if (durationMinutes <= 0)
                    throw new IllegalArgumentException("Time must be greater than 0 at row " + (i + 1));

                GeneratedKeyHolder examKh = new GeneratedKeyHolder();
                jdbcTemplate.update(con -> {
                    var ps = con.prepareStatement(
                            "INSERT INTO exams (created_by, title, description, expected_question_count, passing_score, duration_minutes, thumbnail_url, status, version, created_at) VALUES (?, ?, ?, ?, ?, ?, ?, 'DRAFT', 'v0.1', NOW())",
                            java.sql.Statement.RETURN_GENERATED_KEYS);
                    ps.setLong(1, userId);
                    ps.setString(2, title);
                    ps.setString(3, description);
                    ps.setInt(4, qCount);
                    ps.setDouble(5, passingScore);
                    ps.setInt(6, durationMinutes);
                    if (thumbnailUrl != null)
                        ps.setString(7, thumbnailUrl);
                    else
                        ps.setNull(7, java.sql.Types.VARCHAR);
                    return ps;
                }, examKh);

                Number examKey = examKh.getKey();
                if (examKey != null) {
                    examCodeToId.put(examCode, examKey.longValue());
                    totalExamsCreated++;
                    System.out.println("Created exam: " + examCode + " with ID: " + examKey.longValue());
                }
            }

            System.out.println("Total exams created in EXAM sheet: " + totalExamsCreated);
            if (examCodeToId.isEmpty()) {
                throw new IllegalArgumentException("No valid exams found in the EXAM sheet");
            }

            // --- 2. PARSE SHEET: QUESTIONS ---
            Sheet questionSheet = workbook.getSheetAt(2); // Sheet 3 is QUESTIONS
            // Map structure: ExamCode -> PassageText -> List of Question Rows
            Map<String, Map<String, List<Row>>> examPassageGroups = new LinkedHashMap<>();

            for (int i = 1; i <= questionSheet.getLastRowNum(); i++) {
                Row row = questionSheet.getRow(i);
                if (row == null)
                    continue;

                String examCode = getCellString(row, 0);
                if (examCode == null || examCode.isBlank() || examCode.equals("Exam Code"))
                    continue;
                if (!examCodeToId.containsKey(examCode)) {
                    throw new IllegalArgumentException(
                            "Question at row " + (i + 1) + " has unknown Exam Code: " + examCode);
                }

                String passageText = getCellString(row, 2);
                String key = (passageText != null && !passageText.isBlank()) ? passageText : ("__standalone__" + i);

                examPassageGroups.computeIfAbsent(examCode, k -> new LinkedHashMap<>())
                        .computeIfAbsent(key, k -> new ArrayList<>()).add(row);
            }

            for (Map.Entry<String, Map<String, List<Row>>> examEntry : examPassageGroups.entrySet()) {
                String currentExamCode = examEntry.getKey();
                Long examId = examCodeToId.get(currentExamCode);

                for (Map.Entry<String, List<Row>> passageEntry : examEntry.getValue().entrySet()) {
                    String passageKey = passageEntry.getKey();
                    List<Row> rows = passageEntry.getValue();
                    boolean isGroup = !passageKey.startsWith("__standalone__");

                    Long groupId = null;
                    Row firstRow = rows.get(0);

                    String skillStr = getCellString(firstRow, 10);
                    String diffStr = getCellString(firstRow, 11);
                    String groupTypeStr = getCellString(firstRow, 12);

                    Long skillParamId = resolveSystemParam(skillStr);
                    Long difficultyId = resolveSystemParam(diffStr);
                    Long groupTypeId = resolveSystemParam(groupTypeStr);
                    Long categoryId = null; // Excel does not provide category

                    if (skillParamId == null)
                        throw new IllegalArgumentException(
                                "Invalid Skill Type '" + skillStr + "' at Exam " + currentExamCode);
                    if (difficultyId == null)
                        throw new IllegalArgumentException(
                                "Invalid Difficulty '" + diffStr + "' at Exam " + currentExamCode);

                    if (isGroup) {
                        if (groupTypeId == null)
                            throw new IllegalArgumentException(
                                    "Invalid Group Type '" + groupTypeStr + "' for passage at Exam " + currentExamCode);

                        final String passageText = passageKey;
                        GeneratedKeyHolder kh = new GeneratedKeyHolder();
                        jdbcTemplate.update(con -> {
                            var ps = con.prepareStatement(
                                    "INSERT INTO question_groups (context_text, group_type_param_id) VALUES (?, ?)",
                                    java.sql.Statement.RETURN_GENERATED_KEYS);
                            ps.setString(1, passageText);
                            ps.setLong(2, groupTypeId);
                            return ps;
                        }, kh);
                        Number k = kh.getKey();
                        if (k != null)
                            groupId = k.longValue();
                    }

                    for (Row row : rows) {
                        String orderStr = getCellString(row, 1);
                        String qt = getCellString(row, 3);
                        String optA = getCellString(row, 4);
                        String optB = getCellString(row, 5);
                        String optC = getCellString(row, 6);
                        String optD = getCellString(row, 7);
                        String correct = getCellString(row, 8);
                        String explanation = getCellString(row, 9);

                        if (qt == null || qt.isBlank())
                            throw new IllegalArgumentException("Question Text missing in Exam " + currentExamCode);
                        if (correct == null || correct.isBlank() || !correct.matches("(?i)^[A-D]$")) {
                            throw new IllegalArgumentException(
                                    "Correct Answer must be A, B, C, or D in Exam " + currentExamCode);
                        }

                        final Long fGroupId = groupId;
                        final Long fSkill = skillParamId;
                        final Long fDiff = difficultyId;

                        final Long fCategory = categoryId;
                        GeneratedKeyHolder qkh = new GeneratedKeyHolder();
                        jdbcTemplate.update(con -> {
                            var ps = con.prepareStatement(
                                    "INSERT INTO questions (created_by, category_id, question_text, explanation, difficulty_param_id, status, group_id, skill_param_id) VALUES (?, ?, ?, ?, ?, 'PRIVATE', ?, ?)",
                                    java.sql.Statement.RETURN_GENERATED_KEYS);
                            ps.setLong(1, userId);
                            if (fCategory != null) ps.setLong(2, fCategory);
                            else ps.setNull(2, java.sql.Types.BIGINT);
                            ps.setString(3, qt);
                            if (explanation != null)
                                ps.setString(4, explanation);
                            else
                                ps.setNull(4, java.sql.Types.VARCHAR);
                            ps.setLong(5, fDiff);
                            if (fGroupId != null)
                                ps.setLong(6, fGroupId);
                            else
                                ps.setNull(6, java.sql.Types.BIGINT);
                            ps.setLong(7, fSkill);
                            return ps;
                        }, qkh);
                        Number qk = qkh.getKey();
                        if (qk == null)
                            continue;
                        long questionId = qk.longValue();

                        String[] optTexts = { optA, optB, optC, optD };
                        String[] optLabels = { "A", "B", "C", "D" };
                        for (int oi = 0; oi < 4; oi++) {
                            String ot = optTexts[oi];
                            if (ot == null || ot.isBlank())
                                continue;
                            boolean isCorrect = optLabels[oi].equalsIgnoreCase(correct.trim());
                            jdbcTemplate.update(
                                    "INSERT INTO question_options (question_id, option_text, is_correct) VALUES (?, ?, ?)",
                                    questionId, ot, isCorrect ? 1 : 0);
                        }

                        int orderIndex = (orderStr != null && !orderStr.isBlank()) ? Integer.parseInt(orderStr) : 0;
                        jdbcTemplate.update(
                                "INSERT INTO exam_questions (exam_id, question_id, question_order) VALUES (?, ?, ?)",
                                examId, questionId, orderIndex);

                        totalQuestionsImported++;
                    }
                }
            }

            System.out.println("Total questions imported: " + totalQuestionsImported);
            workbook.close();
        } catch (IllegalArgumentException e) {
            // Throw custom validation message
            return ResponseEntity.badRequest().body(Map.of("error", e.getMessage()));
        } catch (Exception e) {
            e.printStackTrace();
            return ResponseEntity.badRequest().body(Map.of("error", "Failed to parse Excel: " + e.getMessage()));
        }

        return ResponseEntity.ok(Map.of(
                "message", "Import successful",
                "totalExamsCreated", totalExamsCreated,
                "totalQuestionsImported", totalQuestionsImported));
    }

    @GetMapping("/import-excel/template")
    @PreAuthorize("hasAnyRole('TRAINER', 'ADMINISTRATOR', 'TRAINER_LEAD')")
    public ResponseEntity<byte[]> downloadTemplate() {
        try {
            String fileName = "Hango_Exam_Import_Template.xlsx";
            List<Path> candidates = List.of(
                    Paths.get("doc", "templates", fileName),
                    Paths.get("..", "doc", "templates", fileName),
                    Paths.get("doc", "specs", "templates", fileName),
                    Paths.get("..", "doc", "specs", "templates", fileName));
            byte[] bytes = null;
            for (Path p : candidates) {
                if (Files.isRegularFile(p)) {
                    bytes = Files.readAllBytes(p);
                    break;
                }
            }
            if (bytes == null) {
                throw new java.io.IOException("Template not found");
            }
            return ResponseEntity.ok()
                    .header("Content-Disposition", "attachment; filename=" + fileName)
                    .header("Content-Type", "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet")
                    .body(bytes);
        } catch (Exception e) {
            e.printStackTrace();
            return ResponseEntity.internalServerError().build();
        }
    }

    private String getCellString(Row row, int col) {
        Cell cell = row.getCell(col, Row.MissingCellPolicy.RETURN_BLANK_AS_NULL);
        if (cell == null)
            return null;
        return switch (cell.getCellType()) {
            case STRING -> cell.getStringCellValue().trim();
            case NUMERIC -> String.valueOf((long) cell.getNumericCellValue());
            case BOOLEAN -> String.valueOf(cell.getBooleanCellValue());
            default -> null;
        };
    }

    private Long resolveSystemParam(String paramValue) {
        if (paramValue == null || paramValue.isBlank())
            return null;
        
        String searchVal = paramValue.trim();
        
        // Map old Skill Types to new ones
        if (searchVal.equalsIgnoreCase("Conversation/Short Sentences")) searchVal = "Conversation ordering"; // Or any appropriate new skill
        else if (searchVal.equalsIgnoreCase("Synonym")) searchVal = "Synonym in context";
        else if (searchVal.equalsIgnoreCase("Antonym")) searchVal = "Antonym in context";
        else if (searchVal.equalsIgnoreCase("Pronunciation")) searchVal = "Phonetics";
        else if (searchVal.equalsIgnoreCase("Grammar")) searchVal = "Vocabulary"; // Fallback
        else if (searchVal.equalsIgnoreCase("Sentence Meaning")) searchVal = "Contextual meaning";
        else if (searchVal.equalsIgnoreCase("Sentence Combining")) searchVal = "Word order";
        else if (searchVal.equalsIgnoreCase("Fill in Blank")) searchVal = "Vocabulary";
        else if (searchVal.equalsIgnoreCase("Reading Comprehension")) searchVal = "Reading Comprehension - 10 questions";
        else if (searchVal.equalsIgnoreCase("Arrangement")) searchVal = "Paragraph ordering";
        
        // Map old Group Types to new ones
        if (searchVal.equalsIgnoreCase("Notice Completion")) searchVal = "Read and Fill in a Notice";
        else if (searchVal.equalsIgnoreCase("Flyer Completion")) searchVal = "Read and Fill in a Leaflet/Advertisement";
        else if (searchVal.equalsIgnoreCase("Passage Arrangement")) searchVal = "Paragraph/Text Reordering";
        else if (searchVal.equalsIgnoreCase("Information Gap Filling")) searchVal = "Guided Cloze Test";
        else if (searchVal.equalsIgnoreCase("Reading Comprehension")) searchVal = "Reading Comprehension - 10 questions";

        List<Long> ids = jdbcTemplate.query(
                "SELECT id FROM system_parameters WHERE LOWER(param_value) = LOWER(?) LIMIT 1",
                (rs, rn) -> rs.getLong("id"), searchVal);
        return ids.isEmpty() ? null : ids.get(0);
    }

    private Long resolveCategory(String categoryName) {
        if (categoryName == null || categoryName.isBlank())
            return null;
        List<Long> ids = jdbcTemplate.query(
                "SELECT id FROM question_categories WHERE LOWER(name) = LOWER(?) LIMIT 1",
                (rs, rn) -> rs.getLong("id"), categoryName.trim());
        return ids.isEmpty() ? null : ids.get(0);
    }

    private Long resolveUserId(String email) {
        List<Long> ids = jdbcTemplate.query(
                "SELECT id FROM users WHERE email = ?",
                (rs, rn) -> rs.getLong("id"), email);
        return ids.isEmpty() ? null : ids.get(0);
    }
}
