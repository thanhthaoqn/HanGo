package com.hango.hango_backend.service;

import com.hango.hango_backend.dto.QuestionDTO;
import com.hango.hango_backend.entity.User;
import com.hango.hango_backend.enums.QuestionUsageType;
import com.hango.hango_backend.repository.UserRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;
import com.hango.hango_backend.exception.ApiException;
import java.sql.Timestamp;
import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.HashMap;
import java.util.HashSet;
import java.util.Set;
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
            Long categoryId, Long difficultyId, Integer usageType, Long groupTypeId, Boolean isGroup) {
        boolean includeGroupQuery = isGroup == null || isGroup;
        boolean includeSingleQuery = isGroup == null || !isGroup;

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
        String groupTypeConditionGroup = (groupTypeId != null) ? "AND qg.group_type_param_id = ? " : "";
        String groupTypeConditionSingle = (groupTypeId != null) ? "AND 1=0 " : "";
        String usageTypeCondition = "";
        if (usageType != null) {
            if (usageType == 1) {
                usageTypeCondition = " AND (q.usage_type = '1' OR q.usage_type = 'QUIZ_ONLY' OR q.usage_type = '3' OR q.usage_type = 'BOTH') ";
            } else if (usageType == 2) {
                usageTypeCondition = " AND (q.usage_type = '2' OR q.usage_type = 'EXAM_ONLY' OR q.usage_type = '3' OR q.usage_type = 'BOTH') ";
            } else if (usageType == 3) {
                usageTypeCondition = " AND (q.usage_type = '3' OR q.usage_type = 'BOTH') ";
            }
        }

        StringBuilder sql = new StringBuilder();
        List<Object> params = new ArrayList<>();

        String searchConditionGroup = "";
        String searchConditionSingle = "";
        if (search != null && !search.trim().isEmpty()) {
            searchConditionGroup = "AND (qg.context_text LIKE ? OR qc.name LIKE ?) ";
            searchConditionSingle = "AND (q.question_text LIKE ? OR qc.name LIKE ?) ";
        }

        sql.append("SELECT * FROM ( ");

        if (includeGroupQuery) {
        // Group query
        sql.append("SELECT ")
                .append("  TRUE as is_group, ")
                .append("  qg.id as item_id, ")
                .append("  qg.context_text as question_text, ")
                .append("  MAX(qc.name) as category_name, ")
                .append("  NULL as skill_name, ")
                .append("  MAX(sp_group.param_value) as group_type_name, ")
                .append("  MAX(sp_diff.param_value) as difficulty_name, ")
                .append("  MAX(q.status) as status, ")
                .append("  MAX(u.full_name) as creator_name, ")
                .append("  MAX(q.created_at) as created_at, ")
                .append("  MAX(q.updated_at) as updated_at, ")
                .append("  MAX(q.usage_type) as usage_type, ")
                .append("  0 as options_count ")
                .append("FROM question_groups qg ")
                .append("JOIN questions q ON q.group_id = qg.id ")
                .append("LEFT JOIN question_categories qc ON q.category_id = qc.id ")
                .append("LEFT JOIN system_parameters sp_group ON qg.group_type_param_id = sp_group.id ")
                .append("LEFT JOIN system_parameters sp_diff ON q.difficulty_param_id = sp_diff.id ")
                .append("JOIN users u ON q.created_by = u.id ")
                .append("WHERE q.created_by = ? ")
                .append(statusConditionGroup)
                .append(searchConditionGroup)
                .append(skillCondition)
                .append(categoryCondition)
                .append(difficultyCondition)
                .append(groupTypeConditionGroup)
                .append(usageTypeCondition)
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
        if (groupTypeId != null)
            params.add(groupTypeId);
        }

        if (includeGroupQuery && includeSingleQuery) {
            sql.append(" UNION ALL ");
        }

        if (includeSingleQuery) {
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
                .append("  q.updated_at, ")
                .append("  q.usage_type, ")
                .append("  (SELECT COUNT(*) FROM question_options qo WHERE qo.question_id = q.id) as options_count ")
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
                .append(difficultyCondition)
                .append(groupTypeConditionSingle)
                .append(usageTypeCondition);

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
        }

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

            String usageStr = rs.getString("usage_type");
            Integer parsedUsageType = 1;
            if (usageStr != null) {
                if (usageStr.equals("BOTH")) {
                    parsedUsageType = 3;
                } else if (usageStr.equals("EXAM_ONLY")) {
                    parsedUsageType = 2;
                } else if (usageStr.equals("QUIZ_ONLY")) {
                    parsedUsageType = 1;
                } else {
                    try {
                        parsedUsageType = Integer.parseInt(usageStr);
                    } catch (NumberFormatException e) {
                        parsedUsageType = 1;
                    }
                }
            }

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
                    .usageType(parsedUsageType)
                    .usageTypeLabel(QuestionUsageType.fromValue(parsedUsageType).getDescription())
                    .optionsCount(rs.getInt("options_count"))
                    .build();
        }, params.toArray());
    }

    @Override
    @Transactional
    public Map<String, Object> createQuestionBankGroup(String email, CreateGroupQuestionRequestDTO request) {
        validateSubQuestions(request.getSubQuestions());

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

        // 1. Reuse the existing QuestionGroup (if the request references one we own) or create a new one
        QuestionGroup group = null;
        if (request.getPassageText() != null && !request.getPassageText().trim().isEmpty()) {
            if (request.getId() != null) {
                group = questionGroupRepository.findById(request.getId()).orElse(null);
                if (group != null) {
                    List<Question> groupQuestions = questionRepository.findByQuestionGroup(group);
                    boolean ownedByUser = groupQuestions.isEmpty()
                            || groupQuestions.get(0).getCreatedBy().getId().equals(user.getId());
                    if (!ownedByUser) {
                        group = null;
                    }
                }
            }
            if (group == null) {
                group = new QuestionGroup();
            }
            group.setContextText(request.getPassageText());
            group.setGroupTypeParam(skillParam);
            group = questionGroupRepository.save(group);
        }

        List<Long> questionIds = new ArrayList<>();

        // 2. Create or update questions. Reusing the id (when it belongs to this user) keeps the
        // question's identity stable so it doesn't get duplicated in the bank or unlinked from
        // other exams that reference it.
        if (request.getSubQuestions() != null) {
            for (CreateSubQuestionDTO subQ : request.getSubQuestions()) {
                Question q = null;
                if (subQ.getId() != null) {
                    q = questionRepository.findById(subQ.getId())
                            .filter(existing -> existing.getCreatedBy().getId().equals(user.getId()))
                            .orElse(null);
                }
                if (q == null) {
                    q = new Question();
                    q.setCreatedBy(user);
                }
                q.setCategory(category);
                q.setQuestionGroup(group);
                q.setQuestionText(subQ.getQuestionText());
                q.setExplanation(subQ.getExplanation());
                q.setStatus(request.getStatus() != null ? request.getStatus() : "PRIVATE");
                q.setUsageType(request.getUsageType() != null ? request.getUsageType() : 1);

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

                // 3. Replace options. Past exam attempts store a frozen snapshot of the answer
                // (not a live foreign key to question_options.id), so it's safe to swap them.
                if (subQ.getOptions() != null) {
                    if (q.getOptions() == null) {
                        q.setOptions(new ArrayList<>());
                    } else {
                        q.getOptions().clear();
                    }
                    for (CreateOptionDTO optDTO : subQ.getOptions()) {
                        QuestionOption opt = new QuestionOption();
                        opt.setQuestion(q);
                        opt.setOptionText(optDTO.getOptionText());
                        opt.setIsCorrect(optDTO.getIsCorrect() != null && optDTO.getIsCorrect());
                        q.getOptions().add(opt);
                    }
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
                dto.setUsageType(questions.get(0).getUsageType() != null ? questions.get(0).getUsageType() : 1);
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
            dto.setUsageType(q.getUsageType() != null ? q.getUsageType() : 1);

            List<CreateSubQuestionDTO> subDTOs = new ArrayList<>();
            subDTOs.add(mapToSubQuestionDTO(q));
            dto.setSubQuestions(subDTOs);

            return dto;
        }
    }

    private void validateSubQuestions(List<CreateSubQuestionDTO> subQuestions) {
        if (subQuestions == null || subQuestions.isEmpty()) {
            throw new ApiException("At least one question is required.", HttpStatus.BAD_REQUEST);
        }
        for (int i = 0; i < subQuestions.size(); i++) {
            List<CreateOptionDTO> options = subQuestions.get(i).getOptions();
            boolean hasCorrectOption = options != null
                    && options.stream().anyMatch(opt -> Boolean.TRUE.equals(opt.getIsCorrect()));
            if (!hasCorrectOption) {
                throw new ApiException(
                        "Question " + (i + 1) + " must have at least one correct option.",
                        HttpStatus.BAD_REQUEST);
            }
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
        validateSubQuestions(request.getSubQuestions());

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
        List<Question> existingQuestions;
        if (isGroup) {
            group = questionGroupRepository.findById(id)
                    .orElseThrow(() -> new RuntimeException("Question Group not found"));
            group.setContextText(request.getPassageText());

            SystemParameter groupType = skillParam;
            group.setGroupTypeParam(groupType);

            questionGroupRepository.save(group);

            existingQuestions = questionRepository.findByQuestionGroup(group);
            if (!existingQuestions.isEmpty() && !existingQuestions.get(0).getCreatedBy().getId().equals(user.getId())) {
                throw new RuntimeException("No permission");
            }
        } else {
            Question oldQ = questionRepository.findById(id)
                    .orElseThrow(() -> new RuntimeException("Question not found"));
            if (!oldQ.getCreatedBy().getId().equals(user.getId())) {
                throw new RuntimeException("No permission");
            }
            existingQuestions = new ArrayList<>();
            existingQuestions.add(oldQ);
        }

        // Match sub-questions back to their existing rows by id so unchanged questions keep their
        // identity (avoids duplicating them in the bank and unlinking them from other exams).
        Map<Long, Question> existingById = new HashMap<>();
        for (Question existing : existingQuestions) {
            existingById.put(existing.getId(), existing);
        }
        Set<Long> keptIds = new HashSet<>();

        if (request.getSubQuestions() != null) {
            for (CreateSubQuestionDTO subQ : request.getSubQuestions()) {
                Question q = subQ.getId() != null ? existingById.get(subQ.getId()) : null;
                if (q == null) {
                    q = new Question();
                    q.setCreatedBy(user);
                } else {
                    keptIds.add(q.getId());
                }
                q.setCategory(category);
                q.setQuestionGroup(group);
                q.setQuestionText(subQ.getQuestionText());
                q.setExplanation(subQ.getExplanation());
                q.setStatus(request.getStatus() != null ? request.getStatus() : "PRIVATE");
                q.setUsageType(request.getUsageType() != null ? request.getUsageType() : 1);

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
                    if (q.getOptions() == null) {
                        q.setOptions(new ArrayList<>());
                    } else {
                        q.getOptions().clear();
                    }
                    for (CreateOptionDTO optDTO : subQ.getOptions()) {
                        QuestionOption opt = new QuestionOption();
                        opt.setQuestion(q);
                        opt.setOptionText(optDTO.getOptionText());
                        opt.setIsCorrect(optDTO.getIsCorrect() != null && optDTO.getIsCorrect());
                        q.getOptions().add(opt);
                    }
                    questionRepository.save(q);
                }
            }
        }

        // Delete only the questions that were actually removed from this group/edit.
        List<Question> removed = new ArrayList<>();
        for (Question existing : existingQuestions) {
            if (!keptIds.contains(existing.getId())) {
                removed.add(existing);
            }
        }
        if (!removed.isEmpty()) {
            questionRepository.deleteAll(removed);
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
