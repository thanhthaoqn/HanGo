package com.hango.hango_backend.service;

import com.hango.hango_backend.dto.QuestionDTO;
import com.hango.hango_backend.entity.User;
import com.hango.hango_backend.repository.UserRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;
import java.sql.Timestamp;
import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.List;

@Service
@RequiredArgsConstructor
public class TrainerQuestionServiceImpl implements TrainerQuestionService {

    private final JdbcTemplate jdbcTemplate;
    private final UserRepository userRepository;

    @Override
    public List<QuestionDTO> getTrainerQuestions(String email, String type, String search, String sortBy) {
        User user = userRepository.findByEmail(email)
                .orElseThrow(() -> new RuntimeException("User not found with email: " + email));
        
        StringBuilder sql = new StringBuilder();
        List<Object> params = new ArrayList<>();

        if ("QUIZ".equalsIgnoreCase(type)) {
            sql.append("SELECT DISTINCT q.id, q.question_text, qc.name as category_name, sp.param_value as difficulty_name, q.status, u.full_name as creator_name, q.created_at, q.updated_at ")
               .append("FROM questions q ")
               .append("JOIN lesson_quizzes lq ON q.id = lq.question_id ")
               .append("JOIN question_categories qc ON q.category_id = qc.id ")
               .append("JOIN system_parameters sp ON q.difficulty_param_id = sp.id ")
               .append("JOIN users u ON q.created_by = u.id ")
               .append("WHERE 1=1 ");
        } else { // EXAM
            sql.append("SELECT DISTINCT q.id, q.question_text, qc.name as category_name, sp.param_value as difficulty_name, q.status, u.full_name as creator_name, q.created_at, q.updated_at ")
               .append("FROM questions q ")
               .append("JOIN exam_questions eq ON q.id = eq.question_id ")
               .append("JOIN question_categories qc ON q.category_id = qc.id ")
               .append("JOIN system_parameters sp ON q.difficulty_param_id = sp.id ")
               .append("JOIN users u ON q.created_by = u.id ")
               .append("WHERE 1=1 ");
        }

        if (search != null && !search.trim().isEmpty()) {
            sql.append("AND (q.question_text LIKE ? OR qc.name LIKE ?) ");
            String searchPattern = "%" + search.trim() + "%";
            params.add(searchPattern);
            params.add(searchPattern);
        }

        if ("NEWEST".equalsIgnoreCase(sortBy)) {
            sql.append("ORDER BY q.id DESC");
        } else if ("OLDEST".equalsIgnoreCase(sortBy)) {
            sql.append("ORDER BY q.id ASC");
        } else {
            sql.append("ORDER BY q.id DESC");
        }

        return jdbcTemplate.query(sql.toString(), (rs, rowNum) -> {
            Timestamp createdTimestamp = rs.getTimestamp("created_at");
            Timestamp updatedTimestamp = rs.getTimestamp("updated_at");
            
            LocalDateTime createdAt = createdTimestamp != null ? createdTimestamp.toLocalDateTime() : LocalDateTime.now();
            LocalDateTime updatedAt = updatedTimestamp != null ? updatedTimestamp.toLocalDateTime() : LocalDateTime.now();

            return QuestionDTO.builder()
                    .id(rs.getLong("id"))
                    .questionText(rs.getString("question_text"))
                    .categoryName(rs.getString("category_name"))
                    .difficultyName(rs.getString("difficulty_name"))
                    .status(rs.getString("status"))
                    .creatorName(rs.getString("creator_name"))
                    .createdAt(createdAt)
                    .updatedAt(updatedAt)
                    .build();
        }, params.toArray());
    }
}
