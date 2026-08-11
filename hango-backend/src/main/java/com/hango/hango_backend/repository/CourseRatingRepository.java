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

    List<CourseRating> findTop5ByCourseCreatorIdOrderByCreatedAtDesc(Long creatorId);

    @org.springframework.data.jpa.repository.Query("SELECT AVG(cr.rating) FROM CourseRating cr WHERE cr.course.id IN :courseIds")
    Double getAverageRatingByCourseIds(@org.springframework.data.repository.query.Param("courseIds") List<Long> courseIds);

    List<CourseRating> findByCourseIdIn(List<Long> courseIds);
}
