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

@CrossOrigin(origins = "*", maxAge = 3600)
@RestController
@RequestMapping("/api/v1/trainer/exams")
@RequiredArgsConstructor
public class ExamImportController {

    private final JdbcTemplate jdbcTemplate;

    @PostMapping("/{examId}/import-excel")
    @PreAuthorize("hasAnyRole('TRAINER', 'ADMINISTRATOR', 'TRAINER_LEAD')")
    @Transactional
    public ResponseEntity<Map<String, Object>> importExcel(
            @AuthenticationPrincipal UserDetails userDetails,
            @PathVariable Long examId,
            @RequestParam("file") MultipartFile file) {

        if (userDetails == null) return ResponseEntity.status(401).build();
        Long userId = resolveUserId(userDetails.getUsername());
        if (userId == null) return ResponseEntity.status(401).build();

        List<Map<String, Object>> importedBlocks = new ArrayList<>();
        int totalQuestions = 0;

        try (InputStream is = file.getInputStream();
             Workbook workbook = new XSSFWorkbook(is)) {

            Sheet sheet = workbook.getSheetAt(0);
            Map<String, List<Row>> passageGroups = new LinkedHashMap<>();

            for (int i = 1; i <= sheet.getLastRowNum(); i++) {
                Row row = sheet.getRow(i);
                if (row == null) continue;
                String questionText = getCellString(row, 1);
                if (questionText == null || questionText.isBlank()) continue;
                String passageText = getCellString(row, 0);
                String key = (passageText != null && !passageText.isBlank())
                    ? passageText : ("__standalone__" + i);
                passageGroups.computeIfAbsent(key, k -> new ArrayList<>()).add(row);
            }

            for (Map.Entry<String, List<Row>> entry : passageGroups.entrySet()) {
                String passageKey = entry.getKey();
                List<Row> rows = entry.getValue();
                boolean isGroup = !passageKey.startsWith("__standalone__");

                Long groupId = null;
                Row firstRow = rows.get(0);
                Long skillParamId = resolveSystemParam(getCellString(firstRow, 7));
                Long difficultyId = resolveSystemParam(getCellString(firstRow, 8));
                Long categoryId = resolveCategory(getCellString(firstRow, 9));
                if (skillParamId == null) skillParamId = 1L;
                if (difficultyId == null) difficultyId = 14L;
                if (categoryId == null) categoryId = 1L;

                if (isGroup) {
                    final String passageText = passageKey;
                    GeneratedKeyHolder kh = new GeneratedKeyHolder();
                    jdbcTemplate.update(con -> {
                        var ps = con.prepareStatement(
                            "INSERT INTO question_groups (title, group_type_param_id, context_text) VALUES (?, ?, ?)",
                            java.sql.Statement.RETURN_GENERATED_KEYS);
                        ps.setString(1, "Imported Group");
                        ps.setLong(2, 17L);
                        ps.setString(3, passageText);
                        return ps;
                    }, kh);
                    Number k = kh.getKey();
                    if (k != null) groupId = k.longValue();
                }

                List<Long> questionIds = new ArrayList<>();
                for (Row row : rows) {
                    String qt = getCellString(row, 1);
                    String optA = getCellString(row, 2);
                    String optB = getCellString(row, 3);
                    String optC = getCellString(row, 4);
                    String optD = getCellString(row, 5);
                    String correct = getCellString(row, 6);

                    final Long fGroupId = groupId;
                    final Long fSkill = skillParamId;
                    final Long fDiff = difficultyId;
                    final Long fCat = categoryId;
                    GeneratedKeyHolder qkh = new GeneratedKeyHolder();
                    jdbcTemplate.update(con -> {
                        var ps = con.prepareStatement(
                            "INSERT INTO questions (created_by, category_id, question_text, difficulty_param_id, status, group_id, skill_param_id) VALUES (?, ?, ?, ?, 'PRIVATE', ?, ?)",
                            java.sql.Statement.RETURN_GENERATED_KEYS);
                        ps.setLong(1, userId);
                        ps.setLong(2, fCat);
                        ps.setString(3, qt);
                        ps.setLong(4, fDiff);
                        if (fGroupId != null) ps.setLong(5, fGroupId);
                        else ps.setNull(5, java.sql.Types.BIGINT);
                        ps.setLong(6, fSkill);
                        return ps;
                    }, qkh);
                    Number qk = qkh.getKey();
                    if (qk == null) continue;
                    long questionId = qk.longValue();
                    questionIds.add(questionId);

                    String[] optTexts = {optA, optB, optC, optD};
                    String[] optLabels = {"A", "B", "C", "D"};
                    for (int oi = 0; oi < 4; oi++) {
                        String ot = optTexts[oi];
                        if (ot == null || ot.isBlank()) continue;
                        boolean isCorrect = optLabels[oi].equalsIgnoreCase(correct != null ? correct.trim() : "");
                        jdbcTemplate.update(
                            "INSERT INTO question_options (question_id, option_text, is_correct) VALUES (?, ?, ?)",
                            questionId, ot, isCorrect ? 1 : 0);
                    }

                    int nextOrder = jdbcTemplate.queryForObject(
                        "SELECT COALESCE(MAX(question_order), 0) + 1 FROM exam_questions WHERE exam_id = ?",
                        Integer.class, examId);
                    jdbcTemplate.update(
                        "INSERT INTO exam_questions (exam_id, question_id, question_order) VALUES (?, ?, ?)",
                        examId, questionId, nextOrder);
                    totalQuestions++;
                }

                Map<String, Object> block = new HashMap<>();
                block.put("groupId", groupId);
                block.put("isGroup", isGroup);
                block.put("questionIds", questionIds);
                importedBlocks.add(block);
            }

        } catch (Exception e) {
            e.printStackTrace();
            return ResponseEntity.badRequest().body(Map.of("error", "Failed to parse Excel: " + e.getMessage()));
        }

        return ResponseEntity.ok(Map.of(
            "message", "Import successful",
            "totalQuestions", totalQuestions,
            "blocks", importedBlocks
        ));
    }

    @GetMapping("/import-excel/template")
    @PreAuthorize("hasAnyRole('TRAINER', 'ADMINISTRATOR', 'TRAINER_LEAD')")
    public ResponseEntity<byte[]> downloadTemplate() {
        try (Workbook workbook = new XSSFWorkbook()) {
            Sheet sheet = workbook.createSheet("Questions");
            CellStyle headerStyle = workbook.createCellStyle();
            Font font = workbook.createFont();
            font.setBold(true);
            headerStyle.setFont(font);
            headerStyle.setFillForegroundColor(IndexedColors.LIGHT_GREEN.getIndex());
            headerStyle.setFillPattern(FillPatternType.SOLID_FOREGROUND);

            Row header = sheet.createRow(0);
            String[] headers = {"passage_text","question_text","option_a","option_b","option_c","option_d","correct_answer (A/B/C/D)","skill_type","difficulty","category"};
            for (int i = 0; i < headers.length; i++) {
                Cell c = header.createCell(i);
                c.setCellValue(headers[i]);
                c.setCellStyle(headerStyle);
                sheet.setColumnWidth(i, 5500);
            }

            String passage = "The Amazon rainforest covers over 5.5 million square kilometres.";
            Row r1 = sheet.createRow(1);
            r1.createCell(0).setCellValue("");
            r1.createCell(1).setCellValue("What is the capital of France?");
            r1.createCell(2).setCellValue("Paris");
            r1.createCell(3).setCellValue("London");
            r1.createCell(4).setCellValue("Tokyo");
            r1.createCell(5).setCellValue("Berlin");
            r1.createCell(6).setCellValue("A");
            r1.createCell(7).setCellValue("READING");
            r1.createCell(8).setCellValue("EASY");
            r1.createCell(9).setCellValue("Grammar");

            Row r2 = sheet.createRow(2);
            r2.createCell(0).setCellValue(passage);
            r2.createCell(1).setCellValue("What type of forest is the Amazon?");
            r2.createCell(2).setCellValue("Tropical");
            r2.createCell(3).setCellValue("Temperate");
            r2.createCell(4).setCellValue("Boreal");
            r2.createCell(5).setCellValue("Mangrove");
            r2.createCell(6).setCellValue("A");
            r2.createCell(7).setCellValue("READING");
            r2.createCell(8).setCellValue("MEDIUM");
            r2.createCell(9).setCellValue("Reading Comprehension");

            Row r3 = sheet.createRow(3);
            r3.createCell(0).setCellValue(passage);
            r3.createCell(1).setCellValue("How large is the Amazon rainforest?");
            r3.createCell(2).setCellValue("2.5 million km2");
            r3.createCell(3).setCellValue("5.5 million km2");
            r3.createCell(4).setCellValue("8.0 million km2");
            r3.createCell(5).setCellValue("1.2 million km2");
            r3.createCell(6).setCellValue("B");
            r3.createCell(7).setCellValue("READING");
            r3.createCell(8).setCellValue("MEDIUM");
            r3.createCell(9).setCellValue("Reading Comprehension");

            java.io.ByteArrayOutputStream bos = new java.io.ByteArrayOutputStream();
            workbook.write(bos);

            return ResponseEntity.ok()
                .header("Content-Disposition", "attachment; filename=exam_questions_template.xlsx")
                .header("Content-Type", "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet")
                .body(bos.toByteArray());
        } catch (Exception e) {
            return ResponseEntity.internalServerError().build();
        }
    }

    private String getCellString(Row row, int col) {
        Cell cell = row.getCell(col, Row.MissingCellPolicy.RETURN_BLANK_AS_NULL);
        if (cell == null) return null;
        return switch (cell.getCellType()) {
            case STRING -> cell.getStringCellValue().trim();
            case NUMERIC -> String.valueOf((long) cell.getNumericCellValue());
            case BOOLEAN -> String.valueOf(cell.getBooleanCellValue());
            default -> null;
        };
    }

    private Long resolveSystemParam(String paramValue) {
        if (paramValue == null || paramValue.isBlank()) return null;
        List<Long> ids = jdbcTemplate.query(
            "SELECT id FROM system_parameters WHERE LOWER(param_value) = LOWER(?) LIMIT 1",
            (rs, rn) -> rs.getLong("id"), paramValue.trim());
        return ids.isEmpty() ? null : ids.get(0);
    }

    private Long resolveCategory(String categoryName) {
        if (categoryName == null || categoryName.isBlank()) return null;
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