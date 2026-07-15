package com.hango.hango_backend.repository;

import com.hango.hango_backend.entity.ExamMatrixDetail;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;

@Repository
public interface ExamMatrixDetailRepository extends JpaRepository<ExamMatrixDetail, Long> {
    List<ExamMatrixDetail> findByMatrixId(Long matrixId);
}
