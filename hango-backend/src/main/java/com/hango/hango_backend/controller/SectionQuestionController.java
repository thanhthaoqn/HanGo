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
import org.springframework.security.access.prepost.PreAuthorize;
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
    @PreAuthorize("hasAuthority('MANAGE_OWN_COURSES') or hasAuthority('MANAGE_QUESTION_BANK') or hasAuthority('MANAGE_ACCOUNTS_ROLES') or hasRole('ADMINISTRATOR')")
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
    @PreAuthorize("hasAuthority('MANAGE_QUESTION_BANK') or hasAuthority('MANAGE_ACCOUNTS_ROLES') or hasRole('ADMINISTRATOR')")
    public ResponseEntity<Map<String, Object>> getSectionQuestions(
            @PathVariable Long sectionId,
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "5") int size,
            @RequestParam(required = false) String search) {

        StringBuilder sql = new StringBuilder();
        sql.append("SELECT q.id, q.question_text, q.explanation, qc.name as category_name, sp.param_value as difficulty_name, ")
           .append("q.group_id, qg.context_text as passage_text, sk.param_value as skill_name, gt.param_value as group_type_name, ")
           .append("sk.id as skill_param_id, gt.id as group_type_param_id, sp.id as difficulty_param_id ")
           .append("FROM questions q ")
           .append("JOIN question_categories qc ON q.category_id = qc.id ")
           .append("JOIN system_parameters sp ON q.difficulty_param_id = sp.id ")
           .append("LEFT JOIN question_groups qg ON q.group_id = qg.id ")
           .append("LEFT JOIN system_parameters sk ON q.skill_param_id = sk.id ")
           .append("LEFT JOIN system_parameters gt ON qg.group_type_param_id = gt.id ")
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
            
            Long groupId = rs.getObject("group_id") != null ? rs.getLong("group_id") : null;
            String passageText = rs.getString("passage_text");
            String skillName = rs.getString("skill_name");
            String groupTypeName = rs.getString("group_type_name");
            Long skillParamId = rs.getObject("skill_param_id") != null ? rs.getLong("skill_param_id") : null;
            Long groupTypeParamId = rs.getObject("group_type_param_id") != null ? rs.getLong("group_type_param_id") : null;
            Long difficultyParamId = rs.getObject("difficulty_param_id") != null ? rs.getLong("difficulty_param_id") : null;

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
            qMap.put("groupId", groupId);
            qMap.put("passageText", passageText);
            qMap.put("skillName", skillName);
            qMap.put("groupTypeName", groupTypeName);
            qMap.put("skillParamId", skillParamId);
            qMap.put("groupTypeParamId", groupTypeParamId);
            qMap.put("difficultyParamId", difficultyParamId);
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
    @PreAuthorize("hasAuthority('ATTEMPT_QUIZ_AND_EXAM') or hasAuthority('MANAGE_QUESTION_BANK') or hasAuthority('MANAGE_ACCOUNTS_ROLES') or hasRole('ADMINISTRATOR')")
    public ResponseEntity<Map<String, Object>> getLessonQuestions(
            @PathVariable Long lessonId,
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "10") int size) {

        StringBuilder sql = new StringBuilder();
        sql.append("SELECT q.id, q.question_text, q.explanation, qc.name as category_name, sp.param_value as difficulty_name, ")
           .append("q.group_id, qg.context_text as passage_text, sk.param_value as skill_name, gt.param_value as group_type_name, ")
           .append("sk.id as skill_param_id, gt.id as group_type_param_id, sp.id as difficulty_param_id ")
           .append("FROM questions q ")
           .append("JOIN lesson_quizzes lq ON q.id = lq.question_id ")
           .append("JOIN question_categories qc ON q.category_id = qc.id ")
           .append("JOIN system_parameters sp ON q.difficulty_param_id = sp.id ")
           .append("LEFT JOIN question_groups qg ON q.group_id = qg.id ")
           .append("LEFT JOIN system_parameters sk ON q.skill_param_id = sk.id ")
           .append("LEFT JOIN system_parameters gt ON qg.group_type_param_id = gt.id ")
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
            
            Long groupId = rs.getObject("group_id") != null ? rs.getLong("group_id") : null;
            String passageText = rs.getString("passage_text");
            String skillName = rs.getString("skill_name");
            String groupTypeName = rs.getString("group_type_name");
            Long skillParamId = rs.getObject("skill_param_id") != null ? rs.getLong("skill_param_id") : null;
            Long groupTypeParamId = rs.getObject("group_type_param_id") != null ? rs.getLong("group_type_param_id") : null;
            Long difficultyParamId = rs.getObject("difficulty_param_id") != null ? rs.getLong("difficulty_param_id") : null;

            List<String> options = new ArrayList<>();
            int correctIndex = 0;

            // Fetch options normally for all questions
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

            Map<String, Object> qMap = new HashMap<>();
            qMap.put("id", qId);
            qMap.put("questionText", questionText);
            qMap.put("explanation", explanation);
            qMap.put("categoryName", categoryName);
            qMap.put("difficultyName", difficultyName);
            qMap.put("options", options);
            qMap.put("correctIndex", correctIndex);
            
            qMap.put("passageText", passageText);
            qMap.put("skillName", skillName);
            qMap.put("groupTypeName", groupTypeName);
            qMap.put("skillParamId", skillParamId);
            qMap.put("groupTypeParamId", groupTypeParamId);
            qMap.put("difficultyParamId", difficultyParamId);
            if (groupId != null) {
                Map<String, Object> groupMap = new HashMap<>();
                groupMap.put("id", groupId);
                groupMap.put("groupTypeParamId", groupTypeParamId);
                groupMap.put("contextText", passageText);
                qMap.put("questionGroup", groupMap);
            }
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
    @PreAuthorize("hasAuthority('MANAGE_QUESTION_BANK') or hasAuthority('MANAGE_ACCOUNTS_ROLES') or hasRole('ADMINISTRATOR')")
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
    @PreAuthorize("hasAuthority('MANAGE_QUESTION_BANK') or hasAuthority('MANAGE_ACCOUNTS_ROLES') or hasRole('ADMINISTRATOR')")
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
    @PreAuthorize("hasAuthority('MANAGE_QUESTION_BANK') or hasAuthority('MANAGE_ACCOUNTS_ROLES') or hasRole('ADMINISTRATOR')")
    @Transactional
    public ResponseEntity<?> createQuestion(@RequestBody CreateQuestionRequestDTO request) {
        Long currentUserId = getCurrentUserId();
        if (currentUserId == null) {
            return ResponseEntity.status(401).body(Map.of("error", "Unauthorized"));
        }

        Long categoryId = request.getCategoryId() != null ? request.getCategoryId() : 1L;
        Integer catCount = jdbcTemplate.queryForObject("SELECT COUNT(*) FROM question_categories WHERE id = ?", Integer.class, categoryId);
        if (catCount == null || catCount == 0) {
            categoryId = jdbcTemplate.queryForObject("SELECT id FROM question_categories LIMIT 1", Long.class);
        }

        Long difficultyId = request.getDifficultyId() != null ? request.getDifficultyId() : 14L;
        Integer diffCount = jdbcTemplate.queryForObject("SELECT COUNT(*) FROM system_parameters WHERE id = ?", Integer.class, difficultyId);
        if (diffCount == null || diffCount == 0) {
            difficultyId = jdbcTemplate.queryForObject("SELECT id FROM system_parameters WHERE param_type = 'DIFFICULTY' LIMIT 1", Long.class);
        }

        Long skillParamId = request.getSkillParamId() != null ? request.getSkillParamId() : 1L;
        Integer skillCount = jdbcTemplate.queryForObject("SELECT COUNT(*) FROM system_parameters WHERE id = ?", Integer.class, skillParamId);
        if (skillCount == null || skillCount == 0) {
            skillParamId = jdbcTemplate.queryForObject("SELECT id FROM system_parameters WHERE param_type = 'SKILL' LIMIT 1", Long.class);
        }

        Long questionId = null;
        final Long finalCategoryId = categoryId;
        final Long finalDifficultyId = difficultyId;
        final Long finalSkillParamId = skillParamId;
        
        try {
            org.springframework.jdbc.support.GeneratedKeyHolder keyHolder = new org.springframework.jdbc.support.GeneratedKeyHolder();
            jdbcTemplate.update(connection -> {
                java.sql.PreparedStatement ps = connection.prepareStatement(
                        "INSERT INTO questions (created_by, category_id, question_text, explanation, difficulty_param_id, status, section_id, skill_param_id) VALUES (?, ?, ?, ?, ?, ?, ?, ?)",
                        java.sql.Statement.RETURN_GENERATED_KEYS
                );
                ps.setLong(1, currentUserId);
                ps.setLong(2, finalCategoryId);
                ps.setString(3, request.getQuestionText());
                ps.setString(4, request.getExplanation());
                ps.setLong(5, finalDifficultyId);
                ps.setString(6, "APPROVED");
                if (request.getSectionId() != null) {
                    ps.setLong(7, request.getSectionId());
                } else {
                    ps.setNull(7, java.sql.Types.BIGINT);
                }
                ps.setLong(8, finalSkillParamId);
                return ps;
            }, keyHolder);

            Number key = keyHolder.getKey();
            if (key != null) {
                questionId = key.longValue();
            }
        } catch (Exception e) {
            e.printStackTrace();
            return ResponseEntity.badRequest().body(Map.of("error", e.getMessage()));
        }

        if (questionId == null) {
            return ResponseEntity.badRequest().body(Map.of("error", "Failed to save question"));
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

    @PutMapping("/questions/{id}")
    @PreAuthorize("hasAuthority('MANAGE_QUESTION_BANK') or hasAuthority('MANAGE_ACCOUNTS_ROLES') or hasRole('ADMINISTRATOR')")
    @Transactional
    public ResponseEntity<?> updateQuestion(
            @PathVariable Long id,
            @RequestBody CreateQuestionRequestDTO request) {
        Long currentUserId = getCurrentUserId();
        if (currentUserId == null) {
            return ResponseEntity.status(401).body(Map.of("error", "Unauthorized"));
        }

        try {
            jdbcTemplate.update(
                    "UPDATE questions SET question_text = ?, explanation = ?, skill_param_id = ?, difficulty_param_id = ? WHERE id = ?",
                    request.getQuestionText(),
                    request.getExplanation(),
                    request.getSkillParamId(),
                    request.getDifficultyId(),
                    id
            );

            // Verify existence just in case
            Integer count = jdbcTemplate.queryForObject("SELECT COUNT(*) FROM questions WHERE id = ?", Integer.class, id);
            if (count == null || count == 0) {
                return ResponseEntity.status(404).body(Map.of("error", "Question not found"));
            }
            
            if (request.getGroupId() != null) {
                if (request.getPassageText() != null) {
                    jdbcTemplate.update(
                            "UPDATE question_groups SET context_text = ? WHERE id = ?",
                            request.getPassageText(),
                            request.getGroupId()
                    );
                }
                if (request.getGroupTypeParamId() != null) {
                    jdbcTemplate.update(
                            "UPDATE question_groups SET group_type_param_id = ? WHERE id = ?",
                            request.getGroupTypeParamId(),
                            request.getGroupId()
                    );
                }
            }

            // Update options
            jdbcTemplate.update("DELETE FROM question_options WHERE question_id = ?", id);
            List<CreateOptionDTO> options = request.getOptions();
            if (options != null && !options.isEmpty()) {
                for (CreateOptionDTO opt : options) {
                    jdbcTemplate.update(
                            "INSERT INTO question_options (question_id, option_text, is_correct) VALUES (?, ?, ?)",
                            id,
                            opt.getOptionText(),
                            opt.getIsCorrect() != null && opt.getIsCorrect() ? 1 : 0
                    );
                }
            }

            Map<String, Object> response = new HashMap<>();
            response.put("message", "Question updated successfully");
            return ResponseEntity.ok(response);
        } catch (Exception e) {
            e.printStackTrace();
            return ResponseEntity.badRequest().body(Map.of("error", "Failed to update question: " + e.getMessage()));
        }
    }

    @PostMapping("/questions/group")
    @PreAuthorize("hasAuthority('MANAGE_QUESTION_BANK') or hasAuthority('MANAGE_ACCOUNTS_ROLES') or hasRole('ADMINISTRATOR')")
    @Transactional
    public ResponseEntity<?> createGroupQuestion(@RequestBody CreateGroupQuestionRequestDTO request) {
        Long currentUserId = getCurrentUserId();
        if (currentUserId == null) {
            return ResponseEntity.status(401).body(Map.of("error", "Unauthorized"));
        }

        // Default category / skill / difficulty if null
        Long categoryId = request.getCategoryId() != null ? request.getCategoryId() : 1L;
        Integer catCount = jdbcTemplate.queryForObject("SELECT COUNT(*) FROM question_categories WHERE id = ?", Integer.class, categoryId);
        if (catCount == null || catCount == 0) {
            categoryId = jdbcTemplate.queryForObject("SELECT id FROM question_categories LIMIT 1", Long.class);
        }

        Long difficultyId = request.getDifficultyId() != null ? request.getDifficultyId() : 14L;
        Integer diffCount = jdbcTemplate.queryForObject("SELECT COUNT(*) FROM system_parameters WHERE id = ?", Integer.class, difficultyId);
        if (diffCount == null || diffCount == 0) {
            difficultyId = jdbcTemplate.queryForObject("SELECT id FROM system_parameters WHERE param_type = 'DIFFICULTY' LIMIT 1", Long.class);
        }

        Long skillParamId = request.getSkillParamId() != null ? request.getSkillParamId() : 1L;
        Integer skillCount = jdbcTemplate.queryForObject("SELECT COUNT(*) FROM system_parameters WHERE id = ?", Integer.class, skillParamId);
        if (skillCount == null || skillCount == 0) {
            skillParamId = jdbcTemplate.queryForObject("SELECT id FROM system_parameters WHERE param_type = 'SKILL' LIMIT 1", Long.class);
        }

        Long groupTypeParamId = request.getGroupTypeParamId();
        if (groupTypeParamId == null && request.getGroupTypeName() != null) {
            try {
                groupTypeParamId = jdbcTemplate.queryForObject(
                    "SELECT id FROM system_parameters WHERE param_type = 'GROUP_TYPE' AND param_value = ? LIMIT 1", 
                    Long.class, 
                    request.getGroupTypeName()
                );
            } catch (Exception e) {
                // Ignore and let it fallback to default below
            }
        }
        if (groupTypeParamId != null) {
            Integer gtCount = jdbcTemplate.queryForObject("SELECT COUNT(*) FROM system_parameters WHERE id = ?", Integer.class, groupTypeParamId);
            if (gtCount == null || gtCount == 0) groupTypeParamId = null;
        }
        if (groupTypeParamId == null) {
            groupTypeParamId = jdbcTemplate.queryForObject("SELECT id FROM system_parameters WHERE param_type = 'GROUP_TYPE' LIMIT 1", Long.class);
        }
        
        final Long finalGroupTypeParamId = groupTypeParamId;

        // 1. Insert into question_groups
        Long questionGroupId = null;
        try {
            org.springframework.jdbc.support.GeneratedKeyHolder keyHolder = new org.springframework.jdbc.support.GeneratedKeyHolder();
            jdbcTemplate.update(connection -> {
                java.sql.PreparedStatement ps = connection.prepareStatement(
                        "INSERT INTO question_groups (title, group_type_param_id, context_text) VALUES (?, ?, ?)",
                        java.sql.Statement.RETURN_GENERATED_KEYS
                );
                ps.setString(1, "Multiple Choice Group");
                ps.setLong(2, finalGroupTypeParamId); 
                ps.setString(3, request.getPassageText());
                return ps;
            }, keyHolder);

            Number key = keyHolder.getKey();
            if (key != null) {
                questionGroupId = key.longValue();
            }
        } catch (Exception e) {
            e.printStackTrace();
            return ResponseEntity.badRequest().body(Map.of("error", "Failed to create question group: " + e.getMessage()));
        }

        if (questionGroupId == null) {
            return ResponseEntity.badRequest().body(Map.of("error", "Failed to save question group context"));
        }

        // 2. Insert sub-questions
        List<Long> subQuestionIds = new ArrayList<>();
        List<CreateSubQuestionDTO> subQuestions = request.getSubQuestions();
        if (subQuestions != null && !subQuestions.isEmpty()) {
            for (CreateSubQuestionDTO subQ : subQuestions) {
                Long subQuestionId = null;
                final Long finalCategoryId = categoryId;
                final Long finalDifficultyId = difficultyId;
                final Long finalSkillParamId = skillParamId;
                
                try {
                    org.springframework.jdbc.support.GeneratedKeyHolder keyHolder = new org.springframework.jdbc.support.GeneratedKeyHolder();
                    final Long finalGroupId = questionGroupId;
                    jdbcTemplate.update(connection -> {
                        java.sql.PreparedStatement ps = connection.prepareStatement(
                                "INSERT INTO questions (created_by, category_id, question_text, explanation, difficulty_param_id, status, section_id, group_id, skill_param_id) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)",

                                java.sql.Statement.RETURN_GENERATED_KEYS
                        );
                        ps.setLong(1, currentUserId);
                        ps.setLong(2, finalCategoryId);
                        ps.setString(3, subQ.getQuestionText());
                        ps.setString(4, subQ.getExplanation());
                        ps.setLong(5, finalDifficultyId);
                        ps.setString(6, "APPROVED");
                        if (request.getSectionId() != null) {
                            ps.setLong(7, request.getSectionId());
                        } else {
                            ps.setNull(7, java.sql.Types.BIGINT);
                        }
                        ps.setLong(8, finalGroupId);
                        ps.setLong(9, finalSkillParamId);
                        return ps;

                    }, keyHolder);

                    Number key = keyHolder.getKey();
                    if (key != null) {
                        subQuestionId = key.longValue();
                        subQuestionIds.add(subQuestionId);
                    }
                } catch (Exception e) {
                    e.printStackTrace();
                    return ResponseEntity.badRequest().body(Map.of("error", "Failed to save sub question: " + e.getMessage()));
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
        response.put("id", questionGroupId);
        response.put("questionIds", subQuestionIds);
        return ResponseEntity.ok(response);
    }

    private Long getCurrentUserId() {
        org.springframework.security.core.Authentication auth = org.springframework.security.core.context.SecurityContextHolder.getContext().getAuthentication();
        if (auth != null && auth.getPrincipal() instanceof com.hango.hango_backend.security.UserDetailsImpl) {
            return ((com.hango.hango_backend.security.UserDetailsImpl) auth.getPrincipal()).getId();
        }
        return null;
    }
}
