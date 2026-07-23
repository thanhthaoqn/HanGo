package com.hango.hango_backend.repository;

import com.hango.hango_backend.entity.Payment;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;

@Repository
public interface PaymentRepository extends JpaRepository<Payment, Long> {
    Optional<Payment> findByTxnRef(String txnRef);
    List<Payment> findByUserIdAndCourseId(Long userId, Long courseId);
    boolean existsByUserIdAndCourseIdAndStatus(Long userId, Long courseId, String status);

    @org.springframework.data.jpa.repository.Query("SELECT SUM(p.amount) FROM Payment p WHERE p.course.creator.id = :trainerId AND p.status = 'SUCCESS'")
    java.math.BigDecimal sumRevenueByTrainerId(@org.springframework.data.repository.query.Param("trainerId") Long trainerId);

    List<Payment> findTop5ByCourseCreatorIdAndStatusOrderByCreatedAtDesc(Long creatorId, String status);

    @org.springframework.data.jpa.repository.Query(value = "SELECT MONTH(p.created_at) as month, SUM(p.amount) as revenue " +
                   "FROM payments p " +
                   "JOIN courses c ON p.course_id = c.id " +
                   "WHERE c.created_by = :trainerId AND p.status = 'SUCCESS' " +
                   "AND YEAR(p.created_at) = YEAR(CURRENT_DATE) " +
                   "GROUP BY MONTH(p.created_at)", 
           nativeQuery = true)
    List<Object[]> getRevenueByMonthForCurrentYear(@org.springframework.data.repository.query.Param("trainerId") Long trainerId);
}
