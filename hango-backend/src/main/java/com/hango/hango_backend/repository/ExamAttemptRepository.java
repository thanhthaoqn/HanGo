package com.hango.hango_backend.repository;

import com.hango.hango_backend.entity.ExamAttempt;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

@Repository
public interface ExamAttemptRepository extends JpaRepository<ExamAttempt, Long> {
    int countByExamId(Long examId);
}
