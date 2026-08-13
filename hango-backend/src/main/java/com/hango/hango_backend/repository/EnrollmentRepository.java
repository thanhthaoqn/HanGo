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
import java.time.LocalDateTime;

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

    @org.springframework.data.jpa.repository.Query("SELECT e FROM Enrollment e JOIN FETCH e.course c JOIN FETCH c.creator crt LEFT JOIN FETCH c.category LEFT JOIN FETCH c.difficulty WHERE crt.id = :creatorId ORDER BY e.enrolledAt DESC LIMIT 5")
    List<Enrollment> findTop5ByCourseCreatorIdOrderByEnrolledAtDesc(@org.springframework.data.repository.query.Param("creatorId") Long creatorId);

    List<Enrollment> findByCourseIdIn(List<Long> courseIds);

    @Query("SELECT COUNT(DISTINCT e.user.id) FROM Enrollment e WHERE e.course.id IN :courseIds")
    int countDistinctUsersByCourseIdIn(@Param("courseIds") List<Long> courseIds);

    @Query("SELECT e.course.id FROM Enrollment e WHERE e.user.id = :userId AND e.course.id IN :courseIds")
    List<Long> findEnrolledCourseIds(@Param("userId") Long userId, @Param("courseIds") List<Long> courseIds);

    @Query(value = "SELECT REGEXP_REPLACE(UPPER(c.code), '-V[0-9]+$', '') AS base_code, " +
            "COUNT(DISTINCT e.user_id) AS learners_count " +
            "FROM enrollments e " +
            "JOIN courses c ON c.id = e.course_id " +
            "WHERE c.code IS NOT NULL " +
            "AND REGEXP_REPLACE(UPPER(c.code), '-V[0-9]+$', '') IN (:baseCodes) " +
            "GROUP BY REGEXP_REPLACE(UPPER(c.code), '-V[0-9]+$', '')",
            nativeQuery = true)
    List<Object[]> countDistinctUsersByCourseBaseCodes(@Param("baseCodes") List<String> baseCodes);

    @Query("SELECT e.course.id, COUNT(DISTINCT e.user.id) FROM Enrollment e WHERE e.course.id IN :courseIds GROUP BY e.course.id")
    List<Object[]> countDistinctUsersByCourseIdsGrouped(@Param("courseIds") List<Long> courseIds);

    // ── Dashboard aggregate queries ──

    @Query("SELECT COUNT(DISTINCT e.user.id) FROM Enrollment e")
    long countDistinctEnrolledUsers();

    @Query("SELECT COUNT(DISTINCT e.user.id) FROM Enrollment e WHERE e.completedAt IS NOT NULL")
    long countDistinctUsersCompletedAnyCourse();

    @Query("SELECT COUNT(e) FROM Enrollment e WHERE e.completedAt IS NOT NULL")
    long countCompletedEnrollments();

    @Query(value = "SELECT DATE(e.enrolled_at) as day, COUNT(*) as cnt " +
           "FROM enrollments e WHERE e.enrolled_at >= :since " +
           "GROUP BY DATE(e.enrolled_at) ORDER BY day", nativeQuery = true)
    List<Object[]> getDailyEnrollmentsSince(@Param("since") LocalDateTime since);

    @Query(value = "SELECT COUNT(DISTINCT lp.user_id) FROM lesson_progresses lp " +
           "WHERE lp.completed_at IS NOT NULL AND lp.completed_at >= :since", nativeQuery = true)
    long countActiveLearnersSince(@Param("since") java.time.LocalDateTime since);

    @Query(value = "SELECT COUNT(*) FROM enrollments WHERE DATE(enrolled_at) = CURRENT_DATE", nativeQuery = true)
    long countEnrollmentsCreatedToday();
}
