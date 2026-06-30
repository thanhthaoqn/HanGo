package com.hango.hango_backend.controller;

import com.hango.hango_backend.dto.SectionQuestionCountDTO;
import com.hango.hango_backend.dto.QuizQuestionSelectionRequestDTO;
import com.hango.hango_backend.entity.Section;
import com.hango.hango_backend.repository.SectionRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.bind.annotation.*;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

@CrossOrigin(origins = "*", maxAge = 3600)
@RestController
@RequestMapping("/api/v1/trainer")
@RequiredArgsConstructor
public class SectionQuestionController {

    private final SectionRepository sectionRepository;
    private final JdbcTemplate jdbcTemplate;

    @GetMapping("/courses/{courseId}/sections")
    public ResponseEntity<List<SectionQuestionCountDTO>> getCourseSections(@PathVariable Long courseId) {
        List<Section> sections = sectionRepository.findByCourseIdOrderByDisplayOrderAsc(courseId);
        List<SectionQuestionCountDTO> dtos = new ArrayList<>();
        for (Section sec : sections) {
            Integer questionCount = jdbcTemplate.queryForObject(
                    "SELECT COUNT(*) FROM questions WHERE section_id = ?",
                    Integer.class,
                    sec.getId()
            );
            dtos.add(SectionQuestionCountDTO.builder()
                    .id(sec.getId())
                    .title(sec.getTitle())
                    .description(sec.getDescription())
                    .displayOrder(sec.getDisplayOrder())
                    .questionCount(questionCount != null ? questionCount : 0)
                    .build());
        }
        return ResponseEntity.ok(dtos);
    }

    @GetMapping("/sections/{sectionId}/questions")
    public ResponseEntity<Map<String, Object>> getSectionQuestions(
            @PathVariable Long sectionId,
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "5") int size,
            @RequestParam(required = false) String search) {

        StringBuilder sql = new StringBuilder();
        sql.append("SELECT q.id, q.question_text, q.explanation, qc.name as category_name, sp.param_value as difficulty_name ")
           .append("FROM questions q ")
           .append("JOIN question_categories qc ON q.category_id = qc.id ")
           .append("JOIN system_parameters sp ON q.difficulty_param_id = sp.id ")
           .append("WHERE q.section_id = ? ");

        List<Object> params = new ArrayList<>();
        params.add(sectionId);

        if (search != null && !search.trim().isEmpty()) {
            sql.append("AND q.question_text LIKE ? ");
            params.add("%" + search.trim() + "%");
        }

        // Fetch total elements
        String countSql = "SELECT COUNT(*) FROM (" + sql.toString() + ") AS count_tbl";
        Integer totalElements = jdbcTemplate.queryForObject(countSql, Integer.class, params.toArray());
        if (totalElements == null) totalElements = 0;

        // Apply pagination
        sql.append("LIMIT ? OFFSET ?");
        params.add(size);
        params.add(page * size);

        List<Map<String, Object>> content = jdbcTemplate.query(sql.toString(), (rs, rowNum) -> {
            Long qId = rs.getLong("id");
            String questionText = rs.getString("question_text");
            String explanation = rs.getString("explanation");
            String categoryName = rs.getString("category_name");
            String difficultyName = rs.getString("difficulty_name");

            // Fetch options
            List<Map<String, Object>> optionsRows = jdbcTemplate.queryForList(
                    "SELECT option_text, is_correct FROM question_options WHERE question_id = ? ORDER BY id ASC",
                    qId
            );

            List<String> options = new ArrayList<>();
            int correctIndex = 0;
            for (int i = 0; i < optionsRows.size(); i++) {
                Map<String, Object> row = optionsRows.get(i);
                options.add((String) row.get("option_text"));
                Number isCorrectNum = (Number) row.get("is_correct");
                boolean isCorrect = isCorrectNum != null && isCorrectNum.intValue() == 1;
                if (isCorrect) {
                    correctIndex = i;
                }
            }

            Map<String, Object> qMap = new HashMap<>();
            qMap.put("id", qId);
            qMap.put("questionText", questionText);
            qMap.put("explanation", explanation);
            qMap.put("categoryName", categoryName);
            qMap.put("difficultyName", difficultyName);
            qMap.put("options", options);
            qMap.put("correctIndex", correctIndex);
            return qMap;
        }, params.toArray());

        int totalPages = (int) Math.ceil((double) totalElements / size);

        Map<String, Object> response = new HashMap<>();
        response.put("content", content);
        response.put("totalElements", totalElements);
        response.put("totalPages", totalPages);
        response.put("size", size);
        response.put("number", page);

        return ResponseEntity.ok(response);
    }

    @GetMapping("/sections/{sectionId}/questions/select")
    public ResponseEntity<List<Long>> selectSectionQuestions(
            @PathVariable Long sectionId,
            @RequestParam int quantity,
            @RequestParam String mode) { // START or RANDOM

        StringBuilder sql = new StringBuilder();
        sql.append("SELECT id FROM questions WHERE section_id = ? ");
        
        List<Object> params = new ArrayList<>();
        params.add(sectionId);

        if ("RANDOM".equalsIgnoreCase(mode)) {
            sql.append("ORDER BY RAND() ");
        } else {
            sql.append("ORDER BY id ASC ");
        }

        sql.append("LIMIT ?");
        params.add(quantity);

        List<Long> questionIds = jdbcTemplate.query(
                sql.toString(),
                (rs, rowNum) -> rs.getLong("id"),
                params.toArray()
        );

        return ResponseEntity.ok(questionIds);
    }

    @PostMapping("/lessons/{lessonId}/questions")
    @Transactional
    public ResponseEntity<?> saveQuizQuestions(
            @PathVariable Long lessonId,
            @RequestBody QuizQuestionSelectionRequestDTO request) {

        // 1. Delete existing quiz questions
        jdbcTemplate.update("DELETE FROM lesson_quizzes WHERE lesson_id = ?", lessonId);

        // 2. Insert new quiz questions
        List<Long> questionIds = request.getQuestionIds();
        if (questionIds != null && !questionIds.isEmpty()) {
            for (int i = 0; i < questionIds.size(); i++) {
                jdbcTemplate.update(
                        "INSERT INTO lesson_quizzes (lesson_id, question_id, display_order) VALUES (?, ?, ?)",
                        lessonId,
                        questionIds.get(i),
                        i + 1
                );
            }
        }

        return ResponseEntity.ok("{\"message\": \"Questions saved to quiz successfully\"}");
    }
}
