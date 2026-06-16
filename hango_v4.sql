-- =========================================================================
-- ĐỒ ÁN HANGO - SCRIPT KHỞI TẠO CƠ SỞ DỮ LIỆU CHUẨN HOÀN TOÀN
-- =========================================================================

CREATE DATABASE IF NOT EXISTS hango_db;
USE hango_db;

-- Tắt kiểm tra khóa ngoại để dọn dẹp và ghi đè dữ liệu cũ
SET FOREIGN_KEY_CHECKS = 0;

-- XÓA BẢNG CŨ NẾU TỒN TẠI ĐỂ TRÁNH LỖI TRÙNG LẶP (DROP TABLES)
DROP TABLE IF EXISTS exam_reviews;
DROP TABLE IF EXISTS audit_logs;
DROP TABLE IF EXISTS notifications;
DROP TABLE IF EXISTS course_issues;
DROP TABLE IF EXISTS favorite_courses;
DROP TABLE IF EXISTS course_ratings;
DROP TABLE IF EXISTS comment_likes;
DROP TABLE IF EXISTS comments;
DROP TABLE IF EXISTS creator_tasks;
DROP TABLE IF EXISTS tasks;
DROP TABLE IF EXISTS ai_usage_logs;
DROP TABLE IF EXISTS ai_messages;
DROP TABLE IF EXISTS ai_conversations;
DROP TABLE IF EXISTS flashcard_reviews;
DROP TABLE IF EXISTS flashcards;
DROP TABLE IF EXISTS recommendation_rules;
DROP TABLE IF EXISTS skill_analysis;
DROP TABLE IF EXISTS exam_answers;
DROP TABLE IF EXISTS exam_attempts;
DROP TABLE IF EXISTS exam_questions;
DROP TABLE IF EXISTS exams;
DROP TABLE IF EXISTS lesson_quizzes;
DROP TABLE IF EXISTS question_options;
DROP TABLE IF EXISTS questions;
DROP TABLE IF EXISTS question_groups;
DROP TABLE IF EXISTS question_categories;
DROP TABLE IF EXISTS learning_progress;
DROP TABLE IF EXISTS enrollments;
DROP TABLE IF EXISTS lessons;
DROP TABLE IF EXISTS sections;
DROP TABLE IF EXISTS course_reviews;
DROP TABLE IF EXISTS courses;
DROP TABLE IF EXISTS role_permissions;
DROP TABLE IF EXISTS user_roles;
DROP TABLE IF EXISTS permissions;
DROP TABLE IF EXISTS roles;
DROP TABLE IF EXISTS users;
DROP TABLE IF EXISTS system_parameters;

-- =========================================================================
-- KHỞI TẠO HỆ THỐNG BẢNG MỚI
-- =========================================================================

CREATE TABLE system_parameters (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    param_type VARCHAR(50) NOT NULL COMMENT 'COURSE_CATEGORY, ACADEMIC_LEVEL, SKILL_TYPE, DIFFICULTY',
    param_key VARCHAR(50) NOT NULL COMMENT 'GRAMMAR, LEVEL_B1, VOCABULARY, EASY, HARD',
    param_value VARCHAR(100) NOT NULL COMMENT 'Ngữ pháp chuyên sâu, Sơ cấp A2...',
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE users (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    email VARCHAR(255) NOT NULL UNIQUE,
    password_hash VARCHAR(255) NOT NULL,
    full_name VARCHAR(255) NOT NULL,
    phone_number VARCHAR(20) NULL,
    gender VARCHAR(10) NULL,
    date_of_birth DATE NULL,
    avatar_url TEXT NULL,
    status VARCHAR(20) DEFAULT 'ACTIVE',
    is_verified BOOLEAN DEFAULT FALSE,
    last_login_at TIMESTAMP NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE roles (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    role_name VARCHAR(50) NOT NULL UNIQUE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE permissions (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    permission_code VARCHAR(100) NOT NULL UNIQUE,
    description TEXT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE user_roles (
    user_id BIGINT NOT NULL,
    role_id BIGINT NOT NULL,
    PRIMARY KEY (user_id, role_id),
    CONSTRAINT fk_ur_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    CONSTRAINT fk_ur_role FOREIGN KEY (role_id) REFERENCES roles(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE role_permissions (
    role_id BIGINT NOT NULL,
    permission_id BIGINT NOT NULL,
    PRIMARY KEY (role_id, permission_id),
    CONSTRAINT fk_rp_role FOREIGN KEY (role_id) REFERENCES roles(id) ON DELETE CASCADE,
    CONSTRAINT fk_rp_permission FOREIGN KEY (permission_id) REFERENCES permissions(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE courses (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    created_by BIGINT NOT NULL,
    category_param_id BIGINT NOT NULL,
    title VARCHAR(255) NOT NULL,
    description TEXT NULL,
    thumbnail_url TEXT NULL,
    status VARCHAR(30) DEFAULT 'DRAFT',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    deleted_at TIMESTAMP NULL,
    CONSTRAINT fk_course_creator FOREIGN KEY (created_by) REFERENCES users(id),
    CONSTRAINT fk_course_category FOREIGN KEY (category_param_id) REFERENCES system_parameters(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE course_reviews (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    course_id BIGINT NOT NULL,
    reviewer_id BIGINT NOT NULL,
    action VARCHAR(20) NOT NULL,
    comment TEXT NULL,
    reviewed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_creview_course FOREIGN KEY (course_id) REFERENCES courses(id) ON DELETE CASCADE,
    CONSTRAINT fk_creview_reviewer FOREIGN KEY (reviewer_id) REFERENCES users(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE sections (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    course_id BIGINT NOT NULL,
    title VARCHAR(255) NOT NULL,
    display_order INT DEFAULT 1,
    CONSTRAINT fk_section_course FOREIGN KEY (course_id) REFERENCES courses(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE lessons (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    section_id BIGINT NOT NULL,
    title VARCHAR(255) NOT NULL,
    lesson_type VARCHAR(20) NULL,
    skill_param_id BIGINT NOT NULL,
    difficulty_param_id BIGINT NOT NULL,
    content LONGTEXT NULL,
    display_order INT DEFAULT 1,
    deleted_at TIMESTAMP NULL,
    CONSTRAINT fk_lesson_section FOREIGN KEY (section_id) REFERENCES sections(id) ON DELETE CASCADE,
    CONSTRAINT fk_lesson_skill FOREIGN KEY (skill_param_id) REFERENCES system_parameters(id),
    CONSTRAINT fk_lesson_diff FOREIGN KEY (difficulty_param_id) REFERENCES system_parameters(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE enrollments (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    user_id BIGINT NOT NULL,
    course_id BIGINT NOT NULL,
    status VARCHAR(20) DEFAULT 'ENROLLED',
    progress_percentage DECIMAL(5,2) DEFAULT 0.00,
    enrolled_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    completed_at TIMESTAMP NULL,
    UNIQUE KEY uq_user_course (user_id, course_id),
    CONSTRAINT fk_enroll_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    CONSTRAINT fk_enroll_course FOREIGN KEY (course_id) REFERENCES courses(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE learning_progress (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    enrollment_id BIGINT NOT NULL,
    lesson_id BIGINT NOT NULL,
    status VARCHAR(20) NULL,
    completed_at TIMESTAMP NULL,
    CONSTRAINT fk_progress_enroll FOREIGN KEY (enrollment_id) REFERENCES enrollments(id) ON DELETE CASCADE,
    CONSTRAINT fk_progress_lesson FOREIGN KEY (lesson_id) REFERENCES lessons(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE question_categories (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(100) NOT NULL UNIQUE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE question_groups (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    title VARCHAR(255) NULL,
    group_type_param_id BIGINT NOT NULL,
    context_text LONGTEXT NULL,
    CONSTRAINT fk_qgroup_type FOREIGN KEY (group_type_param_id) REFERENCES system_parameters(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE questions (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    created_by BIGINT NOT NULL,
    category_id BIGINT NOT NULL,
    group_id BIGINT NULL,
    question_text TEXT NOT NULL,
    explanation TEXT NULL,
    difficulty_param_id BIGINT NOT NULL,
    status VARCHAR(20) NULL,
    CONSTRAINT fk_question_creator FOREIGN KEY (created_by) REFERENCES users(id),
    CONSTRAINT fk_question_category FOREIGN KEY (category_id) REFERENCES question_categories(id),
    CONSTRAINT fk_question_group FOREIGN KEY (group_id) REFERENCES question_groups(id) ON DELETE SET NULL,
    CONSTRAINT fk_question_diff FOREIGN KEY (difficulty_param_id) REFERENCES system_parameters(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE question_options (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    question_id BIGINT NOT NULL,
    option_text TEXT NOT NULL,
    is_correct BOOLEAN DEFAULT FALSE,
    CONSTRAINT fk_option_question FOREIGN KEY (question_id) REFERENCES questions(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ĐÃ SỬA: Thêm chữ FOREIGN bị thiếu ở ràng buộc khóa ngoại số 2
CREATE TABLE lesson_quizzes (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    lesson_id BIGINT NOT NULL,
    question_id BIGINT NOT NULL,
    display_order INT DEFAULT 0,
    UNIQUE KEY uq_lesson_question (lesson_id, question_id),
    CONSTRAINT fk_lquiz_lesson FOREIGN KEY (lesson_id) REFERENCES lessons(id) ON DELETE CASCADE,
    CONSTRAINT fk_lquiz_question FOREIGN KEY (question_id) REFERENCES questions(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE exams (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    title VARCHAR(255) NOT NULL,
    description TEXT NULL,
    duration_minutes INT NULL,
    status VARCHAR(30) NULL,
    created_by BIGINT NOT NULL,
    deleted_at TIMESTAMP NULL,
    CONSTRAINT fk_exam_creator FOREIGN KEY (created_by) REFERENCES users(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE exam_questions (
    exam_id BIGINT NOT NULL,
    question_id BIGINT NOT NULL,
    question_order INT NULL,
    PRIMARY KEY (exam_id, question_id),
    CONSTRAINT fk_eq_exam FOREIGN KEY (exam_id) REFERENCES exams(id) ON DELETE CASCADE,
    CONSTRAINT fk_eq_question FOREIGN KEY (question_id) REFERENCES questions(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE exam_attempts (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    exam_id BIGINT NOT NULL,
    student_id BIGINT NOT NULL,
    score DECIMAL(5,2) NULL,
    started_at TIMESTAMP NULL,
    submitted_at TIMESTAMP NULL,
    CONSTRAINT fk_attempt_exam FOREIGN KEY (exam_id) REFERENCES exams(id) ON DELETE CASCADE,
    CONSTRAINT fk_attempt_student FOREIGN KEY (student_id) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE exam_answers (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    attempt_id BIGINT NOT NULL,
    question_id BIGINT NOT NULL,
    selected_option_id BIGINT NULL,
    is_correct BOOLEAN NULL,
    CONSTRAINT fk_ans_attempt FOREIGN KEY (attempt_id) REFERENCES exam_attempts(id) ON DELETE CASCADE,
    CONSTRAINT fk_ans_question FOREIGN KEY (question_id) REFERENCES questions(id),
    CONSTRAINT fk_ans_option FOREIGN KEY (selected_option_id) REFERENCES question_options(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE skill_analysis (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    student_id BIGINT NOT NULL,
    skill_param_id BIGINT NOT NULL,
    correct_rate DECIMAL(5,2) NULL,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    CONSTRAINT fk_skill_student FOREIGN KEY (student_id) REFERENCES users(id) ON DELETE CASCADE,
    CONSTRAINT fk_skill_param FOREIGN KEY (skill_param_id) REFERENCES system_parameters(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE recommendation_rules (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    skill_param_id BIGINT NOT NULL,
    min_score DECIMAL(5,2) DEFAULT 0.00,
    max_score DECIMAL(5,2) DEFAULT 100.00,
    suggested_course_id BIGINT NOT NULL,
    CONSTRAINT fk_rule_skill FOREIGN KEY (skill_param_id) REFERENCES system_parameters(id),
    CONSTRAINT fk_rule_course FOREIGN KEY (suggested_course_id) REFERENCES courses(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE flashcards (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    student_id BIGINT NOT NULL,
    word VARCHAR(255) NOT NULL,
    meaning TEXT NULL,
    source_type VARCHAR(20) NULL,
    source_id BIGINT NULL,
    next_review_date DATE NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_flash_student FOREIGN KEY (student_id) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE flashcard_reviews (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    flashcard_id BIGINT NOT NULL,
    reviewed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    remembered BOOLEAN NULL,
    CONSTRAINT fk_freview_flash FOREIGN KEY (flashcard_id) REFERENCES flashcards(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE ai_conversations (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    student_id BIGINT NOT NULL,
    title VARCHAR(255) NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_ai_student FOREIGN KEY (student_id) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE ai_messages (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    conversation_id BIGINT NOT NULL,
    sender_type VARCHAR(20) NULL,
    content LONGTEXT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_amsg_conv FOREIGN KEY (conversation_id) REFERENCES ai_conversations(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE ai_usage_logs (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    user_id BIGINT NOT NULL,
    conversation_id BIGINT NOT NULL,
    prompt_tokens INT DEFAULT 0,
    response_tokens INT DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_ailog_user FOREIGN KEY (user_id) REFERENCES users(id),
    CONSTRAINT fk_ailog_conv FOREIGN KEY (conversation_id) REFERENCES ai_conversations(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE tasks (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    lead_id BIGINT NOT NULL,
    title VARCHAR(255) NOT NULL,
    description TEXT NULL,
    due_date TIMESTAMP NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_task_lead FOREIGN KEY (lead_id) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE creator_tasks (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    task_id BIGINT NOT NULL,
    creator_id BIGINT NOT NULL,
    submission_notes TEXT NULL,
    status VARCHAR(20) DEFAULT 'ASSIGNED',
    submitted_at TIMESTAMP NULL,
    reviewed_by BIGINT NULL,
    review_comment TEXT NULL,
    reviewed_at TIMESTAMP NULL,
    CONSTRAINT fk_ctask_task FOREIGN KEY (task_id) REFERENCES tasks(id) ON DELETE CASCADE,
    CONSTRAINT fk_ctask_creator FOREIGN KEY (creator_id) REFERENCES users(id) ON DELETE CASCADE,
    CONSTRAINT fk_ctask_reviewer FOREIGN KEY (reviewed_by) REFERENCES users(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE comments (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    user_id BIGINT NOT NULL,
    course_id BIGINT NULL,
    lesson_id BIGINT NULL,
    parent_comment_id BIGINT NULL,
    content TEXT NOT NULL,
    status VARCHAR(20) NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    CONSTRAINT fk_comment_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    CONSTRAINT fk_comment_course FOREIGN KEY (course_id) REFERENCES courses(id) ON DELETE CASCADE,
    CONSTRAINT fk_comment_lesson FOREIGN KEY (lesson_id) REFERENCES lessons(id) ON DELETE CASCADE,
    CONSTRAINT fk_comment_parent FOREIGN KEY (parent_comment_id) REFERENCES comments(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE comment_likes (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    comment_id BIGINT NOT NULL,
    user_id BIGINT NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE KEY uq_comment_user_like (comment_id, user_id),
    CONSTRAINT fk_like_comment FOREIGN KEY (comment_id) REFERENCES comments(id) ON DELETE CASCADE,
    CONSTRAINT fk_like_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE course_ratings (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    course_id BIGINT NOT NULL,
    student_id BIGINT NOT NULL,
    rating SMALLINT NOT NULL,
    review_content TEXT NULL,
    UNIQUE KEY uq_course_student_rate (course_id, student_id),
    CONSTRAINT fk_rate_course FOREIGN KEY (course_id) REFERENCES courses(id) ON DELETE CASCADE,
    CONSTRAINT fk_rate_student FOREIGN KEY (student_id) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE favorite_courses (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    student_id BIGINT NOT NULL,
    course_id BIGINT NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE KEY uq_student_course_fav (student_id, course_id),
    CONSTRAINT fk_fav_student FOREIGN KEY (student_id) REFERENCES users(id) ON DELETE CASCADE,
    CONSTRAINT fk_fav_course FOREIGN KEY (course_id) REFERENCES courses(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE course_issues (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    student_id BIGINT NOT NULL,
    course_id BIGINT NOT NULL,
    issue_type VARCHAR(50) NULL,
    description TEXT NULL,
    status VARCHAR(20) DEFAULT 'PENDING',
    admin_id BIGINT NULL,
    assigned_at TIMESTAMP NULL,
    CONSTRAINT fk_issue_student FOREIGN KEY (student_id) REFERENCES users(id),
    CONSTRAINT fk_issue_course FOREIGN KEY (course_id) REFERENCES courses(id) ON DELETE CASCADE,
    CONSTRAINT fk_issue_admin FOREIGN KEY (admin_id) REFERENCES users(id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE notifications (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    user_id BIGINT NOT NULL,
    title VARCHAR(255) NULL,
    content TEXT NULL,
    notification_type VARCHAR(50) NULL,
    is_read BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    read_at TIMESTAMP NULL,
    CONSTRAINT fk_noti_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE audit_logs (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    user_id BIGINT NOT NULL,
    action VARCHAR(50) NOT NULL COMMENT 'UPDATE_ROLE, BAN_USER, APPROVE_COURSE',
    entity_type VARCHAR(50) NOT NULL COMMENT 'courses, users, exams...',
    entity_id BIGINT NOT NULL,
    old_value LONGTEXT NULL,
    new_value LONGTEXT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_audit_user FOREIGN KEY (user_id) REFERENCES users(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE exam_reviews (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    exam_id BIGINT NOT NULL,
    reviewer_id BIGINT NOT NULL,
    action VARCHAR(20) NOT NULL,
    comment TEXT NULL,
    reviewed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_ereview_exam FOREIGN KEY (exam_id) REFERENCES exams(id) ON DELETE CASCADE,
    CONSTRAINT fk_ereview_reviewer FOREIGN KEY (reviewer_id) REFERENCES users(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- =========================================================================
-- SYSTEM TEST AND SEED DATA (ENGLISH ONLY EXCEPT EXAM TITLE)
-- =========================================================================

-- 1. System Parameters
INSERT INTO system_parameters (id, param_type, param_key, param_value) VALUES
(1, 'COURSE_CATEGORY', 'GRAMMAR', 'Core Grammar'),
(2, 'COURSE_CATEGORY', 'VOCABULARY', 'Topic-based Vocabulary'),
(3, 'COURSE_CATEGORY', 'READING_COMPREHENSION', 'Reading Comprehension'),
(4, 'COURSE_CATEGORY', 'LISTENING', 'English Listening Practice'),
(5, 'COURSE_CATEGORY', 'PRONUNCIATION', 'Pronunciation & Stress'),
(6, 'ACADEMIC_LEVEL', 'BASIC', 'Basic (Target 5-6 points)'),
(7, 'ACADEMIC_LEVEL', 'INTERMEDIATE', 'Intermediate (Target 7-8 points)'),
(8, 'ACADEMIC_LEVEL', 'ADVANCED', 'Advanced (Target 9-10 points)'),
(9, 'SKILL_TYPE', 'READING', 'Reading Comprehension Skill'),
(10, 'SKILL_TYPE', 'LISTENING', 'Listening Skill'),
(11, 'SKILL_TYPE', 'GRAMMAR_VOCAB', 'Grammar & Vocabulary'),
(12, 'SKILL_TYPE', 'WRITING', 'Writing Skill'),
(13, 'SKILL_TYPE', 'PRONUNCIATION', 'Pronunciation & Word Stress'),
(14, 'DIFFICULTY', 'EASY', 'Easy'),
(15, 'DIFFICULTY', 'MEDIUM', 'Medium'),
(16, 'DIFFICULTY', 'HARD', 'Hard'),
(17, 'GROUP_TYPE', 'READING_PASSAGE', 'Reading Passage'),
(18, 'GROUP_TYPE', 'CLOZE_TEST', 'Cloze Test');

-- 2. Roles
INSERT INTO roles (id, role_name) VALUES
(1, 'ADMINISTRATOR'),
(2, 'TRAINING_LEAD'),
(3, 'TRAINER'),
(4, 'LEARNER');

-- 3. Permissions
INSERT INTO permissions (id, permission_code, description) VALUES
(1, 'USER_VIEW', 'View user information'),
(2, 'USER_MANAGE', 'Manage user accounts'),
(3, 'COURSE_CREATE', 'Create and update courses'),
(4, 'COURSE_PUBLISH', 'Approve and publish courses'),
(5, 'EXAM_MANAGE', 'Manage exams and questions'),
(6, 'ANALYTICS_VIEW', 'View statistics and analytical reports'),
(7, 'AI_CHAT', 'Chat with AI assistant'),
(8, 'COMMENT_MODERATE', 'Moderate comments');

-- 4. Role Permissions
INSERT INTO role_permissions (role_id, permission_id) VALUES
(1, 1), (1, 2), (1, 6), (1, 8),
(2, 1), (2, 4), (2, 5), (2, 6), (2, 8),
(3, 3), (3, 5),
(4, 7);

-- 5. Users (Password is 12345678)
INSERT INTO users (id, email, password_hash, full_name, phone_number, gender, date_of_birth, avatar_url, status, is_verified) VALUES
(1, 'thaoadmin@hango.edu.vn', '$2a$10$R9hazG9pf8O4yH/Vp9e.XeYmH9bJb5Rz7N/x.13F39z3l4tH4gKGW', 'Luong Thi Thanh Thao', '0912345678', 'FEMALE', '2004-01-01', 'https://api.dicebear.com/7.x/adventurer/svg?seed=thao', 'ACTIVE', 1),
(2, 'hoanglead@hango.edu.vn', '$2a$10$R9hazG9pf8O4yH/Vp9e.XeYmH9bJb5Rz7N/x.13F39z3l4tH4gKGW', 'Nguyen Viet Hoang', '0923456789', 'MALE', '2004-05-15', 'https://api.dicebear.com/7.x/adventurer/svg?seed=hoang', 'ACTIVE', 1),
(3, 'thinhtrainer@hango.edu.vn', '$2a$10$R9hazG9pf8O4yH/Vp9e.XeYmH9bJb5Rz7N/x.13F39z3l4tH4gKGW', 'Nguyen Xuan Thinh', '0934567890', 'MALE', '2004-08-20', 'https://api.dicebear.com/7.x/adventurer/svg?seed=thinh', 'ACTIVE', 1),
(4, 'minhlearner@hango.edu.vn', '$2a$10$R9hazG9pf8O4yH/Vp9e.XeYmH9bJb5Rz7N/x.13F39z3l4tH4gKGW', 'Phan Nhat Minh', '0945678901', 'MALE', '2008-10-10', 'https://api.dicebear.com/7.x/adventurer/svg?seed=minh', 'ACTIVE', 1);

-- 6. User Roles
INSERT INTO user_roles (user_id, role_id) VALUES
(1, 1),
(2, 2),
(3, 3),
(4, 4);

-- 7. Courses
INSERT INTO courses (id, created_by, category_param_id, title, description, thumbnail_url, status) VALUES
(1, 3, 1, 'National High School Graduation Exam Prep - Basic Grammar', 'This course provides all key grammar knowledge for the National High School Graduation English Exam, including verb tenses, subject-verb agreement, passive voice, reported speech, and relative clauses.', 'https://images.unsplash.com/photo-1546410531-bb4caa6b424d?q=80&w=600', 'PUBLISHED'),
(2, 3, 3, 'Advanced English Reading Comprehension Techniques for the National Exam', 'An advanced course that helps students familiarize themselves with reading comprehension formats, develop skimming and scanning skills, and practice guessing vocabulary meanings through context.', 'https://images.unsplash.com/photo-1456513080510-7bf3a84b82f8?q=80&w=600', 'PUBLISHED'),
(3, 3, 2, 'Conquering Advanced Vocabulary for the National High School Graduation Exam', 'A comprehensive course summarizing 1000+ academic vocabulary words commonly appearing in the National Exams to target scores of 8, 9, and 10.', 'https://images.unsplash.com/photo-1457369804613-52c61a468e7d?q=80&w=600', 'DRAFT');

-- 8. Course Reviews
INSERT INTO course_reviews (id, course_id, reviewer_id, action, comment) VALUES
(1, 1, 2, 'APPROVE', 'Comprehensive grammar content, clear structure. Approved for publication.'),
(2, 2, 2, 'APPROVE', 'Rich reading comprehension exercises with good differentiation. Approved for publication.'),
(3, 3, 2, 'REJECT', 'Needs Vietnamese translations and illustrative examples for each vocabulary group.');

-- 9. Sections
INSERT INTO sections (id, course_id, title, display_order) VALUES
(1, 1, 'Verb Tenses', 1),
(2, 1, 'Subject-Verb Agreement', 2),
(3, 2, 'Skimming & Scanning Skills', 1),
(4, 2, 'Contextual Vocabulary Guessing Techniques', 2);

-- 10. Lessons
INSERT INTO lessons (id, section_id, title, lesson_type, skill_param_id, difficulty_param_id, content, display_order) VALUES
(1, 1, 'Simple Present and Present Continuous Tenses', 'LEARNING', 11, 14, '<p>The Simple Present tense expresses a repeated action or a general truth. Structure: S + V(s/es) / S + am/is/are.</p><p>The Present Continuous tense expresses an action happening at the time of speaking. Structure: S + am/is/are + V-ing.</p>', 1),
(2, 1, 'Simple Past and Present Perfect Tenses', 'LEARNING', 11, 14, '<p>The Simple Past tense expresses an action completed in the past. Structure: S + V-ed / V2.</p><p>The Present Perfect tense expresses an action starting in the past that continues into the present. Structure: S + have/has + V-ed / V3.</p>', 2),
(3, 1, 'Verb Tenses Practice Exercises', 'PRACTICE', 11, 14, NULL, 3),
(4, 3, 'Introduction to Skimming & Scanning', 'LEARNING', 9, 15, '<p>Skimming is reading quickly over a text to get the main idea without going deep into details.</p><p>Scanning is reading quickly through a text to locate specific information (keywords, dates, numbers) without needing to understand the whole text.</p>', 1),
(5, 3, 'Practice Skimming for Main Ideas', 'PRACTICE', 9, 15, NULL, 2);

-- 11. Enrollments
INSERT INTO enrollments (id, user_id, course_id, status, progress_percentage) VALUES
(1, 4, 1, 'ENROLLED', 66.67),
(2, 4, 2, 'ENROLLED', 0.00);

-- 12. Learning Progress
INSERT INTO learning_progress (id, enrollment_id, lesson_id, status, completed_at) VALUES
(1, 1, 1, 'COMPLETED', CURRENT_TIMESTAMP - INTERVAL 2 DAY),
(2, 1, 2, 'COMPLETED', CURRENT_TIMESTAMP - INTERVAL 1 DAY),
(3, 1, 3, 'IN_PROGRESS', NULL);

-- 13. Question Categories
INSERT INTO question_categories (id, name) VALUES
(1, 'Grammar & Vocabulary'),
(2, 'Reading Comprehension');

-- 14. Question Groups
INSERT INTO question_groups (id, title, group_type_param_id, context_text) VALUES
(1, 'Reading Comprehension - Education and Technology', 17, '<p>The integration of technology into the classroom has transformed modern education. Interactive smartboards, online learning platforms, and digital textbooks are now common tools in secondary schools. Proponents of tech-heavy education argue that it enhances learner engagement, facilitates self-paced learning, and equips students with essential digital skills. However, critics point out several drawbacks. Excessive screen time can lead to digital fatigue and focus issues. Additionally, technology-dependent classrooms can exclude students from underprivileged backgrounds who do not have reliable internet access at home. Therefore, finding a balance between digital resources and physical textbook instruction remains a key challenge for school administrators.</p>');

-- 15. Questions
INSERT INTO questions (id, created_by, category_id, group_id, question_text, explanation, difficulty_param_id, status) VALUES
(1, 3, 1, NULL, 'Every day, John _______ to school by bus, but today his father is driving him.', 'To describe a habit or routine in the present, we use the simple present tense. With the singular subject "John", the verb "go" becomes "goes".', 14, 'APPROVED'),
(2, 3, 1, NULL, 'We _______ each other since we were in high school.', 'The cue "since" followed by a past point in time indicates an action that started in the past and continues to the present, so we use the present perfect tense. Structure: S + have/has + V3.', 14, 'APPROVED'),
(3, 3, 2, 1, 'According to the passage, what is a benefit of technology-heavy education?', 'Information is in the passage: "Proponents of tech-heavy education argue that it enhances learner engagement, facilitates self-paced learning..." -> promotes self-paced learning.', 15, 'APPROVED'),
(4, 3, 2, 1, 'The word "drawbacks" in the passage is closest in meaning to _______.', 'The word "drawbacks" means limitations or disadvantages, closest in meaning to "disadvantages".', 15, 'APPROVED'),
(5, 3, 1, NULL, 'The man _______ is speaking to our teacher is my uncle.', 'The relative pronoun that functions as a subject for a person is "who".', 14, 'APPROVED');

-- 16. Question Options
INSERT INTO question_options (id, question_id, option_text, is_correct) VALUES
(1, 1, 'go', 0),
(2, 1, 'goes', 1),
(3, 1, 'went', 0),
(4, 1, 'is going', 0),
(5, 2, 'know', 0),
(6, 2, 'knew', 0),
(7, 2, 'have known', 1),
(8, 2, 'had known', 0),
(9, 3, 'It completely replaces physical textbooks', 0),
(10, 3, 'It promotes self-paced learning', 1),
(11, 3, 'It is free for all learners', 0),
(12, 3, 'It avoids digital fatigue', 0),
(13, 4, 'benefits', 0),
(14, 4, 'challenges', 0),
(15, 4, 'disadvantages', 1),
(16, 4, 'interactions', 0),
(17, 5, 'who', 1),
(18, 5, 'whom', 0),
(19, 5, 'which', 0),
(20, 5, 'whose', 0);

-- 17. Lesson Quizzes
INSERT INTO lesson_quizzes (id, lesson_id, question_id, display_order) VALUES
(1, 3, 1, 1),
(2, 3, 2, 2),
(3, 5, 3, 1),
(4, 5, 4, 2);

-- 18. Exams
INSERT INTO exams (id, title, description, duration_minutes, status, created_by) VALUES
(1, 'Đề thi thử THPT Quốc gia môn Tiếng Anh - Đề số 01', 'A comprehensive practice test covering Grammar, Vocabulary, and Reading Comprehension, following the official structure of the Ministry of Education.', 60, 'PUBLISHED', 3);

-- 19. Exam Questions
INSERT INTO exam_questions (exam_id, question_id, question_order) VALUES
(1, 1, 1),
(1, 2, 2),
(1, 3, 3),
(1, 4, 4),
(1, 5, 5);

-- 20. Exam Attempts
INSERT INTO exam_attempts (id, exam_id, student_id, score, started_at, submitted_at) VALUES
(1, 1, 4, 8.00, CURRENT_TIMESTAMP - INTERVAL 3 HOUR, CURRENT_TIMESTAMP - INTERVAL 2 HOUR - 10 MINUTE);

-- 21. Exam Answers
INSERT INTO exam_answers (id, attempt_id, question_id, selected_option_id, is_correct) VALUES
(1, 1, 1, 2, 1),
(2, 1, 2, 7, 1),
(3, 1, 3, 10, 1),
(4, 1, 4, 13, 0),
(5, 1, 5, 17, 1);

-- 22. Skill Analysis
INSERT INTO skill_analysis (id, student_id, skill_param_id, correct_rate) VALUES
(1, 4, 11, 100.00),
(2, 4, 9, 50.00);

-- 23. Recommendation Rules
INSERT INTO recommendation_rules (id, skill_param_id, min_score, max_score, suggested_course_id) VALUES
(1, 9, 0.00, 70.00, 2);

-- 24. Flashcards
INSERT INTO flashcards (id, student_id, word, meaning, source_type, source_id, next_review_date) VALUES
(1, 4, 'drawback', 'Limitation, disadvantage, shortcoming', 'LESSON', 4, CURRENT_DATE + INTERVAL 1 DAY),
(2, 4, 'skimming', 'Reading technique to quickly get the main idea of a text', 'LESSON', 4, CURRENT_DATE + INTERVAL 2 DAY);

-- 25. Flashcard Reviews
INSERT INTO flashcard_reviews (id, flashcard_id, reviewed_at, remembered) VALUES
(1, 1, CURRENT_TIMESTAMP - INTERVAL 12 HOUR, 1);

-- 26. AI Conversations
INSERT INTO ai_conversations (id, student_id, title) VALUES
(1, 4, 'Inquiring about Present Perfect and its indicators');

-- 27. AI Messages
INSERT INTO ai_messages (id, conversation_id, sender_type, content) VALUES
(1, 1, 'USER', 'Hello assistant, how can I distinguish between the present perfect and the simple past? I often get them confused.'),
(2, 1, 'ASSISTANT', 'Hi Minh! The core difference is: \n1. Simple Past is used for actions that COMPLETED in the past and have a specific time indicator (e.g., yesterday, in 2020).\n2. Present Perfect is used for actions that started in the past but CONTINUE into or relate to the present (no specific end time, e.g., since 2018, for 5 years).\n\nExamples: \n- I lived in Hanoi in 2020. (Simple Past - I do not live there anymore).\n- I have lived in Hanoi since 2020. (Present Perfect - I still live in Hanoi now).');

-- 28. AI Usage Logs
INSERT INTO ai_usage_logs (id, user_id, conversation_id, prompt_tokens, response_tokens) VALUES
(1, 4, 1, 35, 180);

-- 29. Tasks
INSERT INTO tasks (id, lead_id, title, description, due_date) VALUES
(1, 2, 'Compile Reading Comprehension Question Bank', 'Create at least 20 multiple-choice reading comprehension questions with detailed answer explanations for the text on Technology and Environment.', CURRENT_TIMESTAMP + INTERVAL 7 DAY);

-- 30. Creator Tasks
INSERT INTO creator_tasks (id, task_id, creator_id, submission_notes, status, submitted_at, reviewed_by, review_comment, reviewed_at) VALUES
(1, 1, 3, 'Here is the first batch of 10 Reading comprehension questions on Technology, along with the reading passage.', 'SUBMITTED', CURRENT_TIMESTAMP - INTERVAL 12 HOUR, NULL, NULL, NULL);

-- 31. Comments
INSERT INTO comments (id, user_id, course_id, lesson_id, parent_comment_id, content, status) VALUES
(1, 4, 1, 1, NULL, 'Hi teachers, could you please tell me when we use "always" with the present continuous tense?', 'APPROVED'),
(2, 3, 1, 1, 1, 'Hi Minh, when "always" is used with the present continuous tense, it expresses complaints or annoyance about a repeated bad habit. For example: "You are always leaving the door open!"', 'APPROVED');

-- 32. Comment Likes
INSERT INTO comment_likes (id, comment_id, user_id) VALUES
(1, 2, 4);

-- 33. Course Ratings
INSERT INTO course_ratings (id, course_id, student_id, rating, review_content) VALUES
(1, 1, 4, 5, 'The course is extremely easy to understand; the concise lessons helped me review the tenses very quickly.');

-- 34. Favorite Courses
INSERT INTO favorite_courses (id, student_id, course_id) VALUES
(1, 4, 1);

-- 35. Course Issues
INSERT INTO course_issues (id, student_id, course_id, issue_type, description, status, admin_id, assigned_at) VALUES
(1, 4, 1, 'SPELLING_ERROR', 'In lesson 2, there is a typo where a word is misspelled as "perfec" instead of "perfect".', 'PENDING', NULL, NULL);

-- 36. Notifications
INSERT INTO notifications (id, user_id, title, content, notification_type, is_read, created_at, read_at) VALUES
(1, 3, 'New Task Assigned', 'You have been assigned the task "Compile Reading Comprehension Question Bank" by Huy.', 'TASK_ASSIGNMENT', 1, CURRENT_TIMESTAMP, NULL),
(2, 2, 'New Course Submission', 'Trainer Linh has submitted the course "Advanced English Reading Comprehension Techniques for the National Exam" for review.', 'COURSE_SUBMISSION', 0, CURRENT_TIMESTAMP, NULL);

-- 37. Audit Logs
INSERT INTO audit_logs (id, user_id, action, entity_type, entity_id, old_value, new_value) VALUES
(1, 1, 'APPROVE_COURSE', 'courses', 1, 'DRAFT', 'PUBLISHED');

-- 38. Exam Reviews
INSERT INTO exam_reviews (id, exam_id, reviewer_id, action, comment) VALUES
(1, 1, 2, 'APPROVE', 'The exam has a precise structure and high-quality questions. Approved for exam publication.');

-- Bật lại kiểm tra khóa ngoại sau khi đã khởi tạo xong hoàn toàn hệ thống
SET FOREIGN_KEY_CHECKS = 1;