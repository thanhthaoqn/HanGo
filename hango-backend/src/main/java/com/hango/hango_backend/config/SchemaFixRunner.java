package com.hango.hango_backend.config;

import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.boot.CommandLineRunner;
import org.springframework.core.annotation.Order;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Component;

/**
 * Chạy các lệnh ALTER TABLE cần thiết khi backend khởi động.
 * Dùng thay thế Flyway/Liquibase cho các schema fix nhỏ, idempotent.
 */
@Component
@Order(0)
@RequiredArgsConstructor
@Slf4j
public class SchemaFixRunner implements CommandLineRunner {

    private final JdbcTemplate jdbcTemplate;

    @Override
    public void run(String... args) {
        fixSystemParametersColumn();
        fixExamMatrixDetailsCategoryNullable();
        fixOrphanedData();
    }

    private void fixSystemParametersColumn() {
        try {
            jdbcTemplate.execute("ALTER TABLE system_parameters MODIFY COLUMN param_value LONGTEXT NULL");
            log.info("[SchemaFix] system_parameters.param_value -> đã đổi thành LONGTEXT thành công.");
        } catch (Exception e) {
            log.warn("[SchemaFix] system_parameters.param_value: {}", e.getMessage());
        }
    }

    /**
     * Cho phép category_id trong exam_matrix_details là NULL.
     * Cột này lưu dạng bài (FK tới question_categories), không bắt buộc khi tạo matrix.
     */
    private void fixExamMatrixDetailsCategoryNullable() {
        try {
            jdbcTemplate.execute(
                "ALTER TABLE exam_matrix_details MODIFY COLUMN category_id BIGINT NULL"
            );
            log.info("[SchemaFix] exam_matrix_details.category_id -> đã đổi thành NULL thành công.");
        } catch (Exception e) {
            log.debug("[SchemaFix] exam_matrix_details.category_id: {}", e.getMessage());
        }
    }

    private void fixOrphanedData() {
        try {
            // Fix courses schema
            jdbcTemplate.execute("ALTER TABLE courses MODIFY COLUMN category_param_id BIGINT NULL");
            jdbcTemplate.execute("ALTER TABLE courses MODIFY COLUMN difficulty_param_id BIGINT NULL");
            jdbcTemplate.execute("ALTER TABLE questions MODIFY COLUMN skill_param_id BIGINT NULL");
            jdbcTemplate.execute("ALTER TABLE questions MODIFY COLUMN difficulty_param_id BIGINT NULL");
            jdbcTemplate.execute("ALTER TABLE question_groups MODIFY COLUMN group_type_param_id BIGINT NULL");
            
            // Clean up orphaned SystemParameters
            jdbcTemplate.update("DELETE FROM course_categories WHERE category_param_id IS NOT NULL AND category_param_id NOT IN (SELECT id FROM system_parameters)");
            jdbcTemplate.update("UPDATE courses SET category_param_id = NULL WHERE category_param_id IS NOT NULL AND category_param_id NOT IN (SELECT id FROM system_parameters)");
            jdbcTemplate.update("UPDATE courses SET difficulty_param_id = NULL WHERE difficulty_param_id IS NOT NULL AND difficulty_param_id NOT IN (SELECT id FROM system_parameters)");
            jdbcTemplate.update("UPDATE questions SET skill_param_id = NULL WHERE skill_param_id IS NOT NULL AND skill_param_id NOT IN (SELECT id FROM system_parameters)");
            jdbcTemplate.update("UPDATE questions SET difficulty_param_id = NULL WHERE difficulty_param_id IS NOT NULL AND difficulty_param_id NOT IN (SELECT id FROM system_parameters)");
            jdbcTemplate.update("UPDATE question_groups SET group_type_param_id = NULL WHERE group_type_param_id IS NOT NULL AND group_type_param_id NOT IN (SELECT id FROM system_parameters)");
            
            // Clean up orphaned Users (User id 98 causing issues in CourseRating)
            jdbcTemplate.update("DELETE FROM course_ratings WHERE user_id NOT IN (SELECT id FROM users)");
            jdbcTemplate.update("DELETE FROM enrollments WHERE user_id NOT IN (SELECT id FROM users)");
            jdbcTemplate.update("DELETE FROM certificates WHERE user_id NOT IN (SELECT id FROM users)");
            jdbcTemplate.update("DELETE FROM payments WHERE user_id NOT IN (SELECT id FROM users)");
            jdbcTemplate.update("DELETE FROM comments WHERE user_id NOT IN (SELECT id FROM users)");
            
            log.info("[SchemaFix] Cleaned up orphaned SystemParameters and Users successfully.");
        } catch (Exception e) {
            log.warn("[SchemaFix] Error cleaning up orphaned data: {}", e.getMessage());
        }
    }
}


