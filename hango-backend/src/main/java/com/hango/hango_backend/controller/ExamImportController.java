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
    @PreAuthorize("hasAuthority('MANAGE_OWN_COURSES') or hasAuthority('MANAGE_ACCOUNTS_ROLES') or hasAuthority('CREATE_AND_MANAGE_EXAMS_CM') or hasRole('ADMINISTRATOR')")
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
        Long firstExamId = null;
        String firstExamTitle = null;
        Integer firstExamExpectedCount = null;
        String firstExamDescription = null;
        Double firstExamPassingScore = null;
        Integer firstExamDurationMinutes = null;
        String firstExamThumbnailUrl = null;

        try (InputStream is = file.getInputStream();
                Workbook workbook = new XSSFWorkbook(is)) {

            List<Map<String, Object>> errors = new ArrayList<>();

            // --- PHASE 1: VALIDATE SHEET: EXAM (no DB writes) ---
            // Excel import creates exactly one exam per file: only the first
            // data row in the EXAM sheet is processed; any further row is
            // rejected so a stray/duplicate second row can't silently create
            // a second, question-less exam.
            Sheet examSheet = workbook.getSheetAt(1); // Sheet 2 is EXAM
            List<ExamRowData> validExamRows = new ArrayList<>();
            Set<String> knownExamCodes = new HashSet<>();
            int examRowCount = 0;

            for (int i = 1; i <= examSheet.getLastRowNum(); i++) {
                Row row = examSheet.getRow(i);
                if (row == null)
                    continue;

                String examCode = getCellString(row, 0);
                if (examCode == null || examCode.isBlank() || examCode.equals("Exam Code"))
                    continue; // Skip header or empty

                int rowNum = i + 1;
                examRowCount++;
                if (examRowCount > 1) {
                    addError(errors, "EXAM", rowNum, null, "TOO_MANY_ROWS", examCode,
                            "Only one exam is allowed per import; remove the extra exam row at row " + rowNum);
                    continue;
                }

                knownExamCodes.add(examCode);

                String title = getCellString(row, 1);
                String description = getCellString(row, 2);
                String qCountStr = getCellString(row, 3);
                String passingScoreStr = getCellString(row, 4);
                String timeStr = getCellString(row, 5);
                String thumbnailUrl = com.hango.hango_backend.entity.Exam.resolveThumbnailUrl(getCellString(row, 6));

                boolean rowHasError = false;
                if (title == null || title.isBlank()) {
                    addError(errors, "EXAM", rowNum, "Title", "MISSING_FIELD", title,
                            "Title is required at row " + rowNum);
                    rowHasError = true;
                }
                if (description == null || description.isBlank()) {
                    addError(errors, "EXAM", rowNum, "Description", "MISSING_FIELD", description,
                            "Description is required at row " + rowNum);
                    rowHasError = true;
                }
                if (qCountStr == null || qCountStr.isBlank()) {
                    addError(errors, "EXAM", rowNum, "Question Count", "MISSING_FIELD", qCountStr,
                            "Question Count is required at row " + rowNum);
                    rowHasError = true;
                }
                if (passingScoreStr == null || passingScoreStr.isBlank()) {
                    addError(errors, "EXAM", rowNum, "Passing Score", "MISSING_FIELD", passingScoreStr,
                            "Passing Score is required at row " + rowNum);
                    rowHasError = true;
                }
                if (timeStr == null || timeStr.isBlank()) {
                    addError(errors, "EXAM", rowNum, "Time", "MISSING_FIELD", timeStr,
                            "Time is required at row " + rowNum);
                    rowHasError = true;
                }
                if (rowHasError)
                    continue;

                Integer qCount = null;
                Double passingScore = null;
                Integer durationMinutes = null;
                boolean numericError = false;
                try {
                    qCount = Integer.parseInt(qCountStr);
                } catch (NumberFormatException nfe) {
                    addError(errors, "EXAM", rowNum, "Question Count", "INVALID_FORMAT", qCountStr,
                            "Question Count must be a number at row " + rowNum);
                    numericError = true;
                }
                try {
                    passingScore = Double.parseDouble(passingScoreStr);
                } catch (NumberFormatException nfe) {
                    addError(errors, "EXAM", rowNum, "Passing Score", "INVALID_FORMAT", passingScoreStr,
                            "Passing Score must be a number at row " + rowNum);
                    numericError = true;
                }
                try {
                    durationMinutes = Integer.parseInt(timeStr);
                } catch (NumberFormatException nfe) {
                    addError(errors, "EXAM", rowNum, "Time", "INVALID_FORMAT", timeStr,
                            "Time must be a number at row " + rowNum);
                    numericError = true;
                }
                if (numericError)
                    continue;

                boolean rangeError = false;
                if (qCount < 2 || qCount > 100) {
                    addError(errors, "EXAM", rowNum, "Question Count", "INVALID_VALUE", qCountStr,
                            "Question Count must be between 2 and 100 at row " + rowNum);
                    rangeError = true;
                }
                if (passingScore <= 0 || passingScore > 10) {
                    addError(errors, "EXAM", rowNum, "Passing Score", "INVALID_VALUE", passingScoreStr,
                            "Passing Score must be greater than 0 and at most 10 at row " + rowNum);
                    rangeError = true;
                }
                if (durationMinutes <= 0) {
                    addError(errors, "EXAM", rowNum, "Time", "INVALID_VALUE", timeStr,
                            "Time must be greater than 0 at row " + rowNum);
                    rangeError = true;
                }
                if (rangeError)
                    continue;

                validExamRows.add(new ExamRowData(examCode, title, description, qCount, passingScore,
                        durationMinutes, thumbnailUrl));
            }

            if (examRowCount == 0) {
                addError(errors, "EXAM", null, null, "MISSING_DATA", null,
                        "No valid exams found in the EXAM sheet");
            }

            // --- PHASE 2: VALIDATE SHEET: QUESTIONS (no DB writes) ---
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
                int rowNum = i + 1;
                if (!knownExamCodes.contains(examCode)) {
                    addError(errors, "QUESTIONS", rowNum, "Exam Code", "UNKNOWN_REFERENCE", examCode,
                            "Question at row " + rowNum + " has unknown Exam Code: " + examCode);
                    continue;
                }

                String passageText = getCellString(row, 2);
                String key = (passageText != null && !passageText.isBlank()) ? passageText : ("__standalone__" + i);

                examPassageGroups.computeIfAbsent(examCode, k -> new LinkedHashMap<>())
                        .computeIfAbsent(key, k -> new ArrayList<>()).add(row);
            }

            for (Map.Entry<String, Map<String, List<Row>>> examEntry : examPassageGroups.entrySet()) {
                String currentExamCode = examEntry.getKey();
                // Order Index must be unique across the whole exam, not just within one
                // passage group, since it drives exam_questions.question_order.
                Map<Integer, Integer> orderIndexFirstRow = new HashMap<>();

                for (Map.Entry<String, List<Row>> passageEntry : examEntry.getValue().entrySet()) {
                    String passageKey = passageEntry.getKey();
                    List<Row> rows = passageEntry.getValue();
                    boolean isGroup = !passageKey.startsWith("__standalone__");
                    Row firstRow = rows.get(0);

                    // Group Type describes the passage as a whole, so it's read once from
                    // the group's first row. Skill/Difficulty are per-question properties
                    // (each row is its own record per the import guidelines) and must be
                    // read from every row below, not copied from the first row of the group.
                    String groupTypeStr = getCellString(firstRow, 12);
                    Long groupTypeId = resolveSystemParam(groupTypeStr);

                    if (isGroup && groupTypeId == null) {
                        addError(errors, "QUESTIONS", firstRow.getRowNum() + 1, "Group Type", "INVALID_VALUE",
                                groupTypeStr,
                                "Invalid Group Type '" + groupTypeStr + "' for passage at Exam " + currentExamCode);
                    }

                    for (Row row : rows) {
                        int qRowNum = row.getRowNum() + 1;
                        String orderStr = getCellString(row, 1);
                        String qt = getCellString(row, 3);
                        String correct = getCellString(row, 8);
                        String skillStr = getCellString(row, 10);
                        String diffStr = getCellString(row, 11);

                        if (qt == null || qt.isBlank())
                            addError(errors, "QUESTIONS", qRowNum, "Question Text", "MISSING_FIELD", qt,
                                    "Question Text missing in Exam " + currentExamCode);

                        if (correct == null || correct.isBlank() || !correct.matches("(?i)^[A-D]$"))
                            addError(errors, "QUESTIONS", qRowNum, "Correct Answer", "INVALID_FORMAT", correct,
                                    "Correct Answer must be A, B, C, or D in Exam " + currentExamCode);

                        if (resolveSystemParam(skillStr) == null)
                            addError(errors, "QUESTIONS", qRowNum, "Skill", "INVALID_VALUE", skillStr,
                                    "Invalid Skill Type '" + skillStr + "' at Exam " + currentExamCode);

                        if (resolveSystemParam(diffStr) == null)
                            addError(errors, "QUESTIONS", qRowNum, "Difficulty", "INVALID_VALUE", diffStr,
                                    "Invalid Difficulty '" + diffStr + "' at Exam " + currentExamCode);

                        if (orderStr != null && !orderStr.isBlank()) {
                            try {
                                int orderIndexVal = Integer.parseInt(orderStr);
                                if (orderIndexVal <= 0) {
                                    addError(errors, "QUESTIONS", qRowNum, "Order Index", "INVALID_VALUE", orderStr,
                                            "Order Index must be greater than 0 in Exam " + currentExamCode);
                                } else {
                                    Integer firstRowForIndex = orderIndexFirstRow.putIfAbsent(orderIndexVal, qRowNum);
                                    if (firstRowForIndex != null) {
                                        addError(errors, "QUESTIONS", qRowNum, "Order Index", "DUPLICATE_VALUE",
                                                orderStr,
                                                "Order Index " + orderIndexVal + " is duplicated with row "
                                                        + firstRowForIndex + " in Exam " + currentExamCode);
                                    }
                                }
                            } catch (NumberFormatException nfe) {
                                addError(errors, "QUESTIONS", qRowNum, "Order Index", "INVALID_FORMAT", orderStr,
                                        "Order Index must be a number in Exam " + currentExamCode);
                            }
                        }
                    }
                }
            }

            // Cross-check the declared Question Count against how many question rows
            // were actually provided for that exam, so a mismatched Excel file is
            // caught here instead of silently importing a shorter/longer exam.
            for (ExamRowData examRow : validExamRows) {
                Map<String, List<Row>> passagesForExam = examPassageGroups.get(examRow.examCode());
                int actualCount = 0;
                if (passagesForExam != null) {
                    for (List<Row> rows : passagesForExam.values()) {
                        actualCount += rows.size();
                    }
                }
                if (actualCount != examRow.qCount()) {
                    addError(errors, "QUESTIONS", null, "Question Count", "COUNT_MISMATCH",
                            String.valueOf(actualCount),
                            "Exam " + examRow.examCode() + " declares Question Count = " + examRow.qCount()
                                    + " but " + actualCount + " question row(s) were found in the QUESTIONS sheet");
                }
            }

            // --- DECISION POINT: report every error at once, insert nothing if any exist
            // ---
            if (!errors.isEmpty()) {
                Map<String, Object> body = new HashMap<>();
                body.put("error", errors.get(0).get("message"));
                body.put("errors", errors);
                return ResponseEntity.badRequest().body(body);
            }

            // --- PHASE 3: INSERT (only reached when validation found zero errors) ---
            Map<String, Long> examCodeToId = new HashMap<>();
            for (ExamRowData examRow : validExamRows) {
                GeneratedKeyHolder examKh = new GeneratedKeyHolder();
                jdbcTemplate.update(con -> {
                    var ps = con.prepareStatement(
                            "INSERT INTO exams (created_by, title, description, expected_question_count, passing_score, duration_minutes, thumbnail_url, status, version, created_at) VALUES (?, ?, ?, ?, ?, ?, ?, 'DRAFT', 'v0.1', NOW())",
                            java.sql.Statement.RETURN_GENERATED_KEYS);
                    ps.setLong(1, userId);
                    ps.setString(2, examRow.title());
                    ps.setString(3, examRow.description());
                    ps.setInt(4, examRow.qCount());
                    ps.setDouble(5, examRow.passingScore());
                    ps.setInt(6, examRow.durationMinutes());
                    ps.setString(7, examRow.thumbnailUrl());
                    return ps;
                }, examKh);

                Number examKey = examKh.getKey();
                if (examKey != null) {
                    examCodeToId.put(examRow.examCode(), examKey.longValue());
                    totalExamsCreated++;
                    if (firstExamId == null) {
                        firstExamId = examKey.longValue();
                        firstExamTitle = examRow.title();
                        firstExamExpectedCount = examRow.qCount();
                        firstExamDescription = examRow.description();
                        firstExamPassingScore = examRow.passingScore();
                        firstExamDurationMinutes = examRow.durationMinutes();
                        firstExamThumbnailUrl = examRow.thumbnailUrl();
                    }
                    System.out.println("Created exam: " + examRow.examCode() + " with ID: " + examKey.longValue());
                }
            }

            System.out.println("Total exams created in EXAM sheet: " + totalExamsCreated);

            for (Map.Entry<String, Map<String, List<Row>>> examEntry : examPassageGroups.entrySet()) {
                String currentExamCode = examEntry.getKey();
                Long examId = examCodeToId.get(currentExamCode);
                if (examId == null)
                    continue;

                for (Map.Entry<String, List<Row>> passageEntry : examEntry.getValue().entrySet()) {
                    String passageKey = passageEntry.getKey();
                    List<Row> rows = passageEntry.getValue();
                    boolean isGroup = !passageKey.startsWith("__standalone__");

                    Long groupId = null;
                    Row firstRow = rows.get(0);

                    String groupTypeStr = getCellString(firstRow, 12);
                    Long groupTypeId = resolveSystemParam(groupTypeStr);
                    Long categoryId = null; // Excel does not provide category

                    if (isGroup) {
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

                        // Already validated in Phase 2 (no errors reached this point).
                        String skillStr = getCellString(row, 10);
                        String diffStr = getCellString(row, 11);
                        Long skillParamId = resolveSystemParam(skillStr);
                        Long difficultyId = resolveSystemParam(diffStr);

                        final Long fGroupId = groupId;
                        final Long fSkill = skillParamId;
                        final Long fDiff = difficultyId;

                        final Long fCategory = categoryId;
                        GeneratedKeyHolder qkh = new GeneratedKeyHolder();
                        jdbcTemplate.update(con -> {
                            var ps = con.prepareStatement(
                                    "INSERT INTO questions (created_by, category_id, question_text, explanation, difficulty_param_id, status, group_id, skill_param_id, usage_type, created_at, updated_at) VALUES (?, ?, ?, ?, ?, 'PRIVATE', ?, ?, 2, NOW(6), NOW(6))",
                                    java.sql.Statement.RETURN_GENERATED_KEYS);
                            ps.setLong(1, userId);
                            if (fCategory != null)
                                ps.setLong(2, fCategory);
                            else
                                ps.setNull(2, java.sql.Types.BIGINT);
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

        Map<String, Object> responseBody = new HashMap<>();
        responseBody.put("message", "Import successful");
        responseBody.put("totalExamsCreated", totalExamsCreated);
        responseBody.put("totalQuestionsImported", totalQuestionsImported);
        // Only surface a single exam to open for verification when exactly
        // one was created; with several exams there's no single obvious one
        // to jump to, so the frontend falls back to the exam list.
        if (totalExamsCreated == 1) {
            responseBody.put("examId", firstExamId);
            responseBody.put("examTitle", firstExamTitle);
            responseBody.put("examExpectedQuestionCount", firstExamExpectedCount);
            responseBody.put("examDescription", firstExamDescription);
            responseBody.put("examPassingScore", firstExamPassingScore);
            responseBody.put("examDurationMinutes", firstExamDurationMinutes);
            responseBody.put("examThumbnailUrl", firstExamThumbnailUrl);
        }
        return ResponseEntity.ok(responseBody);
    }

    @GetMapping("/import-excel/template")
    @PreAuthorize("hasAuthority('MANAGE_OWN_COURSES') or hasAuthority('MANAGE_ACCOUNTS_ROLES') or hasAuthority('CREATE_AND_MANAGE_EXAMS_CM') or hasRole('ADMINISTRATOR')")
    public ResponseEntity<byte[]> downloadTemplate() {
        try {
            String fileName = "Hango_Exam_Import_Template.xlsx";
            org.springframework.core.io.ClassPathResource resource = new org.springframework.core.io.ClassPathResource(
                    "templates/" + fileName);
            if (!resource.exists()) {
                throw new java.io.IOException("Template not found in classpath:templates/");
            }
            byte[] bytes = resource.getInputStream().readAllBytes();
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
            case NUMERIC -> formatNumericCell(cell.getNumericCellValue());
            case BOOLEAN -> String.valueOf(cell.getBooleanCellValue());
            default -> null;
        };
    }

    // Cells typed as "Number" in Excel (e.g. Passing Score entered as 7.5) must
    // keep
    // their decimal part; truncating to (long) before stringifying silently drops
    // it.
    // Whole numbers still come out as plain integers ("30", not "30.0") so existing
    // integer fields (Question Count, Time, Order Index) keep parsing correctly.
    private String formatNumericCell(double value) {
        if (!Double.isInfinite(value) && value == Math.rint(value)) {
            return String.valueOf((long) value);
        }
        return java.math.BigDecimal.valueOf(value).stripTrailingZeros().toPlainString();
    }

    private Long resolveSystemParam(String paramValue) {
        if (paramValue == null || paramValue.isBlank())
            return null;

        String searchVal = paramValue.trim();

        // Map old Skill Types to new ones
        if (searchVal.equalsIgnoreCase("Conversation/Short Sentences"))
            searchVal = "Conversation ordering"; // Or any appropriate new skill
        else if (searchVal.equalsIgnoreCase("Synonym"))
            searchVal = "Synonym in context";
        else if (searchVal.equalsIgnoreCase("Antonym"))
            searchVal = "Antonym in context";
        else if (searchVal.equalsIgnoreCase("Pronunciation"))
            searchVal = "Phonetics";
        else if (searchVal.equalsIgnoreCase("Grammar"))
            searchVal = "Vocabulary"; // Fallback
        else if (searchVal.equalsIgnoreCase("Sentence Meaning"))
            searchVal = "Contextual meaning";
        else if (searchVal.equalsIgnoreCase("Sentence Combining"))
            searchVal = "Word order";
        else if (searchVal.equalsIgnoreCase("Fill in Blank"))
            searchVal = "Vocabulary";
        else if (searchVal.equalsIgnoreCase("Reading Comprehension"))
            searchVal = "Reading Comprehension - 10 questions";
        else if (searchVal.equalsIgnoreCase("Arrangement"))
            searchVal = "Paragraph ordering";

        // Map old Group Types to new ones
        if (searchVal.equalsIgnoreCase("Notice Completion"))
            searchVal = "Read and Fill in a Notice";
        else if (searchVal.equalsIgnoreCase("Flyer Completion"))
            searchVal = "Read and Fill in a Leaflet/Advertisement";
        else if (searchVal.equalsIgnoreCase("Passage Arrangement"))
            searchVal = "Paragraph/Text Reordering";
        else if (searchVal.equalsIgnoreCase("Information Gap Filling"))
            searchVal = "Guided Cloze Test";
        else if (searchVal.equalsIgnoreCase("Reading Comprehension"))
            searchVal = "Reading Comprehension - 10 questions";

        List<Long> ids = jdbcTemplate.query(
                "SELECT id FROM system_parameters WHERE LOWER(param_value) = LOWER(?) LIMIT 1",
                (rs, rn) -> rs.getLong("id"), searchVal);
        return ids.isEmpty() ? null : ids.get(0);
    }

    private Long resolveUserId(String email) {
        List<Long> ids = jdbcTemplate.query(
                "SELECT id FROM users WHERE email = ?",
                (rs, rn) -> rs.getLong("id"), email);
        return ids.isEmpty() ? null : ids.get(0);
    }

    private void addError(List<Map<String, Object>> errors, String sheet, Integer row, String field,
            String errorType, String value, String message) {
        Map<String, Object> err = new LinkedHashMap<>();
        err.put("sheet", sheet);
        err.put("row", row);
        err.put("field", field);
        err.put("errorType", errorType);
        err.put("value", value);
        err.put("message", message);
        errors.add(err);
    }

    private record ExamRowData(String examCode, String title, String description, Integer qCount,
            Double passingScore, Integer durationMinutes, String thumbnailUrl) {
    }
}
