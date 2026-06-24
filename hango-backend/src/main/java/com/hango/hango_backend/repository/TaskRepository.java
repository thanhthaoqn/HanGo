package com.hango.hango_backend.repository;

import com.hango.hango_backend.entity.Task;
import com.hango.hango_backend.entity.TaskType;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.time.LocalDateTime;

@Repository
public interface TaskRepository extends JpaRepository<Task, Long> {

    @Query("SELECT t FROM Task t WHERE " +
           "(:assignedById IS NULL OR t.assignedBy.id = :assignedById) AND " +
           "(:assignedToId IS NULL OR t.assignedTo.id = :assignedToId) AND " +
           "(:type IS NULL OR t.type = :type) AND " +
           "(:fromDate IS NULL OR t.createdAt >= :fromDate) AND " +
           "(:toDate IS NULL OR t.createdAt <= :toDate) AND " +
           "(:search IS NULL OR LOWER(t.content) LIKE LOWER(CONCAT('%', :search, '%')))")
    Page<Task> findTasksWithFilters(
            @Param("assignedById") Long assignedById,
            @Param("assignedToId") Long assignedToId,
            @Param("type") TaskType type,
            @Param("fromDate") LocalDateTime fromDate,
            @Param("toDate") LocalDateTime toDate,
            @Param("search") String search,
            Pageable pageable);

    long countByAssignedToId(Long assignedToId);
}
