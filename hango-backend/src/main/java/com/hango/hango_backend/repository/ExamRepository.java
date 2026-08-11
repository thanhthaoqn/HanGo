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

    List<Exam> findByCreatedByIdAndDeletedAtIsNullOrderByCreatedAtDesc(Long createdById);

    @Query("SELECT COUNT(e) FROM Exam e WHERE e.createdBy.id = :createdById AND e.deletedAt IS NULL")
    long countByCreatedByIdAndDeletedAtIsNull(@Param("createdById") Long createdById);

    @org.springframework.data.jpa.repository.EntityGraph(attributePaths = {"createdBy"})
    List<Exam> findByDeletedAtIsNullOrderByCreatedAtDesc();

    @org.springframework.data.jpa.repository.EntityGraph(attributePaths = {"createdBy"})
    List<Exam> findByStatusAndDeletedAtIsNullOrderByCreatedAtDesc(String status);

    @org.springframework.data.jpa.repository.EntityGraph(attributePaths = {"createdBy"})
    List<Exam> findByStatusInAndDeletedAtIsNullOrderByCreatedAtDesc(List<String> statuses);
}
