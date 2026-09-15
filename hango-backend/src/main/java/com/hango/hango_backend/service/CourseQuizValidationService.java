package com.hango.hango_backend.service;

import com.hango.hango_backend.entity.Lesson;
import com.hango.hango_backend.repository.LessonRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;

import java.util.List;

/**
 * Luat nghiep vu A1 (spec 20): moi course truoc khi duoc PUBLISHED
 * phai co it nhat 1 quiz co it nhat 1 cau hoi.
 *
 * Quiz cua course = lesson (khong bi xoa mem) co it niat 1 dong trong
 * bang lesson_quizzes. Khong doi schema - chi doc du lieu hien co.
 */
@Service
@RequiredArgsConstructor
public class CourseQuizValidationService {

    private final LessonRepository lessonRepository;

    /** true neu course co it nhat 1 quiz (lesson co cau hoi) con hoat dong. */
    public boolean hasAtLeastOneQuiz(Long courseId) {
        List<Lesson> lessons = lessonRepository.findByCourseIdOrdered(courseId);
        if (lessons.isEmpty()) {
            return false;
        }
        List<Long> lessonIds = lessons.stream().map(Lesson::getId).toList();
        // countQuestionsByLessonIds tra ve [lesson_id, so_cau] cho cac lesson co cau hoi
        return lessonRepository.countQuestionsByLessonIds(lessonIds).stream()
                .anyMatch(row -> row[1] != null && ((Number) row[1]).longValue() > 0);
    }
}
