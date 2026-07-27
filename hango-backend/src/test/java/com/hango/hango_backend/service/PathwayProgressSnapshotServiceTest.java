package com.hango.hango_backend.service;

import java.util.List;
import java.util.Optional;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertThrows;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import static org.mockito.Mockito.when;
import org.mockito.junit.jupiter.MockitoExtension;

import com.hango.hango_backend.dto.ProgressSnapshotDTO;
import com.hango.hango_backend.entity.Course;
import com.hango.hango_backend.entity.LearningPathway;
import com.hango.hango_backend.entity.LessonQuizAttempt;
import com.hango.hango_backend.entity.PathwayNode;
import com.hango.hango_backend.entity.User;
import com.hango.hango_backend.repository.LearningPathwayRepository;
import com.hango.hango_backend.repository.LessonProgressRepository;
import com.hango.hango_backend.repository.LessonQuizAttemptRepository;
import com.hango.hango_backend.repository.LessonRepository;

@ExtendWith(MockitoExtension.class)
class PathwayProgressSnapshotServiceTest {

    @Mock
    private LearningPathwayRepository pathwayRepository;
    @Mock
    private LessonProgressRepository lessonProgressRepository;
    @Mock
    private LessonRepository lessonRepository;
    @Mock
    private LessonQuizAttemptRepository quizAttemptRepository;

    @InjectMocks
    private PathwayProgressSnapshotService service;

    private LearningPathway pathwayWithNode(Long studentId, PathwayNode node) {
        LearningPathway pathway = LearningPathway.builder()
                .id(1L)
                .student(User.builder().id(studentId).build())
                .build();
        pathway.addNode(node);
        return pathway;
    }

    private PathwayNode node(Long id, int step, String status, Long courseId) {
        return PathwayNode.builder()
                .id(id)
                .stepOrder(step)
                .status(status)
                .course(Course.builder().id(courseId).build())
                .build();
    }

    private LessonQuizAttempt attempt(double score) {
        return LessonQuizAttempt.builder().score(score).build();
    }

    // =================================================================
    // getProgressSnapshot
    // =================================================================

    @Test
    void getProgressSnapshotShouldThrowWhenPathwayNotFound() {
        when(pathwayRepository.findById(1L)).thenReturn(Optional.empty());

        assertThrows(IllegalArgumentException.class, () -> service.getProgressSnapshot(1L, 1L));
    }

    @Test
    void getProgressSnapshotShouldThrowWhenAccessedByDifferentLearner() {
        LearningPathway pathway = pathwayWithNode(2L, node(1L, 1, "IN_PROGRESS", 10L));
        when(pathwayRepository.findById(1L)).thenReturn(Optional.of(pathway));

        assertThrows(IllegalArgumentException.class, () -> service.getProgressSnapshot(1L, 1L));
    }

    @Test
    void getProgressSnapshotShouldComputeProgressPercentPerNode() {
        LearningPathway pathway = pathwayWithNode(1L, node(1L, 1, "IN_PROGRESS", 10L));
        when(pathwayRepository.findById(1L)).thenReturn(Optional.of(pathway));
        when(lessonRepository.countByCourseId(10L)).thenReturn(4L);
        when(lessonProgressRepository.countCompletedLessonsByUserIdAndCourseId(1L, 10L)).thenReturn(3L);
        when(quizAttemptRepository.findByStudentIdAndLessonSectionCourseIdOrderBySubmittedAtDesc(1L, 10L))
                .thenReturn(List.of());

        ProgressSnapshotDTO result = service.getProgressSnapshot(1L, 1L);

        assertEquals(75, result.getNodesSnapshot().get(0).getProgressPercent());
    }

    @Test
    void getProgressSnapshotShouldReturnZeroProgressWhenCourseHasNoLessons() {
        LearningPathway pathway = pathwayWithNode(1L, node(1L, 1, "IN_PROGRESS", 10L));
        when(pathwayRepository.findById(1L)).thenReturn(Optional.of(pathway));
        when(lessonRepository.countByCourseId(10L)).thenReturn(0L);
        when(quizAttemptRepository.findByStudentIdAndLessonSectionCourseIdOrderBySubmittedAtDesc(1L, 10L))
                .thenReturn(List.of());

        ProgressSnapshotDTO result = service.getProgressSnapshot(1L, 1L);

        assertEquals(0, result.getNodesSnapshot().get(0).getProgressPercent());
    }

    @Test
    void getProgressSnapshotShouldComputeFailStreakFromConsecutiveLowScoreAttempts() {
        LearningPathway pathway = pathwayWithNode(1L, node(1L, 1, "IN_PROGRESS", 10L));
        when(pathwayRepository.findById(1L)).thenReturn(Optional.of(pathway));
        when(lessonRepository.countByCourseId(10L)).thenReturn(1L);
        when(lessonProgressRepository.countCompletedLessonsByUserIdAndCourseId(1L, 10L)).thenReturn(0L);
        when(quizAttemptRepository.findByStudentIdAndLessonSectionCourseIdOrderBySubmittedAtDesc(1L, 10L))
                .thenReturn(List.of(attempt(40.0), attempt(50.0), attempt(90.0)));

        ProgressSnapshotDTO result = service.getProgressSnapshot(1L, 1L);

        assertEquals(2, result.getNodesSnapshot().get(0).getFailStreak());
        assertEquals(40.0, result.getNodesSnapshot().get(0).getLatestScore());
    }

    @Test
    void getProgressSnapshotShouldStopFailStreakAtFirstPassingAttempt() {
        LearningPathway pathway = pathwayWithNode(1L, node(1L, 1, "IN_PROGRESS", 10L));
        when(pathwayRepository.findById(1L)).thenReturn(Optional.of(pathway));
        when(lessonRepository.countByCourseId(10L)).thenReturn(1L);
        when(lessonProgressRepository.countCompletedLessonsByUserIdAndCourseId(1L, 10L)).thenReturn(0L);
        when(quizAttemptRepository.findByStudentIdAndLessonSectionCourseIdOrderBySubmittedAtDesc(1L, 10L))
                .thenReturn(List.of(attempt(90.0), attempt(30.0)));

        ProgressSnapshotDTO result = service.getProgressSnapshot(1L, 1L);

        assertEquals(0, result.getNodesSnapshot().get(0).getFailStreak());
    }

    @Test
    void getProgressSnapshotShouldReturnNullLatestScoreWhenNoAttempts() {
        LearningPathway pathway = pathwayWithNode(1L, node(1L, 1, "IN_PROGRESS", 10L));
        when(pathwayRepository.findById(1L)).thenReturn(Optional.of(pathway));
        when(lessonRepository.countByCourseId(10L)).thenReturn(1L);
        when(lessonProgressRepository.countCompletedLessonsByUserIdAndCourseId(1L, 10L)).thenReturn(0L);
        when(quizAttemptRepository.findByStudentIdAndLessonSectionCourseIdOrderBySubmittedAtDesc(1L, 10L))
                .thenReturn(List.of());

        ProgressSnapshotDTO result = service.getProgressSnapshot(1L, 1L);

        assertNull(result.getNodesSnapshot().get(0).getLatestScore());
        assertEquals(0, result.getNodesSnapshot().get(0).getFailStreak());
    }

    @Test
    void getProgressSnapshotShouldAlwaysReturnHasWeakSkillOverlapFalse() {
        LearningPathway pathway = pathwayWithNode(1L, node(1L, 1, "IN_PROGRESS", 10L));
        when(pathwayRepository.findById(1L)).thenReturn(Optional.of(pathway));
        when(lessonRepository.countByCourseId(10L)).thenReturn(1L);
        when(lessonProgressRepository.countCompletedLessonsByUserIdAndCourseId(1L, 10L)).thenReturn(0L);
        when(quizAttemptRepository.findByStudentIdAndLessonSectionCourseIdOrderBySubmittedAtDesc(1L, 10L))
                .thenReturn(List.of());

        ProgressSnapshotDTO result = service.getProgressSnapshot(1L, 1L);

        assertFalse(result.getNodesSnapshot().get(0).getHasWeakSkillOverlap());
    }
}
