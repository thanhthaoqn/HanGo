package com.hango.hango_backend.controller;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;
import java.util.Map;

@RestController
public class TestDBController {
    @Autowired
    private JdbcTemplate jdbcTemplate;

    @GetMapping("/api/test-db")
    public String testDb() {
        try {
            Long matrixId = jdbcTemplate.queryForObject("SELECT id FROM exam_matrices WHERE title = 'Ma trận THPT Quốc Gia 2026' ORDER BY id DESC LIMIT 1", Long.class);
            List<Map<String, Object>> details = jdbcTemplate.queryForList("SELECT * FROM exam_matrix_details WHERE matrix_id = ?", matrixId);
            
            for (Map<String, Object> detail : details) {
                Long catId = (Long) detail.get("category_id");
                Long diffId = (Long) detail.get("difficulty_param_id");
                Long skillId = (Long) detail.get("skill_param_id");
                Integer quantity = (Integer) detail.get("quantity");
                
                for (int i = 0; i < quantity; i++) {
                    jdbcTemplate.update("INSERT INTO questions (created_by, category_id, difficulty_param_id, skill_param_id, question_text, status, created_at, updated_at) VALUES (1, ?, ?, ?, ?, 'PUBLIC', NOW(), NOW())",
                        catId, diffId, skillId, "Mock Question " + (i + 1) + " for Matrix");
                }
            }
            return "Seeded questions for Matrix!";
        } catch(Exception e) {
            e.printStackTrace();
            return "Error: " + e.getMessage();
        }
    }

    @GetMapping("/api/test-db/init-prices")
    public String initPrices() {
        try {
            // Update prices for existing courses to test VNPay payment
            jdbcTemplate.update("UPDATE courses SET price = 699000.00 WHERE id = 1");
            jdbcTemplate.update("UPDATE courses SET price = 899000.00 WHERE id = 2");
            jdbcTemplate.update("UPDATE courses SET price = 1290000.00 WHERE id = 3");
            jdbcTemplate.update("UPDATE courses SET price = 1500000.00 WHERE id > 3");
            return "Successfully updated course prices to database!";
        } catch (Exception e) {
            e.printStackTrace();
            return "Error updating prices: " + e.getMessage();
        }
    }
}
