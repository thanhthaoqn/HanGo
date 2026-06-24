package com.hango.hango_backend.repository;

import com.hango.hango_backend.entity.Lesson;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;

@Repository
public interface LessonRepository extends JpaRepository<Lesson, Long> {
    List<Lesson> findBySectionIdOrderByDisplayOrderAsc(Long sectionId);

    @org.springframework.data.jpa.repository.Query(value = "SELECT COUNT(*) FROM lesson_quizzes WHERE lesson_id = :lessonId", nativeQuery = true)
    int countQuestionsByLessonId(@org.springframework.data.repository.query.Param("lessonId") Long lessonId);

    @org.springframework.data.jpa.repository.Query("SELECT COUNT(l) FROM Lesson l WHERE l.section.course.id = :courseId AND l.deletedAt IS NULL")
    long countByCourseId(@org.springframework.data.repository.query.Param("courseId") Long courseId);
}
