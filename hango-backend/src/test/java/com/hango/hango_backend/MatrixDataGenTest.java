package com.hango.hango_backend;

import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.test.annotation.Rollback;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;
import java.util.Map;
import java.util.UUID;

@SpringBootTest(classes = HangoBackendApplication.class)
public class MatrixDataGenTest {

    @Autowired private JdbcTemplate jdbcTemplate;

    @Test
    @Rollback(false)
    public void generateQuestionsForMatrix21() {
        Long matrixId = 21L;
        
        List<Map<String, Object>> matrices = jdbcTemplate.queryForList("SELECT id, title FROM exam_matrices WHERE id = ?", matrixId);
        if (matrices.isEmpty()) {
            System.out.println("MATRIX 21 NOT FOUND");
            return;
        }
        System.out.println("FOUND MATRIX: " + matrices.get(0).get("title"));
        
        List<Map<String, Object>> users = jdbcTemplate.queryForList("SELECT id FROM users WHERE email = ?", "hoanglead@hango.edu.vn");
        if (users.isEmpty()) {
            System.out.println("COURSE MANAGER NOT FOUND");
            return;
        }
        Long courseManagerId = ((Number) users.get(0).get("id")).longValue();

        List<Map<String, Object>> details = jdbcTemplate.queryForList("SELECT * FROM exam_matrix_details WHERE matrix_id = ?", matrixId);
        
        for (Map<String, Object> d : details) {
            Long skillId = d.get("skill_param_id") != null ? ((Number) d.get("skill_param_id")).longValue() : null;
            Long difficultyId = d.get("difficulty_param_id") != null ? ((Number) d.get("difficulty_param_id")).longValue() : null;
            Long groupTypeId = d.get("group_type_param_id") != null ? ((Number) d.get("group_type_param_id")).longValue() : null;
            Long categoryId = d.get("category_id") != null ? ((Number) d.get("category_id")).longValue() : null;
            int quantity = ((Number) d.get("quantity")).intValue();
            
            System.out.println("Processing detail: GroupType=" + groupTypeId + ", Skill=" + skillId + ", Diff=" + difficultyId + ", Qty=" + quantity);

            int numQuestions = Math.max(2, quantity + 1);
            
            if (groupTypeId == null) {
                // Generate Single Questions
                for (int i = 0; i < numQuestions; i++) {
                    String code = "GEN_" + UUID.randomUUID().toString().substring(0, 8);
                    
                    String sql = "INSERT INTO questions (created_by, category_id, question_text, explanation, difficulty_param_id, status, skill_param_id, created_at, updated_at) " +
                                 "VALUES (?, ?, ?, ?, ?, ?, ?, NOW(), NOW())";
                    
                    jdbcTemplate.update(sql, courseManagerId, categoryId, 
                        "Generated Single Question " + i + " for detail " + d.get("id"),
                        "Generated explanation", difficultyId, "PUBLISHED", skillId);
                    
                    Long qId = jdbcTemplate.queryForObject("SELECT LAST_INSERT_ID()", Long.class);
                    
                    // Options
                    jdbcTemplate.update("INSERT INTO question_options (question_id, option_text, is_correct) VALUES (?, ?, ?)", qId, "Option A", true);
                    jdbcTemplate.update("INSERT INTO question_options (question_id, option_text, is_correct) VALUES (?, ?, ?)", qId, "Option B", false);
                    jdbcTemplate.update("INSERT INTO question_options (question_id, option_text, is_correct) VALUES (?, ?, ?)", qId, "Option C", false);
                    jdbcTemplate.update("INSERT INTO question_options (question_id, option_text, is_correct) VALUES (?, ?, ?)", qId, "Option D", false);
                    
                    System.out.println("Created single question ID " + qId);
                }
            } else {
                // Determine group type name to check if context should be empty
                String groupTypeName = "";
                List<Map<String, Object>> params = jdbcTemplate.queryForList("SELECT param_value FROM system_parameters WHERE id = ?", groupTypeId);
                if (!params.isEmpty()) {
                    groupTypeName = (String) params.get(0).get("param_value");
                }
                
                // Generate Group Questions
                for (int i = 0; i < numQuestions; i++) {
                    String contextText = "Generated Group Context " + i + " for detail " + d.get("id");
                    if (groupTypeName.equalsIgnoreCase("Paragraph/Text Reordering")) {
                        contextText = ""; // No passage
                    }
                    
                    String groupSql = "INSERT INTO question_groups (context_text, group_type_param_id) VALUES (?, ?)";
                    jdbcTemplate.update(groupSql, contextText, groupTypeId);
                    
                    Long groupId = jdbcTemplate.queryForObject("SELECT LAST_INSERT_ID()", Long.class);
                    
                    for (int j = 0; j < 3; j++) {
                        String sqSql = "INSERT INTO questions (created_by, category_id, group_id, question_text, explanation, difficulty_param_id, status, skill_param_id, created_at, updated_at) " +
                                       "VALUES (?, ?, ?, ?, ?, ?, ?, ?, NOW(), NOW())";
                        jdbcTemplate.update(sqSql, courseManagerId, categoryId, groupId,
                            "Sub Q" + j + " for group " + groupId, "Generated explanation", difficultyId, "PUBLISHED", skillId);
                            
                        Long sqId = jdbcTemplate.queryForObject("SELECT LAST_INSERT_ID()", Long.class);
                        
                        // Options
                        jdbcTemplate.update("INSERT INTO question_options (question_id, option_text, is_correct) VALUES (?, ?, ?)", sqId, "Opt A", true);
                        jdbcTemplate.update("INSERT INTO question_options (question_id, option_text, is_correct) VALUES (?, ?, ?)", sqId, "Opt B", false);
                        jdbcTemplate.update("INSERT INTO question_options (question_id, option_text, is_correct) VALUES (?, ?, ?)", sqId, "Opt C", false);
                        jdbcTemplate.update("INSERT INTO question_options (question_id, option_text, is_correct) VALUES (?, ?, ?)", sqId, "Opt D", false);
                    }
                    System.out.println("Created group ID " + groupId + " with 3 sub-questions");
                }
            }
        }
        System.out.println("FINISHED GENERATING QUESTIONS.");
    }
}
