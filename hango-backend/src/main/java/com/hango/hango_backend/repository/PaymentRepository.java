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
    @org.springframework.data.jpa.repository.Query("SELECT SUM(p.amount) FROM Payment p WHERE p.course.creator.id = :trainerId AND p.status = 'SUCCESS'")
    java.math.BigDecimal sumRevenueByTrainerId(@org.springframework.data.repository.query.Param("trainerId") Long trainerId);

    @org.springframework.data.jpa.repository.EntityGraph(attributePaths = {"course", "course.creator", "course.category", "course.difficulty"})
    List<Payment> findTop5ByCourseCreatorIdAndStatusOrderByCreatedAtDesc(Long creatorId, String status);

    @org.springframework.data.jpa.repository.Query(value = "SELECT MONTH(p.created_at) as month, SUM(p.amount) as revenue " +
                   "FROM payments p " +
                   "JOIN courses c ON p.course_id = c.id " +
                   "WHERE c.created_by = :trainerId AND p.status = 'SUCCESS' " +
                   "AND YEAR(p.created_at) = YEAR(CURRENT_DATE) " +
                   "GROUP BY MONTH(p.created_at)", 
           nativeQuery = true)
    List<Object[]> getRevenueByMonthForCurrentYear(@org.springframework.data.repository.query.Param("trainerId") Long trainerId);

    List<Payment> findByCourseCreatorIdAndStatus(Long creatorId, String status);
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
           "ORDER BY p.createdAt DESC",
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
           "     OR LOWER(c.title) LIKE :search)")
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
           "ORDER BY p.createdAt DESC")
    List<Payment> findAllForManagerList(@Param("status") String status,
                                         @Param("settlementStatus") String settlementStatus,
                                         @Param("search") String search);

    List<Payment> findByStatementId(Long statementId);

    @org.springframework.data.jpa.repository.Modifying
    @Query("UPDATE Payment p SET p.settlementStatus = 'SETTLED' WHERE p.statementId IS NOT NULL AND (p.settlementStatus IS NULL OR UPPER(p.settlementStatus) != 'SETTLED') AND p.statementId IN (SELECT s.id FROM MonthlyStatement s WHERE UPPER(s.status) = 'PAID')")
    int syncSettledPaymentsForPaidStatements();
}





