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
import java.util.Map;
import java.util.HashMap;
import org.springframework.transaction.annotation.Transactional;
import com.hango.hango_backend.dto.CreateGroupQuestionRequestDTO;
import com.hango.hango_backend.dto.CreateSubQuestionDTO;
import com.hango.hango_backend.dto.CreateOptionDTO;
import com.hango.hango_backend.entity.QuestionGroup;
import com.hango.hango_backend.entity.Question;
import com.hango.hango_backend.entity.QuestionOption;
import com.hango.hango_backend.entity.SystemParameter;
import com.hango.hango_backend.entity.QuestionCategory;
import com.hango.hango_backend.repository.QuestionGroupRepository;
import com.hango.hango_backend.repository.QuestionRepository;
import com.hango.hango_backend.repository.QuestionCategoryRepository;
import com.hango.hango_backend.repository.SystemParameterRepository;

@Service
@RequiredArgsConstructor
public class TrainerQuestionServiceImpl implements TrainerQuestionService {

    private final JdbcTemplate jdbcTemplate;
    private final UserRepository userRepository;
    private final QuestionGroupRepository questionGroupRepository;
    private final QuestionRepository questionRepository;
    private final QuestionCategoryRepository categoryRepository;
    private final SystemParameterRepository systemParameterRepository;

    @Override
    public List<QuestionDTO> getTrainerQuestions(String email, String type, String search, String sortBy) {
        User user = userRepository.findByEmail(email)
                .orElseThrow(() -> new RuntimeException("User not found with email: " + email));

        StringBuilder sql = new StringBuilder();
        List<Object> params = new ArrayList<>();

        // Remove filtering by Quiz/Exam since Question Bank should show ALL questions created by trainer
        sql.append(
                "SELECT DISTINCT q.id, q.question_text, qc.name as category_name, sp.param_value as difficulty_name, q.status, u.full_name as creator_name, q.created_at, q.updated_at ")
                .append("FROM questions q ")
                .append("JOIN question_categories qc ON q.category_id = qc.id ")
                .append("LEFT JOIN system_parameters sp ON q.difficulty_param_id = sp.id ")
                .append("JOIN users u ON q.created_by = u.id ")
                .append("WHERE q.created_by = ? ");
        params.add(user.getId());

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

            LocalDateTime createdAt = createdTimestamp != null ? createdTimestamp.toLocalDateTime()
                    : LocalDateTime.now();
            LocalDateTime updatedAt = updatedTimestamp != null ? updatedTimestamp.toLocalDateTime()
                    : LocalDateTime.now();

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

    @Override
    @Transactional
    public Map<String, Object> createQuestionBankGroup(String email, CreateGroupQuestionRequestDTO request) {
        User user = userRepository.findByEmail(email)
                .orElseThrow(() -> new RuntimeException("User not found with email: " + email));

        QuestionCategory category = null;
        if (request.getCategoryId() != null) {
            category = categoryRepository.findById(request.getCategoryId()).orElse(null);
        }

        SystemParameter skillParam = null;
        if (request.getSkillParamId() != null) {
            skillParam = systemParameterRepository.findById(request.getSkillParamId()).orElse(null);
        }

        SystemParameter difficulty = null;
        if (request.getDifficultyId() != null) {
            difficulty = systemParameterRepository.findById(request.getDifficultyId()).orElse(null);
        }

        // 1. Create QuestionGroup if passage text exists
        QuestionGroup group = null;
        if (request.getPassageText() != null && !request.getPassageText().trim().isEmpty()) {
            group = new QuestionGroup();
            group.setContextText(request.getPassageText());
            // group_type_param_id = 17 is the standard reading comprehension param (matches existing logic)
            SystemParameter groupType = systemParameterRepository.findById(17L).orElse(null);
            group.setGroupTypeParam(groupType);
            group = questionGroupRepository.save(group);
        }

        List<Long> questionIds = new ArrayList<>();

        // 2. Create Questions
        if (request.getSubQuestions() != null) {
            for (CreateSubQuestionDTO subQ : request.getSubQuestions()) {
                Question q = new Question();
                q.setCreatedBy(user);
                q.setCategory(category);
                q.setQuestionGroup(group);
                q.setQuestionText(subQ.getQuestionText());
                q.setExplanation(subQ.getExplanation());
                q.setStatus("PRIVATE");

                SystemParameter qDifficulty = difficulty;
                if (subQ.getDifficultyId() != null) {
                    qDifficulty = systemParameterRepository.findById(subQ.getDifficultyId()).orElse(difficulty);
                }
                q.setDifficulty(qDifficulty);

                SystemParameter qSkill = skillParam;
                if (subQ.getSkillParamId() != null) {
                    qSkill = systemParameterRepository.findById(subQ.getSkillParamId()).orElse(skillParam);
                }
                q.setSkillParam(qSkill);

                q = questionRepository.save(q);
                questionIds.add(q.getId());

                // 3. Create Options
                if (subQ.getOptions() != null) {
                    List<QuestionOption> options = new ArrayList<>();
                    for (CreateOptionDTO optDTO : subQ.getOptions()) {
                        QuestionOption opt = new QuestionOption();
                        opt.setQuestion(q);
                        opt.setOptionText(optDTO.getOptionText());
                        opt.setIsCorrect(optDTO.getIsCorrect() != null && optDTO.getIsCorrect());
                        options.add(opt);
                    }
                    q.setOptions(options);
                    questionRepository.save(q);
                }
            }
        }

        Map<String, Object> response = new HashMap<>();
        response.put("message", "Question created successfully");
        response.put("groupId", group != null ? group.getId() : null);
        response.put("questionIds", questionIds);
        return response;
    }

    @Override
    public void updateQuestionStatus(String email, Long questionId, String status) {
        User user = userRepository.findByEmail(email)
                .orElseThrow(() -> new RuntimeException("User not found"));

        Question question = questionRepository.findById(questionId)
                .orElseThrow(() -> new RuntimeException("Question not found"));

        if (!question.getCreatedBy().getId().equals(user.getId())) {
            throw new RuntimeException("You do not have permission to update this question");
        }

        question.setStatus(status);
        questionRepository.save(question);
    }
}
