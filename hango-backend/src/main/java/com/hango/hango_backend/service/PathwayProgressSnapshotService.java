package com.hango.hango_backend.service;

import com.hango.hango_backend.dto.ExamResultAnalysisDTO;
import com.hango.hango_backend.dto.ProgressSnapshotDTO;
import com.hango.hango_backend.entity.LearningPathway;
import com.hango.hango_backend.entity.LessonQuizAttempt;
import com.hango.hango_backend.entity.PathwayNode;
import com.hango.hango_backend.repository.ExamAttemptRepository;
import com.hango.hango_backend.repository.LearningPathwayRepository;
import com.hango.hango_backend.repository.LessonProgressRepository;
import com.hango.hango_backend.repository.LessonQuizAttemptRepository;
import com.hango.hango_backend.repository.LessonRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.ArrayList;
import java.util.HashSet;
import java.util.List;
import java.util.Set;

@Service
@RequiredArgsConstructor
@Slf4j
public class PathwayProgressSnapshotService {

    private static final String LESSON_TYPE_FINAL_QUIZ = "FINAL_QUIZ";
    private static final double PASS_THRESHOLD = 60.0;

    private final LearningPathwayRepository pathwayRepository;
    private final LessonProgressRepository lessonProgressRepository;
    private final LessonRepository lessonRepository;
    private final LessonQuizAttemptRepository quizAttemptRepository;
    private final ExamAttemptRepository examAttemptRepository;
    private final ExamResultAnalyzerService examResultAnalyzerService;

    @Transactional(readOnly = true)
    public ProgressSnapshotDTO getProgressSnapshot(Long pathwayId, Long learnerId) {
        LearningPathway pathway = pathwayRepository.findById(pathwayId)
                .orElseThrow(() -> new IllegalArgumentException("Pathway not found"));

        if (!pathway.getStudent().getId().equals(learnerId)) {
            throw new IllegalArgumentException("Access denied");
        }

        // Diem yeu (theo Category) cua learner - dung de tinh hasWeakSkillOverlap (spec 20 - C1)
        Set<String> weakCategories = extractLearnerWeakCategories(learnerId);

        List<ProgressSnapshotDTO.NodeSnapshotDTO> nodeSnapshots = new ArrayList<>();
        for (PathwayNode node : pathway.getNodes()) {
            Long courseId = node.getCourse().getId();

            long totalLessons = lessonRepository.countByCourseId(courseId);
            long completedLessons = lessonProgressRepository.countCompletedLessonsByUserIdAndCourseId(learnerId, courseId);
            int progressPercent = totalLessons == 0 ? 0 : (int) Math.min(100, Math.round((double) completedLessons / totalLessons * 100));

            // A2: uu tien diem tu bai danh gia cuoi khoa (FINAL_QUIZ); neu course chua co
            // thi fallback ve tong hop moi lesson quiz nhu cu de khong mat du lieu
            List<LessonQuizAttempt> sourceAttempts = resolveSourceAttempts(learnerId, courseId);

            int failStreak = 0;
            Double latestScore = null;

            if (!sourceAttempts.isEmpty()) {
                latestScore = sourceAttempts.get(0).getScore();
                for (LessonQuizAttempt attempt : sourceAttempts) {
                    if (attempt.getScore() != null && attempt.getScore() < PASS_THRESHOLD) { // pass threshold
                        failStreak++;
                    } else {
                        break;
                    }
                }
            }

            boolean hasWeakSkillOverlap = false;
            if (node.getCourse() != null && node.getCourse().getCategory() != null
                    && node.getCourse().getCategory().getParamValue() != null) {
                hasWeakSkillOverlap = weakCategories.contains(
                        node.getCourse().getCategory().getParamValue().trim().toUpperCase());
            }

            nodeSnapshots.add(ProgressSnapshotDTO.NodeSnapshotDTO.builder()
                    .nodeId(node.getId())
                    .courseId(courseId)
                    .stepOrder(node.getStepOrder())
                    .status(node.getStatus())
                    .progressPercent(progressPercent)
                    .failStreak(failStreak)
                    .latestScore(latestScore)
                    .hasWeakSkillOverlap(hasWeakSkillOverlap)
                    .build());
        }

        return ProgressSnapshotDTO.builder()
                .pathwayId(pathwayId)
                .learnerId(learnerId)
                .nodesSnapshot(nodeSnapshots)
                .build();
    }

    /**
     * Uu tien attempt thuoc lesson co lesson_type = 'FINAL_QUIZ'.
     * Neu course chua co final quiz hoac learner chua lam → dung toan bo lesson quiz cua course.
     */
    private List<LessonQuizAttempt> resolveSourceAttempts(Long learnerId, Long courseId) {
        List<LessonQuizAttempt> finalQuizAttempts = quizAttemptRepository
                .findByStudentIdAndLessonSectionCourseIdAndLessonLessonTypeOrderBySubmittedAtDesc(
                        learnerId, courseId, LESSON_TYPE_FINAL_QUIZ);
        if (!finalQuizAttempts.isEmpty()) {
            return finalQuizAttempts;
        }
        return quizAttemptRepository.findByStudentIdAndLessonSectionCourseIdOrderBySubmittedAtDesc(learnerId, courseId);
    }

    /** Rut tap hop Category yeu (upper-case) cua learner tu 10 bai thi gan nhat. */
    private Set<String> extractLearnerWeakCategories(Long learnerId) {
        Set<String> result = new HashSet<>();
        try {
            List<com.hango.hango_backend.entity.ExamAttempt> attempts =
                    examAttemptRepository.findTop10ByStudent_IdOrderBySubmittedAtDesc(learnerId);
            ExamResultAnalysisDTO analysis = examResultAnalyzerService.analyzeLearnerAttempts(learnerId, attempts);
            if (analysis != null && analysis.getKnowledgeGapsJson() != null) {
                com.fasterxml.jackson.databind.JsonNode gaps =
                        new com.fasterxml.jackson.databind.ObjectMapper().readTree(analysis.getKnowledgeGapsJson());
                com.fasterxml.jackson.databind.JsonNode cats = gaps.get("weak_categories");
                if (cats != null && cats.isArray()) {
                    for (com.fasterxml.jackson.databind.JsonNode cat : cats) {
                        if (cat.asText(null) != null && !cat.asText().isBlank()) {
                            result.add(cat.asText().trim().toUpperCase());
                        }
                    }
                }
            }
        } catch (Exception e) {
            // Phan tich loi thi coi nhu khong co overlap - khong lam do snapshot
            log.warn("Could not compute weak categories for snapshot: {}", e.getMessage());
        }
        return result;
    }
}
