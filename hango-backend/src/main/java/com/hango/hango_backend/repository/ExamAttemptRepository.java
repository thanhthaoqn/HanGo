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

    @org.springframework.data.jpa.repository.Query("SELECT COUNT(DISTINCT e.student.id) FROM ExamAttempt e WHERE e.exam.id = :examId")
    Long countDistinctStudentsByExamId(@org.springframework.data.repository.query.Param("examId") Long examId);

    @org.springframework.data.jpa.repository.Query("SELECT e.exam.id, COUNT(DISTINCT e.student.id) FROM ExamAttempt e WHERE e.exam.id IN :examIds GROUP BY e.exam.id")
    java.util.List<Object[]> countDistinctStudentsByExamIds(@org.springframework.data.repository.query.Param("examIds") java.util.List<Long> examIds);


    List<ExamAttempt> findByStudentIdOrderByStartedAtDesc(Long studentId);

    List<ExamAttempt> findByExamIdAndStudentIdOrderByStartedAtDesc(Long examId, Long studentId);

    int countByExamIdAndStudentIdAndStartedAtLessThanEqual(Long examId, Long studentId, java.time.LocalDateTime startedAt);

    // Lấy N attempts gần nhất của learner (theo submittedAt desc) để tổng hợp skill gaps.
    List<ExamAttempt> findTop10ByStudent_IdOrderBySubmittedAtDesc(Long studentId);
}

