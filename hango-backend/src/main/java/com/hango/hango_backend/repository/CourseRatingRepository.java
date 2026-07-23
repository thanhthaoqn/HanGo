package com.hango.hango_backend.repository;

import com.hango.hango_backend.entity.CourseRating;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;

@Repository
public interface CourseRatingRepository extends JpaRepository<CourseRating, Long> {
    List<CourseRating> findByCourseIdOrderByCreatedAtDesc(Long courseId);
    java.util.Optional<CourseRating> findByCourseIdAndStudentId(Long courseId, Long studentId);

    @org.springframework.data.jpa.repository.Query("SELECT AVG(cr.rating) FROM CourseRating cr WHERE cr.course.creator.id = :trainerId")
    Double getAverageRatingByTrainerId(@org.springframework.data.repository.query.Param("trainerId") Long trainerId);

    List<CourseRating> findTop5ByCourseCreatorIdOrderByCreatedAtDesc(Long creatorId);
}
