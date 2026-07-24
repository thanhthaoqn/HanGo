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
}
