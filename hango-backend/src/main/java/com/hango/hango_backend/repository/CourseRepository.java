package com.hango.hango_backend.repository;

import com.hango.hango_backend.entity.Course;
import com.hango.hango_backend.dto.CourseSummaryDTO;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.util.List;

@Repository
public interface CourseRepository extends JpaRepository<Course, Long> {

    @Query("SELECT new com.hango.hango_backend.dto.CourseSummaryDTO(" +
           "c.id, cat.paramValue, c.title, u.fullName, " +
           "CAST(COALESCE(AVG(cr.rating), 0.0) AS double), " +
           "COUNT(DISTINCT e.id), diff.paramKey, c.thumbnailUrl, " +
           "(SELECT e2.progressPercentage FROM Enrollment e2 WHERE e2.course.id = c.id AND e2.user.id = :enrolledUserId)) " +
           "FROM Course c " +
           "LEFT JOIN c.category cat " +
           "LEFT JOIN c.difficulty diff " +
           "LEFT JOIN c.creator u " +
           "LEFT JOIN CourseRating cr ON cr.course.id = c.id " +
           "LEFT JOIN Enrollment e ON e.course.id = c.id " +
           "WHERE c.status != 'DRAFT' " +
           "AND (:search IS NULL OR LOWER(c.title) LIKE LOWER(CONCAT('%', :search, '%'))) " +
           "AND (:difficulty IS NULL OR diff.paramKey = :difficulty) " +
           "AND (:enrolledUserId IS NULL OR EXISTS (SELECT 1 FROM Enrollment e2 WHERE e2.course.id = c.id AND e2.user.id = :enrolledUserId AND (:enrollmentStatus IS NULL OR e2.status = :enrollmentStatus))) " +
           "GROUP BY c.id, cat.paramValue, c.title, u.fullName, diff.paramKey, c.thumbnailUrl")
    List<CourseSummaryDTO> findCoursesWithFilters(@Param("search") String search,
                                                  @Param("difficulty") String difficulty,
                                                  @Param("enrolledUserId") Long enrolledUserId,
                                                  @Param("enrollmentStatus") String enrollmentStatus);

    @Query("SELECT COUNT(c) FROM Course c WHERE c.creator.id = :creatorId AND c.deletedAt IS NULL")
    long countByCreatorIdAndDeletedAtIsNull(@Param("creatorId") Long creatorId);

    @Query(value = "SELECT c.id AS id, c.title AS title, " +
           "(SELECT COUNT(e.id) FROM enrollments e WHERE e.course_id = c.id) AS learnersCount, " +
           "(SELECT COUNT(l.id) FROM lessons l JOIN sections s ON l.section_id = s.id WHERE s.course_id = c.id AND l.deleted_at IS NULL) AS lessonsCount, " +
           "c.thumbnail_url AS thumbnailUrl " +
           "FROM courses c " +
           "WHERE c.created_by = :trainerId AND c.deleted_at IS NULL " +
           "ORDER BY c.created_at DESC", 
           nativeQuery = true)
    List<TrainerCourseProjection> findTrainerCourses(@Param("trainerId") Long trainerId);

    @Query("SELECT COUNT(c) FROM Course c WHERE c.creator.id = :creatorId AND c.status = :status AND c.deletedAt IS NULL")
    long countByCreatorIdAndStatusAndDeletedAtIsNull(@Param("creatorId") Long creatorId, @Param("status") String status);

    @Query(value = "SELECT c.id AS id, c.title AS title, c.status AS status, c.description AS description, " +
           "(SELECT COUNT(e.id) FROM enrollments e WHERE e.course_id = c.id) AS learnersCount, " +
           "(SELECT COUNT(l.id) FROM lessons l JOIN sections s ON l.section_id = s.id WHERE s.course_id = c.id AND l.deleted_at IS NULL) AS lessonsCount, " +
           "c.thumbnail_url AS thumbnailUrl, c.created_at AS createdAt " +
           "FROM courses c " +
           "WHERE c.created_by = :trainerId AND c.deleted_at IS NULL " +
           "AND (:status = 'ALL' OR c.status = :status) " +
           "AND (:search IS NULL OR LOWER(c.title) LIKE LOWER(CONCAT('%', :search, '%')))",
           nativeQuery = true)
    List<TrainerCourseDetailProjection> findTrainerCoursesDetailBase(@Param("trainerId") Long trainerId,
                                                                     @Param("status") String status,
                                                                     @Param("search") String search);
}
