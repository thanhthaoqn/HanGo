package com.hango.hango_backend.repository;

import com.hango.hango_backend.entity.Exam;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;

@Repository
public interface ExamRepository extends JpaRepository<Exam, Long> {
    List<Exam> findByDeletedAtIsNullAndStatus(String status);
}
