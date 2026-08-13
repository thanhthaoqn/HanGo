package com.hango.hango_backend.repository;

import com.hango.hango_backend.entity.Exam;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import java.util.List;

@Repository
public interface ExamRepository extends JpaRepository<Exam, Long> {
    @org.springframework.data.jpa.repository.EntityGraph(attributePaths = {"createdBy"})
    List<Exam> findByDeletedAtIsNullAndStatus(String status);

    @org.springframework.data.jpa.repository.EntityGraph(attributePaths = {"createdBy"})
    List<Exam> findByCreatedByIdAndDeletedAtIsNullOrderByCreatedAtDesc(Long createdById);

    @Query("SELECT COUNT(e) FROM Exam e WHERE e.createdBy.id = :createdById AND e.deletedAt IS NULL")
    long countByCreatedByIdAndDeletedAtIsNull(@Param("createdById") Long createdById);

    @org.springframework.data.jpa.repository.EntityGraph(attributePaths = {"createdBy"})
    List<Exam> findByDeletedAtIsNullOrderByCreatedAtDesc();

    @org.springframework.data.jpa.repository.EntityGraph(attributePaths = {"createdBy"})
    List<Exam> findByStatusAndDeletedAtIsNullOrderByCreatedAtDesc(String status);

    @org.springframework.data.jpa.repository.EntityGraph(attributePaths = {"createdBy"})
    List<Exam> findByStatusInAndDeletedAtIsNullOrderByCreatedAtDesc(List<String> statuses);

    @Query("SELECT e.id, e.title, e.createdAt, e.expectedQuestionCount, e.durationMinutes, e.status, e.visibility, e.thumbnailUrl, e.description, e.passingScore, u.id, u.fullName " +
           "FROM Exam e LEFT JOIN e.createdBy u WHERE e.deletedAt IS NULL AND (u.id = :trainerId OR UPPER(e.status) != 'DRAFT') " +
           "ORDER BY e.createdAt DESC")
    List<Object[]> findTrainerExamsForManager(@Param("trainerId") Long trainerId);

    @Query("SELECT e.id, e.title, e.createdAt, e.expectedQuestionCount, e.durationMinutes, e.status, e.visibility, e.thumbnailUrl, e.description, e.passingScore, u.id, u.fullName " +
           "FROM Exam e LEFT JOIN e.createdBy u WHERE e.deletedAt IS NULL AND u.id = :trainerId " +
           "ORDER BY e.createdAt DESC")
    List<Object[]> findTrainerExamsForTrainer(@Param("trainerId") Long trainerId);

    // ── Dashboard aggregate queries ──

    @Query("SELECT e.status, COUNT(e) FROM Exam e WHERE e.deletedAt IS NULL GROUP BY e.status")
    List<Object[]> countGroupedByStatus();

    @Query("SELECT MIN(e.createdAt) FROM Exam e WHERE e.status = 'PENDING_APPROVAL' AND e.deletedAt IS NULL")
    java.time.LocalDateTime findOldestPendingExamDate();
}
