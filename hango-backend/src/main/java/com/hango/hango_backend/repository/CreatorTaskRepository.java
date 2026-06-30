package com.hango.hango_backend.repository;

import com.hango.hango_backend.entity.CreatorTask;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.time.LocalDateTime;

@Repository
public interface CreatorTaskRepository extends JpaRepository<CreatorTask, Long> {

    @Query("SELECT ct FROM CreatorTask ct " +
           "JOIN FETCH ct.task t " +
           "JOIN FETCH ct.creator c " +
           "LEFT JOIN FETCH ct.reviewer r " +
           "WHERE t.lead.id = :leadId " +
           "AND (:fromDate IS NULL OR t.createdAt >= :fromDate) " +
           "AND (:toDate IS NULL OR t.createdAt <= :toDate) " +
           "AND (:type IS NULL OR :type = 'All type' OR t.type = :type) " +
           "AND (:search IS NULL OR LOWER(t.title) LIKE LOWER(CONCAT('%', :search, '%')))")
    Page<CreatorTask> findTasksForLead(
            @Param("leadId") Long leadId,
            @Param("fromDate") LocalDateTime fromDate,
            @Param("toDate") LocalDateTime toDate,
            @Param("type") String type,
            @Param("search") String search,
            Pageable pageable
    );
}
