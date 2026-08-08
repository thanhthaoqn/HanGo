package com.hango.hango_backend.repository;

import com.hango.hango_backend.entity.Course;
import com.hango.hango_backend.dto.CourseSummaryDTO;
import org.springframework.data.jpa.repository.EntityGraph;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;

@Repository
public interface CourseRepository extends JpaRepository<Course, Long> {

    @Query("SELECT new com.hango.hango_backend.dto.CourseSummaryDTO(" +
           "c.id, cat.paramValue, c.title, u.fullName, " +
           "CAST(COALESCE((SELECT AVG(cr.rating) FROM CourseRating cr WHERE cr.course.id = c.id OR cr.course.parentId = c.id OR cr.course.id = c.parentId OR (c.parentId IS NOT NULL AND cr.course.parentId = c.parentId)), 0.0) AS double), " +
           "(SELECT COUNT(DISTINCT e.id) FROM Enrollment e WHERE e.course.id = c.id OR e.course.parentId = c.id OR e.course.id = c.parentId OR (c.parentId IS NOT NULL AND e.course.parentId = c.parentId)), " +
           "diff.paramKey, c.thumbnailUrl, c.price, " +
           "(SELECT e2.progressPercentage FROM Enrollment e2 WHERE e2.course.id = c.id AND e2.user.id = :enrolledUserId)) " +
           "FROM Course c " +
           "LEFT JOIN c.category cat " +
           "LEFT JOIN c.difficulty diff " +
           "LEFT JOIN c.creator u " +
           "WHERE (c.status = 'PUBLISHED' OR (:enrolledUserId IS NOT NULL AND c.status IN ('HIDDEN', 'ARCHIVED'))) AND c.deletedAt IS NULL " +
           "AND (:search IS NULL OR LOWER(c.title) LIKE LOWER(CONCAT('%', :search, '%'))) " +
           "AND (:difficulty IS NULL OR diff.paramKey = :difficulty) " +
           "AND (:enrolledUserId IS NULL OR EXISTS (SELECT 1 FROM Enrollment e2 WHERE e2.course.id = c.id AND e2.user.id = :enrolledUserId AND (:enrollmentStatus IS NULL OR e2.status = :enrollmentStatus))) " +
           "AND ((c.latestVersionId = c.id OR c.latestVersionId IS NULL) " +
           "     OR (:enrolledUserId IS NOT NULL AND EXISTS (SELECT 1 FROM Enrollment e3 WHERE e3.course.id = c.id AND e3.user.id = :enrolledUserId)))")
    List<CourseSummaryDTO> findCoursesWithFilters(@Param("search") String search,
                                                  @Param("difficulty") String difficulty,
                                                  @Param("enrolledUserId") Long enrolledUserId,
                                                  @Param("enrollmentStatus") String enrollmentStatus);

    @Query("SELECT c.id, cat.paramValue FROM Course c JOIN c.categories cat WHERE c.id IN :courseIds")
    List<Object[]> findCategoriesByCourseIds(@Param("courseIds") List<Long> courseIds);

    @Query("SELECT c.id, cat.paramKey, cat.paramValue FROM Course c JOIN c.categories cat WHERE c.id IN :courseIds")
    List<Object[]> findCategoryDetailsByCourseIds(@Param("courseIds") List<Long> courseIds);

    @Query("SELECT c.id, c.category.paramKey, c.category.paramValue FROM Course c WHERE c.id IN :courseIds AND c.category IS NOT NULL")
    List<Object[]> findSingleCategoryDetailsByCourseIds(@Param("courseIds") List<Long> courseIds);

    @Query("SELECT c FROM Course c WHERE c.code = :code AND c.status = 'PUBLISHED' ORDER BY COALESCE(c.publishedAt, c.createdAt) DESC")
    List<Course> findPublishedByCodeOrderByPublishedAtDesc(@Param("code") String code);

    Optional<Course> findFirstByCodeAndStatusOrderByPublishedAtDesc(String code, String status);

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
           "c.thumbnail_url AS thumbnailUrl, c.created_at AS createdAt, " +
           "c.code AS code, c.version AS version, c.parent_id AS parentId, c.rejection_reason AS rejectionReason, " +
           "c.price AS price, c.suggested_price AS suggestedPrice, c.price_note AS priceNote " +
           "FROM courses c " +
           "WHERE c.created_by = :trainerId AND c.deleted_at IS NULL " +
           "AND (:status = 'ALL' OR c.status = :status) " +
           "AND (:search IS NULL OR LOWER(c.title) LIKE LOWER(CONCAT('%', :search, '%')))",
           nativeQuery = true)
    List<TrainerCourseDetailProjection> findTrainerCoursesDetailBase(@Param("trainerId") Long trainerId,
                                                                     @Param("status") String status,
                                                                     @Param("search") String search);

    long countByStatus(String status);

    @Query(value = "SELECT c.id AS id, c.title AS title, COUNT(e.id) AS enrollmentCount " +
           "FROM courses c LEFT JOIN enrollments e ON e.course_id = c.id " +
           "WHERE c.deleted_at IS NULL " +
           "GROUP BY c.id, c.title " +
           "ORDER BY enrollmentCount DESC " +
           "LIMIT :limit",
           nativeQuery = true)
    List<TopCourseProjection> findTopCoursesByEnrollment(@Param("limit") int limit);

    @EntityGraph(attributePaths = {"creator", "category", "difficulty"})
    List<Course> findByStatusAndDeletedAtIsNullOrderByCreatedAtDesc(String status);

    @EntityGraph(attributePaths = {"creator", "category", "difficulty"})
    List<Course> findByDeletedAtIsNullOrderByCreatedAtDesc();

    long countByStatusAndDeletedAtIsNull(String status);

    boolean existsByCodeIgnoreCase(String code);
    boolean existsByCodeIgnoreCaseAndIdNot(String code, Long id);
    boolean existsByTitleIgnoreCase(String title);

    List<Course> findByCodeAndDeletedAtIsNullOrderByCreatedAtDesc(String code);

    List<Course> findByParentIdAndDeletedAtIsNullOrderByCreatedAtDesc(Long parentId);

    Optional<Course> findByIdAndParentIdIsNullAndDeletedAtIsNull(Long id);

    @EntityGraph(attributePaths = {"categories", "category", "difficulty", "creator"})
    @Query("SELECT c FROM Course c WHERE c.id = :id")
    Optional<Course> findByIdWithDetails(@Param("id") Long id);

    @EntityGraph(attributePaths = {"categories", "category", "difficulty", "creator"})
    @Query("SELECT c FROM Course c WHERE c.id IN :ids")
    List<Course> findAllByIdWithDetails(@Param("ids") List<Long> ids);

    @org.springframework.data.jpa.repository.Modifying
    @Query("UPDATE Course c SET c.averageRating = :average, c.totalRatings = :total WHERE c.id = :courseId")
    void updateCourseStats(@Param("courseId") Long courseId, @Param("average") Double average, @Param("total") Integer total);
}
