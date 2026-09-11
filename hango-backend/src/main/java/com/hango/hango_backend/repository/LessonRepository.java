package com.hango.hango_backend.repository;

import com.hango.hango_backend.entity.Lesson;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;

@Repository
public interface LessonRepository extends JpaRepository<Lesson, Long> {
    List<Lesson> findBySectionIdOrderByDisplayOrderAsc(Long sectionId);

    @org.springframework.data.jpa.repository.EntityGraph(attributePaths = {"section", "exam"})
    @org.springframework.data.jpa.repository.Query("SELECT l FROM Lesson l WHERE l.section.course.id = :courseId AND l.deletedAt IS NULL ORDER BY l.section.displayOrder ASC, l.displayOrder ASC")
    List<Lesson> findByCourseIdOrdered(@org.springframework.data.repository.query.Param("courseId") Long courseId);

    @org.springframework.data.jpa.repository.Query(value = "SELECT COUNT(*) FROM lesson_quizzes WHERE lesson_id = :lessonId", nativeQuery = true)
    int countQuestionsByLessonId(@org.springframework.data.repository.query.Param("lessonId") Long lessonId);

    @org.springframework.data.jpa.repository.Query(value = "SELECT lesson_id, COUNT(*) FROM lesson_quizzes WHERE lesson_id IN (:lessonIds) GROUP BY lesson_id", nativeQuery = true)
    List<Object[]> countQuestionsByLessonIds(@org.springframework.data.repository.query.Param("lessonIds") List<Long> lessonIds);

    @org.springframework.data.jpa.repository.Query("SELECT COUNT(l) FROM Lesson l WHERE l.section.course.id = :courseId AND l.deletedAt IS NULL")
    long countByCourseId(@org.springframework.data.repository.query.Param("courseId") Long courseId);

    @org.springframework.data.jpa.repository.Query("SELECT l FROM Lesson l WHERE l.section.course.id = :courseId AND l.lessonType IN ('QUIZ', 'FINAL_QUIZ') AND l.deletedAt IS NULL ORDER BY l.section.displayOrder DESC, l.displayOrder DESC")
    List<Lesson> findLastQuizByCourseId(@org.springframework.data.repository.query.Param("courseId") Long courseId, org.springframework.data.domain.Pageable pageable);
}
