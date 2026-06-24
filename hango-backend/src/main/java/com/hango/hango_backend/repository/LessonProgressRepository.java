package com.hango.hango_backend.repository;

import com.hango.hango_backend.entity.LessonProgress;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;

@Repository
public interface LessonProgressRepository extends JpaRepository<LessonProgress, Long> {
    
    Optional<LessonProgress> findByUserIdAndLessonId(Long userId, Long lessonId);
    
    boolean existsByUserIdAndLessonIdAndIsCompletedTrue(Long userId, Long lessonId);

    @Query("SELECT COUNT(lp) FROM LessonProgress lp " +
           "WHERE lp.user.id = :userId " +
           "AND lp.lesson.section.course.id = :courseId " +
           "AND lp.isCompleted = true " +
           "AND lp.lesson.deletedAt IS NULL")
    long countCompletedLessonsByUserIdAndCourseId(@Param("userId") Long userId, @Param("courseId") Long courseId);

    @Query("SELECT lp.lesson.id FROM LessonProgress lp " +
           "WHERE lp.user.id = :userId " +
           "AND lp.lesson.section.course.id = :courseId " +
           "AND lp.isCompleted = true " +
           "AND lp.lesson.deletedAt IS NULL")
    List<Long> findCompletedLessonIdsByUserIdAndCourseId(@Param("userId") Long userId, @Param("courseId") Long courseId);
}
