package com.hango.hango_backend.service;

import com.hango.hango_backend.dto.ProgressSnapshotDTO;
import com.hango.hango_backend.entity.LearningPathway;
import com.hango.hango_backend.entity.LessonQuizAttempt;
import com.hango.hango_backend.entity.PathwayNode;
import com.hango.hango_backend.repository.LearningPathwayRepository;
import com.hango.hango_backend.repository.LessonProgressRepository;
import com.hango.hango_backend.repository.LessonQuizAttemptRepository;
import com.hango.hango_backend.repository.LessonRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.ArrayList;
import java.util.List;

@Service
@RequiredArgsConstructor
public class PathwayProgressSnapshotService {

    private final LearningPathwayRepository pathwayRepository;
    private final LessonProgressRepository lessonProgressRepository;
    private final LessonRepository lessonRepository;
    private final LessonQuizAttemptRepository quizAttemptRepository;

    @Transactional(readOnly = true)
    public ProgressSnapshotDTO getProgressSnapshot(Long pathwayId, Long learnerId) {
        LearningPathway pathway = pathwayRepository.findById(pathwayId)
                .orElseThrow(() -> new IllegalArgumentException("Pathway not found"));

        if (!pathway.getStudent().getId().equals(learnerId)) {
            throw new IllegalArgumentException("Access denied");
        }

        List<ProgressSnapshotDTO.NodeSnapshotDTO> nodeSnapshots = new ArrayList<>();
        for (PathwayNode node : pathway.getNodes()) {
            Long courseId = node.getCourse().getId();

            long totalLessons = lessonRepository.countByCourseId(courseId);
            long completedLessons = lessonProgressRepository.countCompletedLessonsByUserIdAndCourseId(learnerId, courseId);
            int progressPercent = totalLessons == 0 ? 0 : (int) Math.min(100, Math.round((double) completedLessons / totalLessons * 100));

            // Calculate fail streak and latest score
            List<LessonQuizAttempt> recentAttempts = quizAttemptRepository.findByStudentIdAndLessonSectionCourseIdOrderBySubmittedAtDesc(learnerId, courseId);
            
            int failStreak = 0;
            Double latestScore = null;
            
            if (!recentAttempts.isEmpty()) {
                latestScore = recentAttempts.get(0).getScore();
                for (LessonQuizAttempt attempt : recentAttempts) {
                    if (attempt.getScore() != null && attempt.getScore() < 60.0) { // pass threshold
                        failStreak++;
                    } else {
                        break;
                    }
                }
            }

            nodeSnapshots.add(ProgressSnapshotDTO.NodeSnapshotDTO.builder()
                    .nodeId(node.getId())
                    .courseId(courseId)
                    .stepOrder(node.getStepOrder())
                    .status(node.getStatus())
                    .progressPercent(progressPercent)
                    .failStreak(failStreak)
                    .latestScore(latestScore)
                    .hasWeakSkillOverlap(false) // Needs implementation based on exam result analyzer
                    .build());
        }

        return ProgressSnapshotDTO.builder()
                .pathwayId(pathwayId)
                .learnerId(learnerId)
                .nodesSnapshot(nodeSnapshots)
                .build();
    }
}
