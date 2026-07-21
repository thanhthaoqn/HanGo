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
}
