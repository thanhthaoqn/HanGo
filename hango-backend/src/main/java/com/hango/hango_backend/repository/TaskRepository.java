package com.hango.hango_backend.repository;

import com.hango.hango_backend.entity.Task;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.time.LocalDateTime;

@Repository
public interface TaskRepository extends JpaRepository<Task, Long> {

       @Query("SELECT DISTINCT t FROM Task t " +
                     "WHERE (:leadId IS NULL OR t.lead.id = :leadId) AND " +
                     "(:creatorId IS NULL OR t.assignee.id = :creatorId) AND " +
                     "(:fromDate IS NULL OR t.createdAt >= :fromDate) AND " +
                     "(:toDate IS NULL OR t.createdAt <= :toDate) AND " +
                     "(:search IS NULL OR LOWER(t.title) LIKE LOWER(CONCAT('%', :search, '%')))")
       Page<Task> findTasksWithFilters(
                     @Param("leadId") Long leadId,
                     @Param("creatorId") Long creatorId,
                     @Param("fromDate") LocalDateTime fromDate,
                     @Param("toDate") LocalDateTime toDate,
                     @Param("search") String search,
                     Pageable pageable);
}
