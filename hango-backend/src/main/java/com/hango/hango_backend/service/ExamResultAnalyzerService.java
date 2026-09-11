package com.hango.hango_backend.service;

import com.hango.hango_backend.dto.ExamResultAnalysisDTO;
import com.hango.hango_backend.dto.UserAnswerDTO;
import com.hango.hango_backend.entity.ExamAttempt;
import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.hango.hango_backend.repository.ExamAttemptRepository;

import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;

import java.util.ArrayList;
import java.util.Collections;

import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Objects;
import java.util.Set;
import java.util.stream.Collectors;


/**
 * Tool dùng cho AI Interactive Learning Pathway.
 *
 * Mục tiêu: cung cấp “đầu vào phân tích” (không phải prompt free-form) từ kết quả bài thi
 * để AI Agent/roadmap không bỏ qua dữ liệu.
 */
@Service
@Slf4j
@RequiredArgsConstructor
public class ExamResultAnalyzerService {

    private final ObjectMapper objectMapper;
    private final SkillCategoryMappingService skillCategoryMappingService;
    private final ExamAttemptRepository examAttemptRepository;

    /**
     * Phân tích 1 attempt (giữ backward compatibility).
     */
    public ExamResultAnalysisDTO analyzeLatestExamAttempt(ExamAttempt examAttempt) {
        Map<String, Object> hints = new HashMap<>();

        String answersJson = examAttempt.getAnswersJson();
        hints.put("answersJson", answersJson);

        if (examAttempt.getScore() != null) {
            hints.put("score", examAttempt.getScore().intValue());
        }

        return ExamResultAnalysisDTO.builder()
                .examAttemptId(examAttempt.getId())
                .score(examAttempt.getScore() != null ? examAttempt.getScore().doubleValue() : null)
                .rawAnswersJson(answersJson)
                .knowledgeGapsJson(extractKnowledgeGapsPlaceholder(answersJson))
                .hints(hints)
                .build();
    }

    /**
     * Phân tích tổng hợp N attempts gần nhất của learner để suy ra điểm yếu kỹ năng.
     *
     * Quy ước: gọi tool để extract skill gaps từ answersJson, rồi merge theo tần suất.
     */
    public ExamResultAnalysisDTO analyzeLearnerAttempts(Long learnerId, List<ExamAttempt> attempts) {
        if (attempts == null || attempts.isEmpty()) {
            return ExamResultAnalysisDTO.builder()
                    .examAttemptId(null)
                    .score(null)
                    .rawAnswersJson(null)
                    .knowledgeGapsJson("{}")
                    .hints(Map.of("learnerId", learnerId, "attemptsUsed", 0))
                    .build();
        }

        // Gom diem yeu theo tan suat xuat hien trong N attempts:
        // skill sai o nhieu attempt se co diem cao hon -> xep truoc
        Map<String, Integer> weakSkillCount = new HashMap<>();
        Map<String, Integer> criticalTopicCount = new HashMap<>();

        Double minScore = null;
        Double maxScore = null;
        Double sumScore = 0.0;
        int scoredAttempts = 0;

        List<Long> attemptIds = attempts.stream().map(ExamAttempt::getId).toList();

        // rawAnswersJson (chỉ lấy attempt mới nhất để không bơm prompt quá lớn)
        ExamAttempt latest = attempts.get(0);
        String rawLatestAnswers = latest.getAnswersJson();

        for (ExamAttempt attempt : attempts) {
            if (attempt.getScore() != null) {
                double s = attempt.getScore().doubleValue();
                sumScore += s;
                scoredAttempts++;
                minScore = (minScore == null) ? s : Math.min(minScore, s);
                maxScore = (maxScore == null) ? s : Math.max(maxScore, s);
            }

            String knowledgeGapsJson = extractKnowledgeGapsPlaceholder(attempt.getAnswersJson());
            // knowledgeGapsJson là JSON string placeholder:
            // {weak_skills:[...], critical_topics:[...], incorrect_count:X}
            mergeKnowledgeGapsFromPlaceholder(knowledgeGapsJson, weakSkillCount, criticalTopicCount);
        }

        // Nếu schema/parse answersJson không đủ để gom skill đúng,
        // fallback bằng cách lấy danh sách weak_skills từ attempt mới nhất.
        if (weakSkillCount.isEmpty()) {
            String latestGaps = extractKnowledgeGapsPlaceholder(latest.getAnswersJson());
            try {
                @SuppressWarnings("unchecked")
                Map<String, Object> parsed = objectMapper.readValue(latestGaps, Map.class);
                Object weakSkillsObj = parsed.get("weak_skills");
                if (weakSkillsObj instanceof List<?> weakSkillsList) {
                    for (Object s : weakSkillsList) {
                        if (s == null) continue;
                        String key = s.toString().trim();
                        if (key.isBlank()) continue;
                        weakSkillCount.put(key, 1);
                    }
                }
            } catch (Exception ignore) {
                // ignore
            }
        }

        double avgScore = scoredAttempts > 0 ? sumScore / scoredAttempts : 0.0;

        List<String> weakSkills = weakSkillCount.entrySet().stream()
                .sorted((a, b) -> Integer.compare(b.getValue(), a.getValue()))
                .limit(10)
                .map(Map.Entry::getKey)
                .toList();

        Set<String> weakCategoriesSet = weakSkills.stream()
                .map(skillCategoryMappingService::getCategoryForSkill)
                .filter(Objects::nonNull)
                .collect(Collectors.toSet());
        List<String> weakCategories = new ArrayList<>(weakCategoriesSet);
        Collections.sort(weakCategories);

        // --- NEW: Extract LATEST weak skills explicitly ---
        List<String> latestWeakSkills = new ArrayList<>();
        try {
            String latestGaps = extractKnowledgeGapsPlaceholder(latest.getAnswersJson());
            @SuppressWarnings("unchecked")
            Map<String, Object> parsedLatest = objectMapper.readValue(latestGaps, Map.class);
            Object weakSkillsObj = parsedLatest.get("weak_skills");
            if (weakSkillsObj instanceof List<?> weakSkillsList) {
                for (Object s : weakSkillsList) {
                    if (s != null && !s.toString().trim().isBlank()) {
                        latestWeakSkills.add(s.toString().trim());
                    }
                }
            }
        } catch (Exception ignore) {}

        List<String> latestWeakCategories = latestWeakSkills.stream()
                .map(skillCategoryMappingService::getCategoryForSkill)
                .filter(Objects::nonNull)
                .distinct()
                .sorted()
                .toList();
        // ------------------------------------------------

        List<String> criticalTopics = criticalTopicCount.entrySet().stream()
                .sorted((a, b) -> Integer.compare(b.getValue(), a.getValue()))
                .limit(10)
                .map(Map.Entry::getKey)
                .toList();

        Map<String, Object> summary = new HashMap<>();
        summary.put("weak_skills", weakSkills);
        summary.put("weak_categories", weakCategories);
        summary.put("latest_weak_skills", latestWeakSkills);
        summary.put("latest_weak_categories", latestWeakCategories);
        summary.put("historical_weak_skills", weakSkills); // Keeping backwards compatibility
        summary.put("historical_weak_categories", weakCategories);
        summary.put("critical_topics", criticalTopics);
        summary.put("attempts_used", attempts.size());
        summary.put("score_avg", avgScore);
        summary.put("score_min", minScore);
        summary.put("score_max", maxScore);

        return ExamResultAnalysisDTO.builder()
                .examAttemptId(latest.getId())
                .score(latest.getScore() != null ? latest.getScore().doubleValue() : null)
                .rawAnswersJson(rawLatestAnswers)
                .knowledgeGapsJson(serializeSafe(summary))
                .hints(Map.of(
                        "learnerId", learnerId,
                        "attemptIds", attemptIds,
                        "attemptsUsed", attempts.size(),
                        "score_avg", avgScore
                ))
                .build();
    }

    private String serializeSafe(Map<String, Object> summary) {
        try {
            return objectMapper.writeValueAsString(summary);
        } catch (Exception e) {
            log.warn("Failed to serialize knowledge gap summary: {}", e.getMessage());
            return "{}";
        }
    }

    /**
     * knowledgeGapsJson hiện tại có thể là JSON placeholder hoặc fallback raw.
     * Nếu là JSON placeholder thì parse và merge.
     */
    private void mergeKnowledgeGapsFromPlaceholder(
            String knowledgeGapsJson,
            Map<String, Integer> weakSkillCount,
            Map<String, Integer> criticalTopicCount) {

        if (knowledgeGapsJson == null || knowledgeGapsJson.isBlank()) {
            return;
        }

        try {
            @SuppressWarnings("unchecked")
            Map<String, Object> parsed = objectMapper.readValue(knowledgeGapsJson, Map.class);

            Object weakSkillsObj = parsed.get("weak_skills");
            if (weakSkillsObj instanceof List<?> weakSkillsList) {
                for (Object s : weakSkillsList) {
                    if (s == null) continue;
                    String key = s.toString().trim();
                    if (key.isBlank()) continue;
                    weakSkillCount.merge(key, 1, Integer::sum);
                }
            }

            Object topicsObj = parsed.get("critical_topics");
            if (topicsObj instanceof List<?> topicsList) {
                for (Object t : topicsList) {
                    if (t == null) continue;
                    String key = t.toString().trim();
                    if (key.isBlank()) continue;
                    criticalTopicCount.merge(key, 1, Integer::sum);
                }
            }
        } catch (Exception e) {
            // nếu parse fail -> bỏ qua để không làm hỏng flow
            log.debug("Skipping merge because knowledgeGapsJson not parseable placeholder. err={}", e.getMessage());
        }
    }


    private String extractKnowledgeGapsPlaceholder(String answersJson) {
        // Day la "tool" phan tich diem yeu: doc answersJson (danh sach cau tra loi
        // co skill/isCorrect/topic), chi giu lai cac CAU SAI de rut ra weak skills
        if (answersJson == null || answersJson.isBlank()) {
            return "{}";
        }

        try {
            // Giả định answersJson có dạng mảng JSON các object trả lời.
            List<UserAnswerDTO> answers = objectMapper.readValue(
                    answersJson,
                    objectMapper.getTypeFactory().constructCollectionType(List.class, UserAnswerDTO.class)
            );

            List<UserAnswerDTO> incorrectAnswers = answers.stream()
                    .filter(a -> Boolean.FALSE.equals(a.getIsCorrect()))
                    .toList();

            int incorrectCount = incorrectAnswers.size();

            // Gom nhóm topic bị làm sai nhiều nhất.
            Map<String, Long> incorrectByTopic = incorrectAnswers.stream()
                    .filter(a -> a.getTopic() != null && !a.getTopic().isBlank())
                    .collect(Collectors.groupingBy(
                            a -> a.getTopic().trim(),
                            Collectors.counting()
                    ));

            // Lấy top topic theo số lần sai (giới hạn để tiết kiệm token).
            List<String> criticalTopics = incorrectByTopic.entrySet().stream()
                    .sorted((e1, e2) -> Long.compare(e2.getValue(), e1.getValue()))
                    .limit(5)
                    .map(e -> e.getKey())
                    .toList();

            Set<String> weakSkills = incorrectAnswers.stream()
                    .map(UserAnswerDTO::getSkill)
                    .filter(Objects::nonNull)
                    .map(String::trim)
                    .filter(s -> !s.isBlank())
                    .collect(Collectors.toSet());

            Set<String> weakCategories = weakSkills.stream()
                    .map(skillCategoryMappingService::getCategoryForSkill)
                    .filter(Objects::nonNull)
                    .collect(Collectors.toSet());

            Map<String, Object> summary = new HashMap<>();
            summary.put("weak_skills", weakSkills.stream().sorted().toList());
            summary.put("weak_categories", weakCategories.stream().sorted().toList());
            summary.put("critical_topics", criticalTopics);
            summary.put("incorrect_count", incorrectCount);

            return objectMapper.writeValueAsString(summary);
        } catch (JsonProcessingException e) {
            // Nếu parse fail (schema JSON thực tế khác giả định), fallback về raw JSON để không làm đứt flow.
            log.warn("Failed to parse answersJson for knowledge gaps. Using raw fallback. error={}", e.getMessage());
            return answersJson;
        } catch (Exception e) {
            log.warn("Unexpected error while extracting knowledge gaps. Using raw fallback. error={}", e.getMessage());
            return answersJson;
        }
    }

    /**
     * Lấy thống kê độ chính xác của từng kỹ năng dựa trên 10 bài thi gần nhất.
     */
    public Map<String, Double> getSkillAnalytics(Long learnerId) {
        List<ExamAttempt> attempts = examAttemptRepository.findTop10ByStudent_IdOrderBySubmittedAtDesc(learnerId);
        if (attempts == null || attempts.isEmpty()) {
            return Collections.emptyMap();
        }

        Map<String, Integer> totalQuestionsPerSkill = new HashMap<>();
        Map<String, Integer> correctQuestionsPerSkill = new HashMap<>();

        for (ExamAttempt attempt : attempts) {
            String answersJson = attempt.getAnswersJson();
            if (answersJson == null || answersJson.isBlank()) continue;

            try {
                List<UserAnswerDTO> answers = objectMapper.readValue(
                        answersJson,
                        objectMapper.getTypeFactory().constructCollectionType(List.class, UserAnswerDTO.class)
                );

                for (UserAnswerDTO a : answers) {
                    if (a.getSkill() == null || a.getSkill().isBlank()) continue;
                    String skill = a.getSkill().trim();

                    totalQuestionsPerSkill.merge(skill, 1, Integer::sum);
                    if (Boolean.TRUE.equals(a.getIsCorrect())) {
                        correctQuestionsPerSkill.merge(skill, 1, Integer::sum);
                    }
                }
            } catch (Exception e) {
                log.warn("Failed to parse answersJson for skill analytics. error={}", e.getMessage());
            }
        }

        Map<String, Double> skillAccuracy = new HashMap<>();
        for (Map.Entry<String, Integer> entry : totalQuestionsPerSkill.entrySet()) {
            String skill = entry.getKey();
            int total = entry.getValue();
            int correct = correctQuestionsPerSkill.getOrDefault(skill, 0);
            double accuracy = total > 0 ? (double) correct / total : 0.0;
            
            // Round to 2 decimal places
            accuracy = Math.round(accuracy * 100.0) / 100.0;
            skillAccuracy.put(skill, accuracy);
        }

        return skillAccuracy;
    }

}

