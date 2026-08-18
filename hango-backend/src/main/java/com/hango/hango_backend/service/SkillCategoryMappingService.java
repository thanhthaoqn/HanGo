package com.hango.hango_backend.service;

import com.hango.hango_backend.entity.SystemParameter;
import com.hango.hango_backend.repository.SystemParameterRepository;
import jakarta.annotation.PostConstruct;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;

import java.util.Collections;
import java.util.List;
import java.util.Map;
import java.util.stream.Collectors;

/**
 * Service to manage the deterministic mapping between Skill Types (26 types)
 * and Course Categories (6 types).
 */
@Service
@RequiredArgsConstructor
@Slf4j
public class SkillCategoryMappingService {

    private final SystemParameterRepository systemParameterRepository;
    
    // In-memory cache for fast lookup: Map<SkillKey, CategoryKey>
    private Map<String, String> skillToCategoryMap = Collections.emptyMap();

    @PostConstruct
    public void init() {
        refreshMapping();
    }

    /**
     * Refreshes the mapping cache from the database.
     */
    public void refreshMapping() {
        try {
            List<SystemParameter> params = systemParameterRepository.findByParamTypeAndIsActiveTrue("SKILL_CATEGORY_MAP");
            skillToCategoryMap = params.stream()
                    .collect(Collectors.toMap(
                            SystemParameter::getParamKey,
                            SystemParameter::getParamValue,
                            (existing, replacement) -> existing // Keep first in case of duplicates
                    ));
            log.info("Loaded {} Skill-to-Category mappings.", skillToCategoryMap.size());
        } catch (Exception e) {
            log.warn("Could not load SKILL_CATEGORY_MAP. Tables might not be initialized yet. Error: {}", e.getMessage());
        }
    }

    /**
     * Gets the full mapping.
     */
    public Map<String, String> getSkillToCategoryMap() {
        return Collections.unmodifiableMap(skillToCategoryMap);
    }

    /**
     * Gets the corresponding Course Category for a given Skill Type.
     * @param skillKey The SKILL_TYPE parameter key (e.g., "PHRASAL_VERB")
     * @return The COURSE_CATEGORY parameter key (e.g., "VOCABULARY"), or null if not mapped.
     */
    public String getCategoryForSkill(String skillKey) {
        if (skillKey == null) return null;
        return skillToCategoryMap.get(skillKey.trim().toUpperCase());
    }
    
    /**
     * Gets a list of skills mapped to a specific category.
     * @param categoryKey The COURSE_CATEGORY parameter key (e.g., "GRAMMAR")
     * @return List of SKILL_TYPE keys.
     */
    public List<String> getSkillsForCategory(String categoryKey) {
        if (categoryKey == null) return Collections.emptyList();
        String upperCategory = categoryKey.trim().toUpperCase();
        return skillToCategoryMap.entrySet().stream()
                .filter(entry -> upperCategory.equals(entry.getValue()))
                .map(Map.Entry::getKey)
                .toList();
    }
}
