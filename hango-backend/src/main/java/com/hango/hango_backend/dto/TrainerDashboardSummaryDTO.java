package com.hango.hango_backend.dto;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;
import java.util.List;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class TrainerDashboardSummaryDTO {
    private long coursesCount;
    private long learnersCount;
    private long salesCount;
    private java.math.BigDecimal totalRevenue;
    private Double averageRating;
    private List<TrainerCourseDTO> courses;
    private List<RecentActivityDTO> recentActivities;
    private List<MonthlyRevenueDTO> monthlyRevenues;
}
