package com.hango.hango_backend.repository;

import com.hango.hango_backend.entity.ExamHistoryLog;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;

public interface ExamHistoryLogRepository extends JpaRepository<ExamHistoryLog, Long> {
    List<ExamHistoryLog> findByExamIdOrderByCreatedAtAsc(Long examId);
}
