package com.hango.hango_backend.repository;

import com.hango.hango_backend.entity.ExamAttempt;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;

@Repository
public interface ExamAttemptRepository extends JpaRepository<ExamAttempt, Long> {
    int countByExamId(Long examId);
    List<ExamAttempt> findByExamIdAndStudentIdOrderBySubmittedAtAsc(Long examId, Long studentId);
    int countByExamIdAndStudentId(Long examId, Long studentId);
}
