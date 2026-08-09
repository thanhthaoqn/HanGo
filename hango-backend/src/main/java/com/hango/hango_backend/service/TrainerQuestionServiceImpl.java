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
    public List<QuestionDTO> getTrainerQuestions(String email, String type, String search, String sortBy, Long skillId,
            Long categoryId, Long difficultyId) {
        User user = userRepository.findByEmail(email)
                .orElseThrow(() -> new RuntimeException("User not found with email: " + email));

        // type is now treated as status filter: ALL, PUBLIC, PRIVATE
        String statusFilter = (type != null && !type.equalsIgnoreCase("QUIZ") && !type.equalsIgnoreCase("EXAM")
                && !type.equalsIgnoreCase("ALL"))
                        ? type
                        : null;
        // If type is ALL or old values QUIZ/EXAM, show all statuses
        String statusConditionGroup = (statusFilter != null) ? "AND q.status = ? " : "";
        String statusConditionSingle = (statusFilter != null) ? "AND q.status = ? " : "";

        String skillCondition = (skillId != null) ? "AND q.skill_param_id = ? " : "";
        String categoryCondition = (categoryId != null) ? "AND q.category_id = ? " : "";
        String difficultyCondition = (difficultyId != null) ? "AND q.difficulty_param_id = ? " : "";

        StringBuilder sql = new StringBuilder();
        List<Object> params = new ArrayList<>();

        String searchConditionGroup = "";
        String searchConditionSingle = "";
        if (search != null && !search.trim().isEmpty()) {
            searchConditionGroup = "AND (qg.context_text LIKE ? OR qc.name LIKE ?) ";
            searchConditionSingle = "AND (q.question_text LIKE ? OR qc.name LIKE ?) ";
        }

        sql.append("SELECT * FROM ( ");

        // Group query
        sql.append("SELECT ")
                .append("  TRUE as is_group, ")
                .append("  qg.id as item_id, ")
                .append("  qg.context_text as question_text, ")
                .append("  MAX(qc.name) as category_name, ")
                .append("  NULL as skill_name, ")
                .append("  MAX(sp_group.param_value) as group_type_name, ")
                .append("  NULL as difficulty_name, ")
                .append("  MAX(q.status) as status, ")
                .append("  MAX(u.full_name) as creator_name, ")
                .append("  MAX(q.created_at) as created_at, ")
                .append("  MAX(q.updated_at) as updated_at ")
                .append("FROM question_groups qg ")
                .append("JOIN questions q ON q.group_id = qg.id ")
                .append("LEFT JOIN question_categories qc ON q.category_id = qc.id ")
                .append("LEFT JOIN system_parameters sp_group ON qg.group_type_param_id = sp_group.id ")
                .append("JOIN users u ON q.created_by = u.id ")
                .append("WHERE q.created_by = ? ")
                .append(statusConditionGroup)
                .append(searchConditionGroup)
                .append(skillCondition)
                .append(categoryCondition)
                .append(difficultyCondition)
                .append("GROUP BY qg.id, qg.context_text ");

        params.add(user.getId());
        if (statusFilter != null)
            params.add(statusFilter);
        if (search != null && !search.trim().isEmpty()) {
            String searchPattern = "%" + search.trim() + "%";
            params.add(searchPattern);
            params.add(searchPattern);
        }
        if (skillId != null)
            params.add(skillId);
        if (categoryId != null)
            params.add(categoryId);
        if (difficultyId != null)
            params.add(difficultyId);

        sql.append(" UNION ALL ");

        // Single query
        sql.append("SELECT ")
                .append("  FALSE as is_group, ")
                .append("  q.id as item_id, ")
                .append("  q.question_text as question_text, ")
                .append("  qc.name as category_name, ")
                .append("  sp_skill.param_value as skill_name, ")
                .append("  NULL as group_type_name, ")
                .append("  sp.param_value as difficulty_name, ")
                .append("  q.status, ")
                .append("  u.full_name as creator_name, ")
                .append("  q.created_at, ")
                .append("  q.updated_at ")
                .append("FROM questions q ")
                .append("LEFT JOIN question_categories qc ON q.category_id = qc.id ")
                .append("LEFT JOIN system_parameters sp_skill ON q.skill_param_id = sp_skill.id ")
                .append("LEFT JOIN system_parameters sp ON q.difficulty_param_id = sp.id ")
                .append("JOIN users u ON q.created_by = u.id ")
                .append("WHERE q.created_by = ? AND q.group_id IS NULL ")
                .append(statusConditionSingle)
                .append(searchConditionSingle)
                .append(skillCondition)
                .append(categoryCondition)
                .append(difficultyCondition);

        params.add(user.getId());
        if (statusFilter != null)
            params.add(statusFilter);
        if (search != null && !search.trim().isEmpty()) {
            String searchPattern = "%" + search.trim() + "%";
            params.add(searchPattern);
            params.add(searchPattern);
        }
        if (skillId != null)
            params.add(skillId);
        if (categoryId != null)
            params.add(categoryId);
        if (difficultyId != null)
            params.add(difficultyId);

        sql.append(") AS combined_results ");

        if ("NEWEST".equalsIgnoreCase(sortBy)) {
            sql.append("ORDER BY updated_at DESC");
        } else if ("OLDEST".equalsIgnoreCase(sortBy)) {
            sql.append("ORDER BY updated_at ASC");
        } else {
            sql.append("ORDER BY updated_at DESC");
        }

        return jdbcTemplate.query(sql.toString(), (rs, rowNum) -> {
            Timestamp createdTimestamp = rs.getTimestamp("created_at");
            Timestamp updatedTimestamp = rs.getTimestamp("updated_at");

            LocalDateTime createdAt = createdTimestamp != null ? createdTimestamp.toLocalDateTime()
                    : LocalDateTime.now();
            LocalDateTime updatedAt = updatedTimestamp != null ? updatedTimestamp.toLocalDateTime()
                    : LocalDateTime.now();

            return QuestionDTO.builder()
                    .id(rs.getLong("item_id"))
                    .isGroup(rs.getBoolean("is_group"))
                    .questionText(rs.getString("question_text"))
                    .categoryName(rs.getString("category_name"))
                    .skillName(rs.getString("skill_name"))
                    .groupTypeName(rs.getString("group_type_name"))
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
        // categoryId from frontend is actually the Group Type (SystemParameter) when
        // it's a group question.
        // So we don't look it up in QuestionCategory.

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

            SystemParameter groupType = skillParam;
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
                q.setStatus(request.getStatus() != null ? request.getStatus() : "PRIVATE");

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
    public CreateGroupQuestionRequestDTO getQuestionDetail(String email, Long id, boolean isGroup) {
        User user = userRepository.findByEmail(email)
                .orElseThrow(() -> new RuntimeException("User not found"));

        if (isGroup) {
            QuestionGroup group = questionGroupRepository.findById(id)
                    .orElseThrow(() -> new RuntimeException("Question Group not found"));

            List<Question> questions = questionRepository.findByQuestionGroup(group);
            if (!questions.isEmpty() && !questions.get(0).getCreatedBy().getId().equals(user.getId())) {
                throw new RuntimeException("You do not have permission to view this group");
            }

            CreateGroupQuestionRequestDTO dto = new CreateGroupQuestionRequestDTO();
            dto.setId(group.getId());
            dto.setPassageText(group.getContextText());

            if (!questions.isEmpty()) {
                // If it's a group, the frontend expects categoryId to be the group type
                // SystemParameter ID
                dto.setCategoryId(group.getGroupTypeParam() != null ? group.getGroupTypeParam().getId() : null);
                dto.setStatus(questions.get(0).getStatus());
            }

            List<CreateSubQuestionDTO> subDTOs = new ArrayList<>();
            for (Question q : questions) {
                subDTOs.add(mapToSubQuestionDTO(q));
            }
            dto.setSubQuestions(subDTOs);
            return dto;
        } else {
            Question q = questionRepository.findById(id)
                    .orElseThrow(() -> new RuntimeException("Question not found"));

            if (!q.getCreatedBy().getId().equals(user.getId())) {
                throw new RuntimeException("You do not have permission to view this question");
            }

            CreateGroupQuestionRequestDTO dto = new CreateGroupQuestionRequestDTO();
            dto.setCategoryId(q.getCategory() != null ? q.getCategory().getId() : null);
            dto.setDifficultyId(q.getDifficulty() != null ? q.getDifficulty().getId() : null);
            dto.setSkillParamId(q.getSkillParam() != null ? q.getSkillParam().getId() : null);
            dto.setStatus(q.getStatus());

            List<CreateSubQuestionDTO> subDTOs = new ArrayList<>();
            subDTOs.add(mapToSubQuestionDTO(q));
            dto.setSubQuestions(subDTOs);

            return dto;
        }
    }

    private CreateSubQuestionDTO mapToSubQuestionDTO(Question q) {
        CreateSubQuestionDTO sub = new CreateSubQuestionDTO();
        sub.setId(q.getId());
        sub.setQuestionText(q.getQuestionText());
        sub.setExplanation(q.getExplanation());
        sub.setSkillParamId(q.getSkillParam() != null ? q.getSkillParam().getId() : null);
        sub.setDifficultyId(q.getDifficulty() != null ? q.getDifficulty().getId() : null);

        List<CreateOptionDTO> optDTOs = new ArrayList<>();
        if (q.getOptions() != null) {
            for (QuestionOption opt : q.getOptions()) {
                CreateOptionDTO optDTO = new CreateOptionDTO();
                optDTO.setId(opt.getId());
                optDTO.setOptionText(opt.getOptionText());
                optDTO.setIsCorrect(opt.getIsCorrect());
                optDTOs.add(optDTO);
            }
        }
        sub.setOptions(optDTOs);
        return sub;
    }

    @Override
    @Transactional
    public void updateQuestionBankGroup(String email, Long id, boolean isGroup, CreateGroupQuestionRequestDTO request) {
        User user = userRepository.findByEmail(email)
                .orElseThrow(() -> new RuntimeException("User not found with email: " + email));

        QuestionCategory category = null;
        if (!isGroup && request.getCategoryId() != null) {
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

        QuestionGroup group = null;
        if (isGroup) {
            group = questionGroupRepository.findById(id)
                    .orElseThrow(() -> new RuntimeException("Question Group not found"));
            group.setContextText(request.getPassageText());

            SystemParameter groupType = skillParam;
            group.setGroupTypeParam(groupType);

            questionGroupRepository.save(group);

            // For simplicity, we just delete old questions and create new ones
            List<Question> oldQuestions = questionRepository.findByQuestionGroup(group);
            if (!oldQuestions.isEmpty() && !oldQuestions.get(0).getCreatedBy().getId().equals(user.getId())) {
                throw new RuntimeException("No permission");
            }
            questionRepository.deleteAll(oldQuestions);
        } else {
            Question oldQ = questionRepository.findById(id)
                    .orElseThrow(() -> new RuntimeException("Question not found"));
            if (!oldQ.getCreatedBy().getId().equals(user.getId())) {
                throw new RuntimeException("No permission");
            }
            questionRepository.delete(oldQ);
        }

        // Recreate questions
        if (request.getSubQuestions() != null) {
            for (CreateSubQuestionDTO subQ : request.getSubQuestions()) {
                Question q = new Question();
                q.setCreatedBy(user);
                q.setCategory(category);
                q.setQuestionGroup(group);
                q.setQuestionText(subQ.getQuestionText());
                q.setExplanation(subQ.getExplanation());
                q.setStatus(request.getStatus() != null ? request.getStatus() : "PRIVATE");

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
    }

    @Override
    @Transactional
    public void updateQuestionStatus(String email, Long questionId, String status, boolean isGroup) {
        User user = userRepository.findByEmail(email)
                .orElseThrow(() -> new RuntimeException("User not found"));

        if (isGroup) {
            QuestionGroup group = questionGroupRepository.findById(questionId)
                    .orElseThrow(() -> new RuntimeException("Group not found"));
            List<Question> questions = questionRepository.findByQuestionGroup(group);
            for (Question question : questions) {
                if (!question.getCreatedBy().getId().equals(user.getId())) {
                    throw new RuntimeException("You do not have permission to update this question");
                }
                question.setStatus(status);
                questionRepository.save(question);
            }
        } else {
            Question question = questionRepository.findById(questionId)
                    .orElseThrow(() -> new RuntimeException("Question not found"));

            if (!question.getCreatedBy().getId().equals(user.getId())) {
                throw new RuntimeException("You do not have permission to update this question");
            }

            question.setStatus(status);
            questionRepository.save(question);
        }
    }

}
