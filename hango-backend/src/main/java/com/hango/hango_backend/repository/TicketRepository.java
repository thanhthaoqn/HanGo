package com.hango.hango_backend.repository;

import com.hango.hango_backend.entity.Ticket;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.util.Optional;

@Repository
public interface TicketRepository extends JpaRepository<Ticket, Long> {

    Optional<Ticket> findByTicketCode(String ticketCode);

    Page<Ticket> findByUserIdOrderByCreatedAtDesc(Long userId, Pageable pageable);

    Page<Ticket> findByUserIdAndStatusOrderByCreatedAtDesc(Long userId, String status, Pageable pageable);

    Page<Ticket> findByUserIdAndStatusInOrderByCreatedAtDesc(Long userId, java.util.Collection<String> statuses, Pageable pageable);

    @Query("SELECT t FROM Ticket t WHERE " +
           "(:status IS NULL OR " +
           " (:status = 'PROCESSED' AND t.status IN ('APPROVED', 'REJECTED')) OR " +
           " (:status <> 'PROCESSED' AND t.status = :status)) AND " +
           "(:category IS NULL OR t.category = :category) AND " +
           "(:keyword IS NULL OR LOWER(t.ticketCode) LIKE LOWER(CONCAT('%', :keyword, '%')) OR LOWER(t.title) LIKE LOWER(CONCAT('%', :keyword, '%')) OR LOWER(t.user.fullName) LIKE LOWER(CONCAT('%', :keyword, '%')) OR LOWER(t.user.email) LIKE LOWER(CONCAT('%', :keyword, '%'))) " +
           "ORDER BY t.createdAt DESC")
    Page<Ticket> findAllFiltered(
            @Param("status") String status,
            @Param("category") String category,
            @Param("keyword") String keyword,
            Pageable pageable
    );

    long countByStatus(String status);
    long countByUserId(Long userId);
    long countByUserIdAndStatus(Long userId, String status);
}
