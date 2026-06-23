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
           "COUNT(DISTINCT e.id), diff.paramKey, c.thumbnailUrl) " +
           "FROM Course c " +
           "LEFT JOIN c.category cat " +
           "LEFT JOIN c.difficulty diff " +
           "LEFT JOIN c.creator u " +
           "LEFT JOIN CourseRating cr ON cr.course.id = c.id " +
           "LEFT JOIN Enrollment e ON e.course.id = c.id " +
           "WHERE c.status != 'DRAFT' " +
           "AND (:search IS NULL OR LOWER(c.title) LIKE LOWER(CONCAT('%', :search, '%'))) " +
           "AND (:difficulty IS NULL OR diff.paramKey = :difficulty) " +
           "AND (:enrolledUserId IS NULL OR EXISTS (SELECT 1 FROM Enrollment e2 WHERE e2.course.id = c.id AND e2.user.id = :enrolledUserId)) " +
           "GROUP BY c.id, cat.paramValue, c.title, u.fullName, diff.paramKey, c.thumbnailUrl")
    List<CourseSummaryDTO> findCoursesWithFilters(@Param("search") String search,
                                                  @Param("difficulty") String difficulty,
                                                  @Param("enrolledUserId") Long enrolledUserId);
    long countByStatus(String status);
}
