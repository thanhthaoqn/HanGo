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

    // ── Dashboard aggregate queries ──

    @org.springframework.data.jpa.repository.Query("SELECT COALESCE(AVG(e.score), 0) FROM ExamAttempt e WHERE e.submittedAt IS NOT NULL")
    Double avgScore();

    @org.springframework.data.jpa.repository.Query("SELECT COUNT(e) FROM ExamAttempt e WHERE e.submittedAt IS NOT NULL AND COALESCE(e.score, 0.0) >= COALESCE(e.exam.passingScore, 5.0)")
    long countPassedAttempts();

    @org.springframework.data.jpa.repository.Query("SELECT COUNT(e) FROM ExamAttempt e WHERE e.submittedAt IS NOT NULL")
    long countSubmittedAttempts();

    @org.springframework.data.jpa.repository.Query(value = "SELECT DATE(ea.submitted_at) as day, COUNT(*) as cnt " +
           "FROM exam_attempts ea WHERE ea.submitted_at IS NOT NULL AND ea.submitted_at >= :since " +
           "GROUP BY DATE(ea.submitted_at) ORDER BY day", nativeQuery = true)
    List<Object[]> getDailyAttemptsSince(@org.springframework.data.repository.query.Param("since") java.time.LocalDateTime since);

    @org.springframework.data.jpa.repository.Query(value = "SELECT ea.exam_id, e.title, COUNT(*) as attempt_count, AVG(ea.score) as avg_score " +
           "FROM exam_attempts ea JOIN exams e ON ea.exam_id = e.id " +
           "WHERE ea.submitted_at IS NOT NULL " +
           "GROUP BY ea.exam_id, e.title ORDER BY attempt_count DESC LIMIT 5", nativeQuery = true)
    List<Object[]> findTopExamsByAttemptCount();

    @org.springframework.data.jpa.repository.Query(value = "SELECT ea.exam_id, e.title, AVG(ea.score) as avg_score, COUNT(*) as attempt_count " +
           "FROM exam_attempts ea JOIN exams e ON ea.exam_id = e.id " +
           "WHERE ea.submitted_at IS NOT NULL " +
           "GROUP BY ea.exam_id, e.title ORDER BY avg_score ASC LIMIT 5", nativeQuery = true)
    List<Object[]> findHardestExams();

    @org.springframework.data.jpa.repository.Query(value = "SELECT COUNT(*) FROM exam_attempts WHERE DATE(started_at) = CURRENT_DATE", nativeQuery = true)
    long countExamAttemptsToday();
}
