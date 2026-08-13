package com.hango.hango_backend.repository;

import com.hango.hango_backend.entity.AiUsageLog;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.time.LocalDateTime;
import java.util.List;

@Repository
public interface AiUsageLogRepository extends JpaRepository<AiUsageLog, Long> {
    long countBySuccess(boolean success);
    long countByCallType(String callType);
    List<AiUsageLog> findByCreatedAtAfter(LocalDateTime after);

    // ── Dashboard aggregate queries ──

    @org.springframework.data.jpa.repository.Query(value = "SELECT DATE(a.created_at) as day, " +
           "COUNT(*) as total_calls, SUM(CASE WHEN a.success = true THEN 1 ELSE 0 END) as success_calls, " +
           "SUM(CASE WHEN a.success = false THEN 1 ELSE 0 END) as failed_calls " +
           "FROM ai_usage_logs a WHERE a.created_at >= :since " +
           "GROUP BY DATE(a.created_at) ORDER BY day", nativeQuery = true)
    List<Object[]> getDailyUsageSince(@org.springframework.data.repository.query.Param("since") LocalDateTime since);

    @org.springframework.data.jpa.repository.Query(value = "SELECT a.user_id, u.full_name, COUNT(*) as call_count " +
           "FROM ai_usage_logs a JOIN users u ON a.user_id = u.id " +
           "GROUP BY a.user_id, u.full_name ORDER BY call_count DESC LIMIT 10", nativeQuery = true)
    List<Object[]> findTopUsersByUsage();

    @org.springframework.data.jpa.repository.Query("SELECT COALESCE(AVG(a.durationMs), 0) FROM AiUsageLog a WHERE a.success = true")
    Double avgSuccessDurationMs();
}
