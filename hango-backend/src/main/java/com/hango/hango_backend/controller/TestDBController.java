package com.hango.hango_backend.controller;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.context.annotation.Profile;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;
import java.util.Map;

@RestController
@RequestMapping("/api/test-db")
@Profile("dev")
@PreAuthorize("hasAuthority('MANAGE_ACCOUNTS_ROLES') or hasRole('ADMINISTRATOR')")
public class TestDBController {
    @Autowired
    private JdbcTemplate jdbcTemplate;

    @GetMapping({"", "/"})
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

    @GetMapping("/init-prices")
    public String initPrices() {
        try {
            // Update prices for existing courses to test VNPay payment
            jdbcTemplate.update("UPDATE courses SET price = 699000.00 WHERE id = 1");
            jdbcTemplate.update("UPDATE courses SET price = 899000.00 WHERE id = 2");
            jdbcTemplate.update("UPDATE courses SET price = 1290000.00 WHERE id = 3");
            jdbcTemplate.update("UPDATE courses SET price = 1500000.00 WHERE id > 3");
            try {
                jdbcTemplate.execute("ALTER TABLE payments MODIFY COLUMN course_id BIGINT NULL");
            } catch (Exception ignored) {}
            try {
                jdbcTemplate.execute("ALTER TABLE payments ADD COLUMN course_ids VARCHAR(255) NULL");
            } catch (Exception ignored) {}
            return "Successfully updated course prices to database!";
        } catch (Exception e) {
            e.printStackTrace();
            return "Error updating prices: " + e.getMessage();
        }
    }

    @GetMapping(value = "/seed-revenue-data", produces = "text/html;charset=UTF-8")
    public String seedRevenueData() {
        try {
            // 1. Tìm hoặc gán role Trainer cho user 1 hoặc user tìm được
            Long trainerId = null;
            try {
                trainerId = jdbcTemplate.queryForObject(
                    "SELECT id FROM users WHERE role IN ('TRAINER', 'ROLE_TRAINER', 'TEACHER') ORDER BY id ASC LIMIT 1", Long.class);
            } catch (Exception ignored) {}

            if (trainerId == null) {
                trainerId = 1L;
            }

            // Đặt password mặc định là 12345678 (BCrypt hash) cho tài khoản Trainer này để dễ đăng nhập test
            String bCryptPasswordHash = "$2a$10$8.UnVuG9HHgffUDAlk8qfOuVGkqRzgVymGe07xD0Bo17.4339Tne2";
            jdbcTemplate.update(
                "UPDATE users SET role = 'TRAINER', password_hash = ?, is_verified = 1, status = 'ACTIVE' WHERE id = ?",
                bCryptPasswordHash, trainerId);

            String trainerEmail = jdbcTemplate.queryForObject("SELECT email FROM users WHERE id = ?", String.class, trainerId);

            // 2. Tạo/Cập nhật TrainerProfile với ngân hàng
            int countProfile = jdbcTemplate.queryForObject(
                "SELECT COUNT(*) FROM trainer_profiles WHERE user_id = ?", Integer.class, trainerId);
            if (countProfile == 0) {
                jdbcTemplate.update(
                    "INSERT INTO trainer_profiles (user_id, trainer_type, bank_name, bank_account, bank_account_name, status) VALUES (?, 'PROFESSIONAL', 'Vietcombank', '190012345678', 'NGUYEN VAN A', 'VERIFIED')",
                    trainerId);
            } else {
                jdbcTemplate.update(
                    "UPDATE trainer_profiles SET trainer_type = 'PROFESSIONAL', bank_name = 'Vietcombank', bank_account = '190012345678', bank_account_name = 'NGUYEN VAN A' WHERE user_id = ?",
                    trainerId);
            }

            // 3. Đảm bảo có ít nhất 1 course thuộc về trainerId này
            Long courseId = null;
            try {
                courseId = jdbcTemplate.queryForObject(
                    "SELECT id FROM courses WHERE creator_id = ? LIMIT 1", Long.class, trainerId);
            } catch (Exception ignored) {}

            if (courseId == null) {
                try {
                    courseId = jdbcTemplate.queryForObject("SELECT id FROM courses LIMIT 1", Long.class);
                    if (courseId != null) {
                        jdbcTemplate.update("UPDATE courses SET creator_id = ? WHERE id = ?", trainerId, courseId);
                    }
                } catch (Exception ignored) {}
            }

            if (courseId == null) {
                jdbcTemplate.update("INSERT INTO courses (title, category, price, creator_id, status) VALUES ('Khóa Tiếng Anh Chuyên Sâu 2026', 'Grammar', 500000.00, ?, 'PUBLISHED')", trainerId);
                courseId = jdbcTemplate.queryForObject("SELECT LAST_INSERT_ID()", Long.class);
            }

            // 4. Tạo các thanh toán mẫu (Payments):
            jdbcTemplate.update(
                "INSERT INTO payments (user_id, course_id, txn_ref, amount, status, bank_code, created_at, paid_at, platform_fee, trainer_earnings, settlement_status) " +
                "VALUES (1, ?, CONCAT('TEST_REF_', FLOOR(RAND()*100000)), 500000.00, 'SUCCESS', 'VietQR', DATE_SUB(NOW(), INTERVAL 10 DAY), DATE_SUB(NOW(), INTERVAL 10 DAY), 150000.00, 350000.00, 'PENDING')",
                courseId);

            jdbcTemplate.update(
                "INSERT INTO payments (user_id, course_id, txn_ref, amount, status, bank_code, created_at, paid_at, platform_fee, trainer_earnings, settlement_status) " +
                "VALUES (1, ?, CONCAT('TEST_REF_', FLOOR(RAND()*100000)), 1000000.00, 'SUCCESS', 'VietQR', DATE_SUB(NOW(), INTERVAL 12 DAY), DATE_SUB(NOW(), INTERVAL 12 DAY), 300000.00, 700000.00, 'PENDING')",
                courseId);

            jdbcTemplate.update(
                "INSERT INTO payments (user_id, course_id, txn_ref, amount, status, bank_code, created_at, paid_at, platform_fee, trainer_earnings, settlement_status) " +
                "VALUES (1, ?, CONCAT('TEST_REF_', FLOOR(RAND()*100000)), 600000.00, 'SUCCESS', 'VietQR', DATE_SUB(NOW(), INTERVAL 2 DAY), DATE_SUB(NOW(), INTERVAL 2 DAY), 180000.00, 420000.00, 'PENDING')",
                courseId);

            // 5. Tạo 1 Báo cáo quyết toán mẫu cho kỳ 2026-06
            int countStatement = jdbcTemplate.queryForObject(
                "SELECT COUNT(*) FROM monthly_statements WHERE trainer_id = ? AND period_month = '2026-06'", Integer.class, trainerId);
            if (countStatement == 0) {
                jdbcTemplate.update(
                    "INSERT INTO monthly_statements (statement_code, trainer_id, period_month, total_orders, total_gross_amount, total_platform_fee, total_trainer_gross, pit_tax_amount, net_payout_amount, bank_name, bank_account, bank_account_name, status, admin_notes) " +
                    "VALUES (?, ?, '2026-06', 4, 2000000.00, 600000.00, 1400000.00, 140000.00, 1260000.00, 'Vietcombank', '190012345678', 'NGUYEN VAN A', 'PENDING_TRAINER_CONFIRM', 'Kỳ quyết toán tháng 06/2026 (Test Data)')",
                    "ST-202606-TR" + trainerId, trainerId);
            }

            return "<div style='font-family: sans-serif; padding: 20px; border: 2px solid #28B79B; border-radius: 10px; max-width: 600px; margin: 40px auto;'>" +
                   "<h2 style='color: #28B79B;'>✅ Nạp dữ liệu doanh thu thành công!</h2>" +
                   "<p>Thông tin đăng nhập tài khoản <b>Trainer</b> để test giao diện:</p>" +
                   "<ul>" +
                   "<li><b>Email:</b> <code style='background:#f1f5f9; padding: 4px 8px; border-radius: 4px; color: #0f172a; font-size: 16px;'>" + trainerEmail + "</code></li>" +
                   "<li><b>Mật khẩu:</b> <code style='background:#f1f5f9; padding: 4px 8px; border-radius: 4px; color: #0f172a; font-size: 16px;'>12345678</code></li>" +
                   "<li><b>Role:</b> TRAINER (Giáo viên chuyên nghiệp 70/30)</li>" +
                   "</ul>" +
                   "<p>👉 Bây giờ bạn có thể dùng Email và Mật khẩu trên để đăng nhập tại <b>http://localhost:3000/#/login</b>!</p>" +
                   "</div>";
        } catch (Exception e) {
            e.printStackTrace();
            return "Error seeding revenue data: " + e.getMessage();
        }
    }
}
