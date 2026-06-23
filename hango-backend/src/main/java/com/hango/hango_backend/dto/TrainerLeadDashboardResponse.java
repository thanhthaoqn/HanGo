package com.hango.hango_backend.dto;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class TrainerLeadDashboardResponse {
    private long totalUsers;
    private double percentageIncrease;
    private long totalCourses;
    private long activeCourses;
    private long inactiveCourses;
    private long assignedTasks;
    private long pendingApprovals;
}
