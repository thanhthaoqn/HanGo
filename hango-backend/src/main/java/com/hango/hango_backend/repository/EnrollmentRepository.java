package com.hango.hango_backend.repository;

import com.hango.hango_backend.entity.Enrollment;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

@Repository
public interface EnrollmentRepository extends JpaRepository<Enrollment, Long> {

    @Query("SELECT COUNT(DISTINCT e.user.id) FROM Enrollment e " +
           "WHERE e.course.creator.id = :trainerId AND e.course.deletedAt IS NULL")
    long countDistinctLearnersByTrainerId(@Param("trainerId") Long trainerId);
}
