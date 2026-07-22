package com.hango.hango_backend.config;

import com.hango.hango_backend.entity.SystemParameter;
import com.hango.hango_backend.repository.SystemParameterRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.boot.CommandLineRunner;
import org.springframework.stereotype.Component;

import java.util.LinkedHashMap;
import java.util.Map;

@Component
@RequiredArgsConstructor
@Slf4j
public class SystemParameterDataInitializer implements CommandLineRunner {

    private final SystemParameterRepository systemParameterRepository;

    @Override
    public void run(String... args) {
        log.info("Initializing Course Category System Parameters...");

        Map<String, String> categories = new LinkedHashMap<>();
        categories.put("CONVERSATION_SHORT_SENTENCES", "Conversation/Short Sentences");
        categories.put("SYNONYM", "Synonym");
        categories.put("ANTONYM", "Antonym");
        categories.put("PRONUNCIATION", "Pronunciation");
        categories.put("GRAMMAR", "Grammar");
        categories.put("SENTENCE_MEANING", "Sentence Meaning");
        categories.put("SENTENCE_COMBINING", "Sentence Combining");
        categories.put("FILL_IN_BLANK", "Fill in Blank");
        categories.put("READING_COMPREHENSION", "Reading Comprehension");
        categories.put("ARRANGEMENT", "Arrangement");

        for (Map.Entry<String, String> entry : categories.entrySet()) {
            String key = entry.getKey();
            String value = entry.getValue();

            boolean exists = systemParameterRepository
                    .findByParamTypeAndParamKey("COURSE_CATEGORY", key)
                    .isPresent();

            if (!exists) {
                SystemParameter param = SystemParameter.builder()
                        .paramType("COURSE_CATEGORY")
                        .paramKey(key)
                        .paramValue(value)
                        .isActive(true)
                        .build();
                systemParameterRepository.save(param);
                log.info("Created SystemParameter: COURSE_CATEGORY -> {} ({})", key, value);
            }
        }
    }
}
