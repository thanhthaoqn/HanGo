package com.hango.hango_backend.config;

import com.hango.hango_backend.entity.SystemParameter;
import com.hango.hango_backend.repository.SystemParameterRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.boot.CommandLineRunner;
import org.springframework.stereotype.Component;

import org.springframework.jdbc.core.JdbcTemplate;
import java.util.LinkedHashMap;
import java.util.Map;

@Component
@RequiredArgsConstructor
@Slf4j
public class SystemParameterDataInitializer implements CommandLineRunner {

    private final SystemParameterRepository systemParameterRepository;
    private final JdbcTemplate jdbcTemplate;

    @Override
    public void run(String... args) {
        log.info("Initializing New Skill/Category System Parameters...");

        // Xóa các loại cũ (có thể đang dùng)
        jdbcTemplate.execute("SET FOREIGN_KEY_CHECKS = 0");
        jdbcTemplate.update("DELETE FROM system_parameters WHERE param_type IN ('COURSE_CATEGORY', 'SKILL_TYPE', 'SKILL')");
        jdbcTemplate.execute("SET FOREIGN_KEY_CHECKS = 1");

        Map<String, String> newSkills = new LinkedHashMap<>();
        newSkills.put("PHONETICS", "Phonetics");
        newSkills.put("WORD_ORDER", "Word order");
        newSkills.put("REDUCED_RELATIVE_CLAUSE", "Reduced relative clause");
        newSkills.put("PREPOSITION", "Preposition");
        newSkills.put("COLLOCATION", "Collocation");
        newSkills.put("TO_INFINITIVE", "To-infinitive");
        newSkills.put("QUANTIFIER", "Quantifier");
        newSkills.put("PHRASAL_VERB", "Phrasal verb");
        newSkills.put("PREPOSITIONAL_PHRASE", "Prepositional phrase");
        newSkills.put("VOCABULARY", "Vocabulary");
        newSkills.put("CONVERSATION_ORDERING", "Conversation ordering");
        newSkills.put("LETTER_ORDERING", "Letter ordering");
        newSkills.put("PARAGRAPH_ORDERING", "Paragraph ordering");
        newSkills.put("PASSIVE_VOICE", "Passive voice");
        newSkills.put("RELATIVE_CLAUSE", "Relative clause");
        newSkills.put("CONTEXTUAL_MEANING", "Contextual meaning");
        newSkills.put("FACTUAL_DETAIL_QUESTION", "Factual / Detail question");
        newSkills.put("SYNONYM_IN_CONTEXT", "Synonym in context");
        newSkills.put("ANTONYM_IN_CONTEXT", "Antonym in context");
        newSkills.put("REFERENCE_QUESTION", "Reference question");
        newSkills.put("PARAPHRASING_QUESTION", "Paraphrasing question");
        newSkills.put("PARAGRAPH_SPECIFIC_INFORMATION_QUESTION", "Paragraph-specific information question");
        newSkills.put("MAIN_IDEA_CENTRAL_THEME_QUESTION", "Main idea / Central theme question");
        newSkills.put("TRUE_NOT_TRUE_QUESTION", "TRUE / NOT TRUE question");
        newSkills.put("INFERENCE_QUESTION", "Inference question");

        String[] types = {"COURSE_CATEGORY", "SKILL_TYPE", "SKILL"};

        for (String type : types) {
            for (Map.Entry<String, String> entry : newSkills.entrySet()) {
                String key = entry.getKey();
                String value = entry.getValue();

                SystemParameter param = SystemParameter.builder()
                        .paramType(type)
                        .paramKey(key)
                        .paramValue(value)
                        .isActive(true)
                        .build();
                systemParameterRepository.save(param);
            }
        }
        
        // --- Bắt đầu cập nhật GROUP_TYPE ---
        jdbcTemplate.execute("SET FOREIGN_KEY_CHECKS = 0");
        jdbcTemplate.update("DELETE FROM system_parameters WHERE param_type = 'GROUP_TYPE'");
        jdbcTemplate.execute("SET FOREIGN_KEY_CHECKS = 1");

        Map<String, String> newGroupTypes = new LinkedHashMap<>();
        newGroupTypes.put("NOTICE_COMPLETION", "Read and Fill in a Notice");
        newGroupTypes.put("LEAFLET_ADVERTISEMENT", "Read and Fill in a Leaflet/Advertisement");
        newGroupTypes.put("PARAGRAPH_TEXT_REORDERING", "Paragraph/Text Reordering");
        newGroupTypes.put("GUIDED_CLOZE_TEST", "Guided Cloze Test");
        newGroupTypes.put("READING_COMPREHENSION_8_QUESTIONS", "Reading Comprehension - 8 questions");
        newGroupTypes.put("READING_COMPREHENSION_10_QUESTIONS", "Reading Comprehension - 10 questions");

        for (Map.Entry<String, String> entry : newGroupTypes.entrySet()) {
            SystemParameter param = SystemParameter.builder()
                    .paramType("GROUP_TYPE")
                    .paramKey(entry.getKey())
                    .paramValue(entry.getValue())
                    .isActive(true)
                    .build();
            systemParameterRepository.save(param);
        }
        
        log.info("Successfully recreated COURSE_CATEGORY, SKILL_TYPE, SKILL, and GROUP_TYPE in system_parameters.");
    }
}
