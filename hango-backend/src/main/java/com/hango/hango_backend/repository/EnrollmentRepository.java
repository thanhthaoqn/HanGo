package com.hango.hango_backend.repository;

import com.hango.hango_backend.entity.Enrollment;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import java.util.Optional;

@Repository
public interface EnrollmentRepository extends JpaRepository<Enrollment, Long> {
    Optional<Enrollment> findByUserIdAndCourseId(Long userId, Long courseId);
    boolean existsByUserIdAndCourseId(Long userId, Long courseId);
    void deleteByUserIdAndCourseId(Long userId, Long courseId);
    int countByCourseId(Long courseId);

    @Query("SELECT COUNT(DISTINCT e.user.id) FROM Enrollment e WHERE e.course.creator.id = :creatorId AND e.course.deletedAt IS NULL")
    long countDistinctStudentsByCourseCreatorId(@Param("creatorId") Long creatorId);
}
