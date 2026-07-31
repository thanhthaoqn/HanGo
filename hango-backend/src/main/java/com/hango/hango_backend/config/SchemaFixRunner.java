package com.hango.hango_backend.config;

import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.boot.CommandLineRunner;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Component;

/**
 * Chạy các lệnh ALTER TABLE cần thiết khi backend khởi động.
 * Dùng thay thế Flyway/Liquibase cho các schema fix nhỏ, idempotent.
 */
@Component
@RequiredArgsConstructor
@Slf4j
public class SchemaFixRunner implements CommandLineRunner {

    private final JdbcTemplate jdbcTemplate;

    @Override
    public void run(String... args) {
        fixExamMatrixDetailsCategoryNullable();
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
            log.info("[SchemaFix] exam_matrix_details.category_id → đã đổi thành NULL thành công.");
        } catch (Exception e) {
            // Cột có thể đã là nullable rồi → bỏ qua, không crash app
            log.debug("[SchemaFix] exam_matrix_details.category_id: {}", e.getMessage());
        }
    }
}


