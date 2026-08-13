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

    // ── Dashboard aggregate queries ──

    @Query("SELECT t.category, COUNT(t) FROM Ticket t GROUP BY t.category")
    java.util.List<Object[]> countByCategory();

    @Query("SELECT t.status, COUNT(t) FROM Ticket t GROUP BY t.status")
    java.util.List<Object[]> countGroupedByStatus();

    @Query(value = "SELECT AVG(TIMESTAMPDIFF(HOUR, t.created_at, tm.created_at)) " +
           "FROM tickets t JOIN ticket_messages tm ON tm.ticket_id = t.id " +
           "WHERE tm.sender_id != t.user_id " +
           "AND tm.id = (SELECT MIN(tm2.id) FROM ticket_messages tm2 WHERE tm2.ticket_id = t.id AND tm2.sender_id != t.user_id)",
           nativeQuery = true)
    Double avgFirstResponseHours();

    @Query(value = "SELECT AVG(TIMESTAMPDIFF(HOUR, t.created_at, t.processed_at)) " +
           "FROM tickets t WHERE t.processed_at IS NOT NULL", nativeQuery = true)
    Double avgResolutionHours();
}
