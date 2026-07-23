package com.hango.hango_backend.repository;

import com.hango.hango_backend.entity.Enrollment;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Lock;
import org.springframework.stereotype.Repository;

import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import jakarta.persistence.LockModeType;
import java.util.Optional;
import java.util.List;

@Repository
public interface EnrollmentRepository extends JpaRepository<Enrollment, Long> {
    Optional<Enrollment> findByUserIdAndCourseId(Long userId, Long courseId);
    boolean existsByUserIdAndCourseId(Long userId, Long courseId);
    void deleteByUserIdAndCourseId(Long userId, Long courseId);
    int countByCourseId(Long courseId);

    @Query("SELECT COUNT(DISTINCT e.id) FROM Enrollment e, Course c WHERE c.id = :courseId AND (e.course.id = c.id OR e.course.parentId = c.id OR e.course.id = c.parentId OR (c.parentId IS NOT NULL AND e.course.parentId = c.parentId))")
    int countByCourseFamily(@Param("courseId") Long courseId);

    @Query("SELECT e FROM Enrollment e, Course c WHERE e.user.id = :userId AND c.id = :courseId AND (e.course.id = c.id OR e.course.parentId = c.id OR e.course.id = c.parentId OR (c.parentId IS NOT NULL AND e.course.parentId = c.parentId))")
    List<Enrollment> findFamilyEnrollments(@Param("userId") Long userId, @Param("courseId") Long courseId);

    @Query("SELECT COUNT(DISTINCT e.user.id) FROM Enrollment e WHERE e.course.creator.id = :creatorId AND e.course.deletedAt IS NULL")
    long countDistinctStudentsByCourseCreatorId(@Param("creatorId") Long creatorId);

    @Lock(LockModeType.PESSIMISTIC_WRITE)
    @Query("SELECT e FROM Enrollment e WHERE e.user.id = :userId AND e.course.id = :courseId")
    Optional<Enrollment> findByUserIdAndCourseIdWithLock(@Param("userId") Long userId, @Param("courseId") Long courseId);

    List<Enrollment> findTop5ByCourseCreatorIdOrderByEnrolledAtDesc(Long creatorId);
}
