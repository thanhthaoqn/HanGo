package com.hango.hango_backend.repository;

import com.hango.hango_backend.entity.Payment;
import jakarta.persistence.LockModeType;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Lock;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.time.LocalDateTime;
import java.util.List;
import java.util.Optional;

@Repository
public interface PaymentRepository extends JpaRepository<Payment, Long> {
    Optional<Payment> findByTxnRef(String txnRef);

    @Lock(LockModeType.PESSIMISTIC_WRITE)
    @Query("SELECT p FROM Payment p WHERE p.txnRef = :txnRef")
    Optional<Payment> findByTxnRefWithLock(@Param("txnRef") String txnRef);

    List<Payment> findByUserIdAndCourseId(Long userId, Long courseId);
    List<Payment> findByUserIdOrderByCreatedAtDesc(Long userId);

    Page<Payment> findByUserIdOrderByCreatedAtDesc(Long userId, Pageable pageable);
    Page<Payment> findByUserIdAndStatusOrderByCreatedAtDesc(Long userId, String status, Pageable pageable);

    List<Payment> findByStatusAndCreatedAtBefore(String status, LocalDateTime cutoffTime);

    boolean existsByUserIdAndCourseIdAndStatus(Long userId, Long courseId, String status);
    @org.springframework.data.jpa.repository.Query("SELECT SUM(COALESCE(p.trainerEarnings, 0)) FROM Payment p WHERE p.course.creator.id = :trainerId AND p.status = 'SUCCESS'")
    java.math.BigDecimal sumRevenueByTrainerId(@org.springframework.data.repository.query.Param("trainerId") Long trainerId);

    @org.springframework.data.jpa.repository.Query("SELECT p FROM Payment p JOIN FETCH p.course c JOIN FETCH c.creator crt LEFT JOIN FETCH c.category LEFT JOIN FETCH c.difficulty WHERE crt.id = :creatorId AND p.status = :status ORDER BY p.createdAt DESC LIMIT 20")
    List<Payment> findTop20ByCourseCreatorIdAndStatusOrderByCreatedAtDesc(@org.springframework.data.repository.query.Param("creatorId") Long creatorId, @org.springframework.data.repository.query.Param("status") String status);

    @org.springframework.data.jpa.repository.Query(value = "SELECT MONTH(p.created_at) as month, SUM(IFNULL(p.trainer_earnings, 0)) as revenue " +
                   "FROM payments p " +
                   "JOIN courses c ON p.course_id = c.id " +
                   "WHERE c.created_by = :trainerId AND p.status = 'SUCCESS' " +
                   "AND YEAR(p.created_at) = YEAR(CURRENT_DATE) " +
                   "GROUP BY MONTH(p.created_at)", 
           nativeQuery = true)
    List<Object[]> getRevenueByMonthForCurrentYear(@org.springframework.data.repository.query.Param("trainerId") Long trainerId);

    @org.springframework.data.jpa.repository.Query(value = "SELECT MONTH(p.created_at) as month, SUM(IFNULL(p.trainer_earnings, 0)) as revenue " +
                   "FROM payments p " +
                   "JOIN courses c ON p.course_id = c.id " +
                   "WHERE c.created_by = :trainerId AND p.status = 'SUCCESS' " +
                   "AND YEAR(p.created_at) = :year " +
                   "GROUP BY MONTH(p.created_at)", 
           nativeQuery = true)
    List<Object[]> getRevenueByMonthForYear(@org.springframework.data.repository.query.Param("trainerId") Long trainerId, @org.springframework.data.repository.query.Param("year") int year);

    @org.springframework.data.jpa.repository.Query(value = "SELECT DATE(p.created_at) as date, SUM(IFNULL(p.trainer_earnings, 0)) as revenue " +
                   "FROM payments p " +
                   "JOIN courses c ON p.course_id = c.id " +
                   "WHERE c.created_by = :trainerId AND p.status = 'SUCCESS' " +
                   "AND p.created_at >= :startDate AND p.created_at < :endDate " +
                   "GROUP BY DATE(p.created_at)", 
           nativeQuery = true)
    List<Object[]> getRevenueByDay(@org.springframework.data.repository.query.Param("trainerId") Long trainerId, @org.springframework.data.repository.query.Param("startDate") java.time.LocalDateTime startDate, @org.springframework.data.repository.query.Param("endDate") java.time.LocalDateTime endDate);

    List<Payment> findByCourseCreatorIdAndStatus(Long creatorId, String status);
    long countByCourseCreatorIdAndStatus(Long creatorId, String status);

    @org.springframework.data.jpa.repository.Modifying
    @org.springframework.data.jpa.repository.Query(value = "INSERT INTO payments (amount, created_at, status, course_id, user_id, trainer_earnings, platform_fee, settlement_status, txn_ref) VALUES (:amount, :createdAt, :status, :courseId, :userId, :trainerEarnings, :platformFee, :settlementStatus, :txnRef)", nativeQuery = true)
    void insertMockPayment(@org.springframework.data.repository.query.Param("amount") java.math.BigDecimal amount, @org.springframework.data.repository.query.Param("createdAt") java.time.LocalDateTime createdAt, @org.springframework.data.repository.query.Param("status") String status, @org.springframework.data.repository.query.Param("courseId") Long courseId, @org.springframework.data.repository.query.Param("userId") Long userId, @org.springframework.data.repository.query.Param("trainerEarnings") java.math.BigDecimal trainerEarnings, @org.springframework.data.repository.query.Param("platformFee") java.math.BigDecimal platformFee, @org.springframework.data.repository.query.Param("settlementStatus") String settlementStatus, @org.springframework.data.repository.query.Param("txnRef") String txnRef);

    @Query(value = "SELECT p.trainer_earnings, p.amount, p.settlement_status, p.created_at " +
           "FROM payments p JOIN courses c ON p.course_id = c.id " +
           "WHERE c.created_by = :trainerId AND p.status = 'SUCCESS'",
           nativeQuery = true)
    List<Object[]> findRevenueDataByTrainerId(@Param("trainerId") Long trainerId);
    List<Payment> findByCourseCreatorIdAndStatusAndSettlementStatus(Long creatorId, String status, String settlementStatus);

    @Query(value = "SELECT p FROM Payment p LEFT JOIN p.user u LEFT JOIN p.course c " +
           "WHERE (:status IS NULL OR :status = '' OR UPPER(p.status) = UPPER(:status)) " +
           "AND (:settlementStatus IS NULL OR :settlementStatus = '' " +
           "     OR (:settlementStatus = 'PENDING' AND (p.statementId IS NULL OR UPPER(p.settlementStatus) = 'PENDING')) " +
           "     OR (:settlementStatus = 'IN_STATEMENT' AND p.statementId IS NOT NULL AND UPPER(p.settlementStatus) != 'SETTLED') " +
           "     OR (:settlementStatus = 'SETTLED' AND UPPER(p.settlementStatus) = 'SETTLED')) " +
           "AND (:search IS NULL OR :search = '' " +
           "     OR LOWER(p.txnRef) LIKE :search " +
           "     OR LOWER(u.fullName) LIKE :search " +
           "     OR LOWER(u.email) LIKE :search " +
           "     OR LOWER(c.title) LIKE :search) " +
           "ORDER BY COALESCE(p.paidAt, p.createdAt) DESC, p.id DESC",
           countQuery = "SELECT COUNT(p) FROM Payment p LEFT JOIN p.user u LEFT JOIN p.course c " +
           "WHERE (:status IS NULL OR :status = '' OR UPPER(p.status) = UPPER(:status)) " +
           "AND (:settlementStatus IS NULL OR :settlementStatus = '' " +
           "     OR (:settlementStatus = 'PENDING' AND (p.statementId IS NULL OR UPPER(p.settlementStatus) = 'PENDING')) " +
           "     OR (:settlementStatus = 'IN_STATEMENT' AND p.statementId IS NOT NULL AND UPPER(p.settlementStatus) != 'SETTLED') " +
           "     OR (:settlementStatus = 'SETTLED' AND UPPER(p.settlementStatus) = 'SETTLED')) " +
           "AND (:search IS NULL OR :search = '' " +
           "     OR LOWER(p.txnRef) LIKE :search " +
           "     OR LOWER(u.fullName) LIKE :search " +
           "     OR LOWER(u.email) LIKE :search " +
           "     OR LOWER(c.title) LIKE :search) " +
           "ORDER BY COALESCE(p.paidAt, p.createdAt) DESC, p.id DESC")
    Page<Payment> findAllForManager(@Param("status") String status,
                                     @Param("settlementStatus") String settlementStatus,
                                     @Param("search") String search,
                                     Pageable pageable);

    @Query("SELECT p FROM Payment p LEFT JOIN p.user u LEFT JOIN p.course c " +
           "WHERE (:status IS NULL OR :status = '' OR UPPER(p.status) = UPPER(:status)) " +
           "AND (:settlementStatus IS NULL OR :settlementStatus = '' " +
           "     OR (:settlementStatus = 'PENDING' AND (p.statementId IS NULL OR UPPER(p.settlementStatus) = 'PENDING')) " +
           "     OR (:settlementStatus = 'IN_STATEMENT' AND p.statementId IS NOT NULL AND UPPER(p.settlementStatus) != 'SETTLED') " +
           "     OR (:settlementStatus = 'SETTLED' AND UPPER(p.settlementStatus) = 'SETTLED')) " +
           "AND (:search IS NULL OR :search = '' " +
           "     OR LOWER(p.txnRef) LIKE :search " +
           "     OR LOWER(u.fullName) LIKE :search " +
           "     OR LOWER(u.email) LIKE :search " +
           "     OR LOWER(c.title) LIKE :search) " +
           "ORDER BY COALESCE(p.paidAt, p.createdAt) DESC, p.id DESC")
    List<Payment> findAllForManagerList(@Param("status") String status,
                                         @Param("settlementStatus") String settlementStatus,
                                         @Param("search") String search);

    List<Payment> findByStatementId(Long statementId);

    @org.springframework.data.jpa.repository.Modifying
    @Query("UPDATE Payment p SET p.settlementStatus = 'SETTLED' WHERE p.statementId IS NOT NULL AND (p.settlementStatus IS NULL OR UPPER(p.settlementStatus) != 'SETTLED') AND p.statementId IN (SELECT s.id FROM MonthlyStatement s WHERE UPPER(s.status) = 'PAID')")
    int syncSettledPaymentsForPaidStatements();

    // ── Dashboard aggregate queries ──

    @Query("SELECT COALESCE(SUM(p.amount), 0) FROM Payment p WHERE p.status = 'SUCCESS'")
    java.math.BigDecimal sumTotalRevenue();

    @Query("SELECT COALESCE(SUM(p.platformFee), 0) FROM Payment p WHERE p.status = 'SUCCESS'")
    java.math.BigDecimal sumTotalPlatformFee();

    @Query("SELECT COALESCE(SUM(p.trainerEarnings), 0) FROM Payment p WHERE p.status = 'SUCCESS'")
    java.math.BigDecimal sumTotalTrainerEarnings();

    @Query("SELECT COUNT(p) FROM Payment p WHERE p.status = 'SUCCESS'")
    long countSuccessful();

    @Query("SELECT COALESCE(SUM(p.amount), 0) FROM Payment p WHERE p.status = 'SUCCESS' AND p.createdAt >= :since")
    java.math.BigDecimal sumRevenueSince(@Param("since") LocalDateTime since);

    @Query("SELECT COALESCE(SUM(p.amount), 0) FROM Payment p WHERE p.status = 'SUCCESS' AND p.createdAt >= :start AND p.createdAt < :end")
    java.math.BigDecimal sumRevenueBetween(@Param("start") LocalDateTime start, @Param("end") LocalDateTime end);

    @Query(value = "SELECT DATE_FORMAT(p.created_at, '%Y-%m') as month, " +
           "SUM(p.amount) as total_revenue, " +
           "SUM(p.platform_fee) as platform_fee, " +
           "SUM(p.trainer_earnings) as trainer_earnings, " +
           "COUNT(*) as tx_count " +
           "FROM payments p WHERE p.status = 'SUCCESS' " +
           "GROUP BY DATE_FORMAT(p.created_at, '%Y-%m') " +
           "ORDER BY month DESC LIMIT :limit", nativeQuery = true)
    List<Object[]> getMonthlyRevenueBreakdown(@Param("limit") int limit);

    @Query(value = "SELECT DATE(p.created_at) as day, SUM(p.amount) as revenue, COUNT(*) as tx_count " +
           "FROM payments p WHERE p.status = 'SUCCESS' AND p.created_at >= :since " +
           "GROUP BY DATE(p.created_at) ORDER BY day", nativeQuery = true)
    List<Object[]> getDailyRevenueSince(@Param("since") LocalDateTime since);

    @Query("SELECT COUNT(p) FROM Payment p WHERE p.status = 'SUCCESS' AND p.course.price = 0")
    long countFreeEnrollmentPayments();
}





