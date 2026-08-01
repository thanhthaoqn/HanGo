package com.hango.hango_backend.repository;

import com.hango.hango_backend.entity.ExamMatrix;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;

@Repository
public interface ExamMatrixRepository extends JpaRepository<ExamMatrix, Long> {
    List<ExamMatrix> findAllByOrderByCreatedAtDesc();
    List<ExamMatrix> findAllByIsPublicTrueOrderByCreatedAtDesc();
}
