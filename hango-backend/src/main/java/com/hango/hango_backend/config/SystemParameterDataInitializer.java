package com.hango.hango_backend.config;

import com.hango.hango_backend.entity.SystemParameter;
import com.hango.hango_backend.repository.SystemParameterRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.boot.CommandLineRunner;
import org.springframework.core.annotation.Order;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Component;

import java.util.LinkedHashMap;
import java.util.Map;
import java.util.Optional;

@Component
@RequiredArgsConstructor
@Slf4j
@Order(1) // Run early
public class SystemParameterDataInitializer implements CommandLineRunner {

    private final SystemParameterRepository systemParameterRepository;
    private final JdbcTemplate jdbcTemplate;

    @Override
    public void run(String... args) {
        log.info("Ensuring Skill/Category/GroupType System Parameters exist...");

        // --- STEP 0: Clean up orphaned FK references left by previous destructive runs ---
        try {
            jdbcTemplate.update(
                "DELETE FROM course_categories WHERE category_param_id NOT IN (SELECT id FROM system_parameters)");
            jdbcTemplate.update(
                "UPDATE courses SET category_param_id = NULL WHERE category_param_id IS NOT NULL AND category_param_id NOT IN (SELECT id FROM system_parameters)");
            jdbcTemplate.update(
                "UPDATE courses SET difficulty_param_id = NULL WHERE difficulty_param_id IS NOT NULL AND difficulty_param_id NOT IN (SELECT id FROM system_parameters)");
            jdbcTemplate.update(
                "UPDATE questions SET skill_param_id = NULL WHERE skill_param_id IS NOT NULL AND skill_param_id NOT IN (SELECT id FROM system_parameters)");
            jdbcTemplate.update(
                "UPDATE questions SET difficulty_param_id = NULL WHERE difficulty_param_id IS NOT NULL AND difficulty_param_id NOT IN (SELECT id FROM system_parameters)");
            jdbcTemplate.update(
                "UPDATE question_groups SET group_type_param_id = NULL WHERE group_type_param_id IS NOT NULL AND group_type_param_id NOT IN (SELECT id FROM system_parameters)");
            
            // First unlink courses that are using the obsolete categories
            jdbcTemplate.update(
                "UPDATE courses SET category_param_id = NULL WHERE category_param_id IN " +
                "(SELECT id FROM system_parameters WHERE param_type = 'COURSE_CATEGORY' AND param_key NOT IN " +
                "('READING_COMPREHENSION', 'VOCABULARY', 'GRAMMAR', 'WRITING_STRUCTURE', 'PRONUNCIATION', 'TEST_PREPARATION'))");

            // Cleanup obsolete COURSE_CATEGORY that are actually skills (from previous structure)
            jdbcTemplate.update(
                "DELETE FROM system_parameters WHERE param_type = 'COURSE_CATEGORY' AND param_key NOT IN " +
                "('READING_COMPREHENSION', 'VOCABULARY', 'GRAMMAR', 'WRITING_STRUCTURE', 'PRONUNCIATION', 'TEST_PREPARATION')");
                
            log.info("Orphaned FK references cleaned up.");
        } catch (Exception e) {
            log.warn("Could not cleanup orphaned references (tables may not exist yet): {}", e.getMessage());
        }

        // --- STEP 1: Ensure 25 Skill Types exist ---
        Map<String, String> skills = new LinkedHashMap<>();
        skills.put("PHONETICS", "Phonetics");
        skills.put("WORD_ORDER", "Word order");
        skills.put("REDUCED_RELATIVE_CLAUSE", "Reduced relative clause");
        skills.put("PREPOSITION", "Preposition");
        skills.put("COLLOCATION", "Collocation");
        skills.put("TO_INFINITIVE", "To-infinitive");
        skills.put("QUANTIFIER", "Quantifier");
        skills.put("PHRASAL_VERB", "Phrasal verb");
        skills.put("PREPOSITIONAL_PHRASE", "Prepositional phrase");
        skills.put("VOCABULARY", "Vocabulary");
        skills.put("CONVERSATION_ORDERING", "Conversation ordering");
        skills.put("LETTER_ORDERING", "Letter ordering");
        skills.put("PARAGRAPH_ORDERING", "Paragraph ordering");
        skills.put("PASSIVE_VOICE", "Passive voice");
        skills.put("RELATIVE_CLAUSE", "Relative clause");
        skills.put("CONTEXTUAL_MEANING", "Contextual meaning");
        skills.put("FACTUAL_DETAIL_QUESTION", "Factual / Detail question");
        skills.put("SYNONYM_IN_CONTEXT", "Synonym in context");
        skills.put("ANTONYM_IN_CONTEXT", "Antonym in context");
        skills.put("REFERENCE_QUESTION", "Reference question");
        skills.put("PARAPHRASING_QUESTION", "Paraphrasing question");
        skills.put("PARAGRAPH_SPECIFIC_INFORMATION_QUESTION", "Paragraph-specific information question");
        skills.put("MAIN_IDEA_CENTRAL_THEME_QUESTION", "Main idea / Central theme question");
        skills.put("TRUE_NOT_TRUE_QUESTION", "TRUE / NOT TRUE question");
        skills.put("INFERENCE_QUESTION", "Inference question");

        // --- STEP 1: Ensure 25 Skill Types exist for SKILL_TYPE and SKILL ---
        String[] skillParamTypes = {"SKILL_TYPE", "SKILL"};
        for (String paramType : skillParamTypes) {
            for (Map.Entry<String, String> entry : skills.entrySet()) {
                ensureExists(paramType, entry.getKey(), entry.getValue());
            }
        }

        // --- STEP 1.5: Ensure 6 Macro COURSE_CATEGORIES exist ---
        Map<String, String> courseCategories = new LinkedHashMap<>();
        courseCategories.put("READING_COMPREHENSION", "Reading Comprehension");
        courseCategories.put("VOCABULARY", "Vocabulary");
        courseCategories.put("GRAMMAR", "Grammar");
        courseCategories.put("WRITING_STRUCTURE", "Writing & Structure");
        courseCategories.put("PRONUNCIATION", "Pronunciation");
        courseCategories.put("TEST_PREPARATION", "Test Preparation");
        
        for (Map.Entry<String, String> entry : courseCategories.entrySet()) {
            ensureExists("COURSE_CATEGORY", entry.getKey(), entry.getValue());
        }

        // --- STEP 2: Ensure 6 Group Types exist ---
        Map<String, String> groupTypes = new LinkedHashMap<>();
        groupTypes.put("NOTICE_COMPLETION", "Read and Fill in a Notice");
        groupTypes.put("LEAFLET_ADVERTISEMENT", "Read and Fill in a Leaflet/Advertisement");
        groupTypes.put("PARAGRAPH_TEXT_REORDERING", "Paragraph/Text Reordering");
        groupTypes.put("GUIDED_CLOZE_TEST", "Guided Cloze Test");
        groupTypes.put("READING_COMPREHENSION_8_QUESTIONS", "Reading Comprehension - 8 questions");
        groupTypes.put("READING_COMPREHENSION_10_QUESTIONS", "Reading Comprehension - 10 questions");

        for (Map.Entry<String, String> entry : groupTypes.entrySet()) {
            ensureExists("GROUP_TYPE", entry.getKey(), entry.getValue());
        }

        log.info("System parameters initialization complete.");
    }

    private void ensureExists(String paramType, String paramKey, String paramValue) {
        Optional<SystemParameter> existing = systemParameterRepository.findByParamTypeAndParamKey(paramType, paramKey);
        if (existing.isEmpty()) {
            SystemParameter param = SystemParameter.builder()
                    .paramType(paramType)
                    .paramKey(paramKey)
                    .paramValue(paramValue)
                    .isActive(true)
                    .build();
            systemParameterRepository.save(param);
            log.info("Created SystemParameter: {} -> {} ({})", paramType, paramKey, paramValue);
        }
    }
}
