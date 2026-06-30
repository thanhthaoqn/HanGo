package com.hango.hango_backend.controller;

import com.hango.hango_backend.dto.SectionQuestionCountDTO;
import com.hango.hango_backend.dto.QuizQuestionSelectionRequestDTO;
import com.hango.hango_backend.dto.CreateQuestionRequestDTO;
import com.hango.hango_backend.dto.CreateOptionDTO;
import com.hango.hango_backend.dto.CreateGroupQuestionRequestDTO;
import com.hango.hango_backend.dto.CreateSubQuestionDTO;
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
                Object isCorrectObj = row.get("is_correct");
                boolean isCorrect = false;
                if (isCorrectObj instanceof Boolean) {
                    isCorrect = (Boolean) isCorrectObj;
                } else if (isCorrectObj instanceof Number) {
                    isCorrect = ((Number) isCorrectObj).intValue() == 1;
                }
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

    @GetMapping("/lessons/{lessonId}/questions")
    public ResponseEntity<Map<String, Object>> getLessonQuestions(
            @PathVariable Long lessonId,
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "10") int size) {

        StringBuilder sql = new StringBuilder();
        sql.append("SELECT q.id, q.question_text, q.explanation, qc.name as category_name, sp.param_value as difficulty_name ")
           .append("FROM questions q ")
           .append("JOIN lesson_quizzes lq ON q.id = lq.question_id ")
           .append("JOIN question_categories qc ON q.category_id = qc.id ")
           .append("JOIN system_parameters sp ON q.difficulty_param_id = sp.id ")
           .append("WHERE lq.lesson_id = ? ");

        List<Object> params = new ArrayList<>();
        params.add(lessonId);

        // Fetch total elements
        String countSql = "SELECT COUNT(*) FROM (" + sql.toString() + ") AS count_tbl";
        Integer totalElements = jdbcTemplate.queryForObject(countSql, Integer.class, params.toArray());
        if (totalElements == null) totalElements = 0;

        // Apply pagination
        sql.append("ORDER BY lq.display_order ASC LIMIT ? OFFSET ?");
        params.add(size);
        params.add(page * size);

        List<Map<String, Object>> content = jdbcTemplate.query(sql.toString(), (rs, rowNum) -> {
            Long qId = rs.getLong("id");
            String questionText = rs.getString("question_text");
            String explanation = rs.getString("explanation");
            String categoryName = rs.getString("category_name");
            String difficultyName = rs.getString("difficulty_name");

            // Check if it has sub-questions
            List<Map<String, Object>> subQuestions = jdbcTemplate.queryForList(
                    "SELECT id FROM questions WHERE group_id = ?",
                    qId
            );

            List<String> options = new ArrayList<>();
            int correctIndex = 0;

            if (subQuestions != null && !subQuestions.isEmpty()) {
                categoryName = "Multiple Choice";
                // Get options of all sub-questions to count them
                for (Map<String, Object> subQ : subQuestions) {
                    Long subQId = ((Number) subQ.get("id")).longValue();
                    List<Map<String, Object>> subOpts = jdbcTemplate.queryForList(
                            "SELECT option_text FROM question_options WHERE question_id = ? ORDER BY id ASC",
                            subQId
                    );
                    for (Map<String, Object> opt : subOpts) {
                        options.add((String) opt.get("option_text"));
                    }
                }
            } else {
                // Fetch options
                List<Map<String, Object>> optionsRows = jdbcTemplate.queryForList(
                        "SELECT option_text, is_correct FROM question_options WHERE question_id = ? ORDER BY id ASC",
                        qId
                );

                for (int i = 0; i < optionsRows.size(); i++) {
                    Map<String, Object> row = optionsRows.get(i);
                    options.add((String) row.get("option_text"));
                    Object isCorrectObj = row.get("is_correct");
                    boolean isCorrect = false;
                    if (isCorrectObj instanceof Boolean) {
                        isCorrect = (Boolean) isCorrectObj;
                    } else if (isCorrectObj instanceof Number) {
                        isCorrect = ((Number) isCorrectObj).intValue() == 1;
                    }
                    if (isCorrect) {
                        correctIndex = i;
                    }
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

    @PostMapping("/questions")
    @Transactional
    public ResponseEntity<?> createQuestion(@RequestBody CreateQuestionRequestDTO request) {
        Long currentUserId = getCurrentUserId();
        if (currentUserId == null) {
            return ResponseEntity.status(401).body("{\"error\": \"Unauthorized\"}");
        }

        // Default category & difficulty if null
        Long categoryId = request.getCategoryId() != null ? request.getCategoryId() : 1L;
        Long difficultyId = request.getDifficultyId() != null ? request.getDifficultyId() : 14L;

        Long questionId = null;
        try {
            org.springframework.jdbc.support.GeneratedKeyHolder keyHolder = new org.springframework.jdbc.support.GeneratedKeyHolder();
            jdbcTemplate.update(connection -> {
                java.sql.PreparedStatement ps = connection.prepareStatement(
                        "INSERT INTO questions (created_by, category_id, question_text, explanation, difficulty_param_id, status, section_id) VALUES (?, ?, ?, ?, ?, ?, ?)",
                        java.sql.Statement.RETURN_GENERATED_KEYS
                );
                ps.setLong(1, currentUserId);
                ps.setLong(2, categoryId);
                ps.setString(3, request.getQuestionText());
                ps.setString(4, request.getExplanation());
                ps.setLong(5, difficultyId);
                ps.setString(6, "APPROVED");
                if (request.getSectionId() != null) {
                    ps.setLong(7, request.getSectionId());
                } else {
                    ps.setNull(7, java.sql.Types.BIGINT);
                }
                return ps;
            }, keyHolder);

            Number key = keyHolder.getKey();
            if (key != null) {
                questionId = key.longValue();
            }
        } catch (Exception e) {
            e.printStackTrace();
            return ResponseEntity.badRequest().body("{\"error\": \"" + e.getMessage() + "\"}");
        }

        if (questionId == null) {
            return ResponseEntity.badRequest().body("{\"error\": \"Failed to save question\"}");
        }

        // Insert options
        List<CreateOptionDTO> options = request.getOptions();
        if (options != null && !options.isEmpty()) {
            for (CreateOptionDTO opt : options) {
                jdbcTemplate.update(
                        "INSERT INTO question_options (question_id, option_text, is_correct) VALUES (?, ?, ?)",
                        questionId,
                        opt.getOptionText(),
                        opt.getIsCorrect() != null && opt.getIsCorrect() ? 1 : 0
                );
            }
        }

        Map<String, Object> response = new HashMap<>();
        response.put("message", "Question created successfully");
        response.put("id", questionId);
        return ResponseEntity.ok(response);
    }

    @PostMapping("/questions/group")
    @Transactional
    public ResponseEntity<?> createGroupQuestion(@RequestBody CreateGroupQuestionRequestDTO request) {
        Long currentUserId = getCurrentUserId();
        if (currentUserId == null) {
            return ResponseEntity.status(401).body("{\"error\": \"Unauthorized\"}");
        }

        // Default category & difficulty if null
        Long categoryId = request.getCategoryId() != null ? request.getCategoryId() : 1L;
        Long difficultyId = request.getDifficultyId() != null ? request.getDifficultyId() : 14L;

        // 1. Insert parent (passage) question
        Long parentQuestionId = null;
        try {
            org.springframework.jdbc.support.GeneratedKeyHolder keyHolder = new org.springframework.jdbc.support.GeneratedKeyHolder();
            jdbcTemplate.update(connection -> {
                java.sql.PreparedStatement ps = connection.prepareStatement(
                        "INSERT INTO questions (created_by, category_id, question_text, explanation, difficulty_param_id, status, section_id) VALUES (?, ?, ?, ?, ?, ?, ?)",
                        java.sql.Statement.RETURN_GENERATED_KEYS
                );
                ps.setLong(1, currentUserId);
                ps.setLong(2, categoryId);
                ps.setString(3, request.getPassageText());
                ps.setString(4, request.getExplanation());
                ps.setLong(5, difficultyId);
                ps.setString(6, "APPROVED");
                if (request.getSectionId() != null) {
                    ps.setLong(7, request.getSectionId());
                } else {
                    ps.setNull(7, java.sql.Types.BIGINT);
                }
                return ps;
            }, keyHolder);

            Number key = keyHolder.getKey();
            if (key != null) {
                parentQuestionId = key.longValue();
            }
        } catch (Exception e) {
            e.printStackTrace();
            return ResponseEntity.badRequest().body("{\"error\": \"" + e.getMessage() + "\"}");
        }

        if (parentQuestionId == null) {
            return ResponseEntity.badRequest().body("{\"error\": \"Failed to save passage parent question\"}");
        }

        // 2. Insert sub-questions
        List<CreateSubQuestionDTO> subQuestions = request.getSubQuestions();
        if (subQuestions != null && !subQuestions.isEmpty()) {
            for (CreateSubQuestionDTO subQ : subQuestions) {
                Long subQuestionId = null;
                try {
                    org.springframework.jdbc.support.GeneratedKeyHolder keyHolder = new org.springframework.jdbc.support.GeneratedKeyHolder();
                    final Long finalParentId = parentQuestionId;
                    jdbcTemplate.update(connection -> {
                        java.sql.PreparedStatement ps = connection.prepareStatement(
                                "INSERT INTO questions (created_by, category_id, question_text, explanation, difficulty_param_id, status, section_id, group_id) VALUES (?, ?, ?, ?, ?, ?, ?, ?)",
                                java.sql.Statement.RETURN_GENERATED_KEYS
                        );
                        ps.setLong(1, currentUserId);
                        ps.setLong(2, categoryId);
                        ps.setString(3, subQ.getQuestionText());
                        ps.setString(4, subQ.getExplanation());
                        ps.setLong(5, difficultyId);
                        ps.setString(6, "APPROVED");
                        if (request.getSectionId() != null) {
                            ps.setLong(7, request.getSectionId());
                        } else {
                            ps.setNull(7, java.sql.Types.BIGINT);
                        }
                        ps.setLong(8, finalParentId);
                        return ps;
                    }, keyHolder);

                    Number key = keyHolder.getKey();
                    if (key != null) {
                        subQuestionId = key.longValue();
                    }
                } catch (Exception e) {
                    e.printStackTrace();
                    return ResponseEntity.badRequest().body("{\"error\": \"Failed to save sub question: " + e.getMessage() + "\"}");
                }

                if (subQuestionId != null) {
                    // Insert options for this sub-question
                    List<CreateOptionDTO> options = subQ.getOptions();
                    if (options != null && !options.isEmpty()) {
                        for (CreateOptionDTO opt : options) {
                            jdbcTemplate.update(
                                    "INSERT INTO question_options (question_id, option_text, is_correct) VALUES (?, ?, ?)",
                                    subQuestionId,
                                    opt.getOptionText(),
                                    opt.getIsCorrect() != null && opt.getIsCorrect() ? 1 : 0
                            );
                        }
                    }
                }
            }
        }

        Map<String, Object> response = new HashMap<>();
        response.put("message", "Group question created successfully");
        response.put("id", parentQuestionId);
        return ResponseEntity.ok(response);
    }

    private Long getCurrentUserId() {
        org.springframework.security.core.Authentication auth = org.springframework.security.core.context.SecurityContextHolder.getContext().getAuthentication();
        if (auth != null && auth.getPrincipal() instanceof com.hango.hango_backend.sercurity.UserDetailsImpl) {
            return ((com.hango.hango_backend.sercurity.UserDetailsImpl) auth.getPrincipal()).getId();
        }
        return null;
    }
}
