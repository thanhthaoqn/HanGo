package com.hango.hango_backend.repository;

import com.hango.hango_backend.entity.MonthlyStatement;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;

@Repository
public interface MonthlyStatementRepository extends JpaRepository<MonthlyStatement, Long> {
    List<MonthlyStatement> findByTrainerIdOrderByPeriodMonthDesc(Long trainerId);
    Optional<MonthlyStatement> findByTrainerIdAndPeriodMonth(Long trainerId, String periodMonth);
    List<MonthlyStatement> findByPeriodMonth(String periodMonth);
    List<MonthlyStatement> findByPeriodMonthAndStatus(String periodMonth, String status);
    List<MonthlyStatement> findByStatus(String status);
    Optional<MonthlyStatement> findByStatementCode(String statementCode);
}
