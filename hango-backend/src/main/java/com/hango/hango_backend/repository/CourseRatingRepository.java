package com.hango.hango_backend.repository;

import java.util.List;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import com.hango.hango_backend.entity.CourseRating;

@Repository
public interface CourseRatingRepository extends JpaRepository<CourseRating, Long> {
    List<CourseRating> findByCourseIdOrderByCreatedAtDesc(Long courseId);
    
    @org.springframework.data.jpa.repository.Query("SELECT cr FROM CourseRating cr, Course c WHERE c.id = :courseId AND (cr.course.id = c.id OR cr.course.parentId = c.id OR cr.course.id = c.parentId OR (c.parentId IS NOT NULL AND cr.course.parentId = c.parentId)) ORDER BY cr.createdAt DESC")
    List<CourseRating> findByCourseFamilyOrderByCreatedAtDesc(@org.springframework.data.repository.query.Param("courseId") Long courseId);

    java.util.Optional<CourseRating> findByCourseIdAndStudentId(Long courseId, Long studentId);

    @org.springframework.data.jpa.repository.Query("SELECT AVG(cr.rating) FROM CourseRating cr WHERE cr.course.creator.id = :trainerId")
    Double getAverageRatingByTrainerId(@org.springframework.data.repository.query.Param("trainerId") Long trainerId);

    @org.springframework.data.jpa.repository.Query("SELECT cr FROM CourseRating cr JOIN FETCH cr.course c JOIN FETCH c.creator crt LEFT JOIN FETCH c.category LEFT JOIN FETCH c.difficulty WHERE crt.id = :creatorId ORDER BY cr.createdAt DESC LIMIT 5")
    List<CourseRating> findTop5ByCourseCreatorIdOrderByCreatedAtDesc(@org.springframework.data.repository.query.Param("creatorId") Long creatorId);

    @org.springframework.data.jpa.repository.Query("SELECT AVG(cr.rating) FROM CourseRating cr WHERE cr.course.id IN :courseIds")
    Double getAverageRatingByCourseIds(@org.springframework.data.repository.query.Param("courseIds") List<Long> courseIds);

    List<CourseRating> findByCourseIdIn(List<Long> courseIds);

    long countByCourseIdIn(List<Long> courseIds);

    @org.springframework.data.jpa.repository.Query(value = "SELECT REGEXP_REPLACE(UPPER(c.code), '-V[0-9]+$', '') AS base_code, " +
            "AVG(cr.rating) AS average_rating, COUNT(cr.id) AS total_ratings " +
            "FROM course_ratings cr " +
            "JOIN courses c ON c.id = cr.course_id " +
            "WHERE c.code IS NOT NULL " +
            "AND REGEXP_REPLACE(UPPER(c.code), '-V[0-9]+$', '') IN (:baseCodes) " +
            "GROUP BY REGEXP_REPLACE(UPPER(c.code), '-V[0-9]+$', '')",
            nativeQuery = true)
    List<Object[]> getRatingStatsByCourseBaseCodes(@org.springframework.data.repository.query.Param("baseCodes") List<String> baseCodes);

    @org.springframework.data.jpa.repository.Query("SELECT cr.course.id, AVG(cr.rating), COUNT(cr.id) FROM CourseRating cr WHERE cr.course.id IN :courseIds GROUP BY cr.course.id")
    List<Object[]> getRatingStatsByCourseIds(@org.springframework.data.repository.query.Param("courseIds") List<Long> courseIds);
}
