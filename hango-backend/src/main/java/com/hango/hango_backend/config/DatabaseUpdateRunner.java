package com.hango.hango_backend.config;

import com.hango.hango_backend.entity.SystemParameter;
import com.hango.hango_backend.repository.SystemParameterRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.boot.CommandLineRunner;
import org.springframework.stereotype.Component;

import java.util.List;

@Component
@RequiredArgsConstructor
@Slf4j
public class DatabaseUpdateRunner implements CommandLineRunner {

    private final SystemParameterRepository systemParameterRepository;

    @Override
    public void run(String... args) throws Exception {
        log.info("STARTING DATABASE UPDATE RUNNER...");

        // Check if already populated
        boolean alreadyPopulated = systemParameterRepository.findAll().stream()
                .anyMatch(p -> "SKILL_TYPE".equals(p.getParamType()) && "Conversation/Short Sentences".equals(p.getParamValue()));
        if (alreadyPopulated) {
            log.info("Database already populated with new SKILL_TYPE and GROUP_TYPE. Skipping runner.");
            return;
        }

        // Set existing SKILL_TYPE and GROUP_TYPE to INACTIVE instead of deleting them to avoid FK violations
        List<SystemParameter> existingParams = systemParameterRepository.findAll().stream()
                .filter(p -> "SKILL_TYPE".equals(p.getParamType()) || "GROUP_TYPE".equals(p.getParamType()))
                .toList();
        for (SystemParameter p : existingParams) {
            p.setIsActive(false);
        }
        systemParameterRepository.saveAll(existingParams);
        log.info("Deactivated {} existing SKILL_TYPE and GROUP_TYPE parameters.", existingParams.size());

        // GroupType Options
        String[] groupTypes = {
                "Notice Completion",
                "Flyer Completion",
                "Passage Arrangement",
                "Information Gap Filling",
                "Reading Comprehension"
        };
        for (int i = 0; i < groupTypes.length; i++) {
            SystemParameter p = new SystemParameter();
            p.setParamType("GROUP_TYPE");
            p.setParamKey("GROUP_" + (i + 1));
            p.setParamValue(groupTypes[i]);
            p.setIsActive(true);
            systemParameterRepository.save(p);
        }
        log.info("Inserted GroupType Options.");

        // SkillType Options
        String[] skillTypes = {
                "Conversation/Short Sentences",
                "Synonym",
                "Antonym",
                "Pronunciation",
                "Grammar",
                "Sentence Meaning",
                "Sentence Combining",
                "Fill in Blank",
                "Reading Comprehension",
                "Arrangement"
        };
        for (int i = 0; i < skillTypes.length; i++) {
            SystemParameter p = new SystemParameter();
            p.setParamType("SKILL_TYPE");
            p.setParamKey("SKILL_" + (i + 1));
            p.setParamValue(skillTypes[i]);
            p.setIsActive(true);
            systemParameterRepository.save(p);
        }
        log.info("Inserted SkillType Options.");
        log.info("DATABASE UPDATE RUNNER COMPLETED SUCCESSFULLY.");
    }
}
