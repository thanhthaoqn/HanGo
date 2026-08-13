package com.hango.hango_backend.dto.admin;

import lombok.Builder;
import lombok.Data;

import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.util.List;
import java.util.Map;

@Data
@Builder
public class DashboardStatsDTO {

    private Overview overview;
    private Revenue revenue;
    private ContentHealth contentHealth;
    private LearningPerformance learningPerformance;
    private TicketHealth ticketHealth;
    private AiUsage aiUsage;
    private Trends trends;
    private PendingActions pendingActions;
    private List<RecentActivity> recentActivity;

    @Data
    @Builder
    public static class Overview {
        private long totalActiveUsers;
        private long totalLearners;
        private long totalTrainers;
        private long totalCourseManagers;
        private long totalAdmins;
        
        private long totalPublishedCourses;
        private long totalFreeCourses;
        private long totalPaidCourses;
        
        private long totalEnrollments;
        private long totalExamAttempts;
        private long totalCertificates;
        
        private long newUsersToday;
        private long newEnrollmentsToday;
        private long newCoursesToday;
        private long newExamAttemptsToday;
    }

    @Data
    @Builder
    public static class Revenue {
        private BigDecimal totalRevenue;
        private BigDecimal platformFee;
        private BigDecimal trainerEarnings;
        private BigDecimal avgTransactionValue;
        private long transactionCount;
        private List<MonthlyRevenue> revenueByMonth;
    }

    @Data
    @Builder
    public static class MonthlyRevenue {
        private String month;
        private BigDecimal total;
        private BigDecimal platformFee;
        private BigDecimal trainerEarnings;
        private long txCount;
    }

    @Data
    @Builder
    public static class ContentHealth {
        private Map<String, Long> coursesByStatus;
        private Map<String, Long> examsByStatus;
        private Map<String, Long> trainerAppsByStatus;
        private Double avgCourseRating;
        private long lowRatingCourseCount;
        private Double approvalRate;
        private LocalDateTime oldestPendingCourseDate;
        private LocalDateTime oldestPendingTrainerAppDate;
        private LocalDateTime oldestPendingExamDate;
    }

    @Data
    @Builder
    public static class LearningPerformance {
        private Double completionRate;
        private Double avgExamScore;
        private Double examPassRate;
        private long activeLearners30d;
        private LearningFunnel learningFunnel;
    }

    @Data
    @Builder
    public static class LearningFunnel {
        private long registered;
        private long enrolledAtLeast1;
        private long activelyLearning;
        private long completedAtLeast1Course;
        private long certified;
    }

    @Data
    @Builder
    public static class TicketHealth {
        private Map<String, Long> byStatus;
        private Map<String, Long> byCategory;
        private Double avgFirstResponseHours;
        private Double avgResolutionHours;
        private Double slaComplianceRate;
    }

    @Data
    @Builder
    public static class AiUsage {
        private long totalCalls;
        private long chatCalls;
        private long embeddingCalls;
        private Double successRate;
        private Double avgSuccessDurationMs;
        private List<DailyAiUsage> callsByDay;
        private List<TopAiUser> topUsers;
    }

    @Data
    @Builder
    public static class DailyAiUsage {
        private String date; // "yyyy-MM-dd"
        private long count;
        private long success;
        private long failed;
    }

    @Data
    @Builder
    public static class TopAiUser {
        private Long userId;
        private String fullName;
        private long callCount;
    }

    @Data
    @Builder
    public static class Trends {
        private List<DailyUserGrowth> userGrowthByDay;
        private List<DailyRevenue> revenueByDay;
    }

    @Data
    @Builder
    public static class DailyUserGrowth {
        private String date;
        private long newUsers;
        private long newEnrollments;
    }

    @Data
    @Builder
    public static class DailyRevenue {
        private String date;
        private BigDecimal amount;
        private long txCount;
    }

    @Data
    @Builder
    public static class PendingActions {
        private long coursesPendingReview;
        private long examsPendingReview;
        private long trainerAppsPending;
        private long ticketsPending;
        private long commentsPendingModeration;
        private long unsettledStatements;
    }

    @Data
    @Builder
    public static class RecentActivity {
        private String type; // NEW_USER, PAYMENT, COURSE_SUBMITTED, etc.
        private String message;
        private LocalDateTime timestamp;
    }
}
