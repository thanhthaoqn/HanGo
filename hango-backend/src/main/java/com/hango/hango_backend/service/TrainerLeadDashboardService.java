package com.hango.hango_backend.service;

import com.hango.hango_backend.dto.TrainerLeadDashboardStatsDto;
import jakarta.persistence.EntityManager;
import jakarta.persistence.PersistenceContext;
import jakarta.persistence.Query;
import org.springframework.stereotype.Service;

import java.math.BigDecimal;

@Service
public class TrainerLeadDashboardService {

    @PersistenceContext
    private EntityManager entityManager;

    public TrainerLeadDashboardStatsDto getDashboardStats() {
        // 1. Registered Users
        long registeredUsers = getCount("SELECT COUNT(*) FROM users");
        
        // Mocking user growth percentage for now as calculating it requires historical snapshots or complex queries
        double userGrowthPercentage = 12.5; 
        
        // 2. Courses
        long totalCourses = getCount("SELECT COUNT(*) FROM courses WHERE deleted_at IS NULL");
        long activeCourses = getCount("SELECT COUNT(*) FROM courses WHERE status != 'DRAFT' AND deleted_at IS NULL");
        long inactiveCourses = getCount("SELECT COUNT(*) FROM courses WHERE status = 'DRAFT' AND deleted_at IS NULL");
        
        // 3. Assigned Tasks
        long assignedTasks = getCount("SELECT COUNT(*) FROM tasks");
        
        // 4. Pending Approvals
        long pendingApprovals = getCount("SELECT COUNT(*) FROM creator_tasks WHERE status = 'SUBMITTED' OR status = 'PENDING'");

        return new TrainerLeadDashboardStatsDto(
                registeredUsers,
                userGrowthPercentage,
                totalCourses,
                activeCourses,
                inactiveCourses,
                assignedTasks,
                pendingApprovals
        );
    }

    private long getCount(String sql) {
        try {
            Query query = entityManager.createNativeQuery(sql);
            Object result = query.getSingleResult();
            if (result instanceof Number) {
                return ((Number) result).longValue();
            }
            return 0;
        } catch (Exception e) {
            return 0; // Return 0 if table doesn't exist yet or other error occurs
        }
    }
}
