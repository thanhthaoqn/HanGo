package com.hango.hango_backend.service;

import com.hango.hango_backend.dto.admin.DashboardStatsDTO;
import com.hango.hango_backend.repository.*;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.time.LocalDateTime;
import java.util.*;
import java.util.concurrent.CompletableFuture;
import java.util.stream.Collectors;

@Service
@RequiredArgsConstructor
@Slf4j
public class AdminDashboardService {

    private final UserRepository userRepository;
    private final CourseRepository courseRepository;
    private final EnrollmentRepository enrollmentRepository;
    private final PaymentRepository paymentRepository;
    private final TicketRepository ticketRepository;
    private final ExamRepository examRepository;
    private final ExamAttemptRepository examAttemptRepository;
    private final TrainerProfileRepository trainerProfileRepository;
    private final AiUsageLogRepository aiUsageLogRepository;
    private final CertificateRepository certificateRepository;
    private final MonthlyStatementRepository monthlyStatementRepository;
    private final CommentRepository commentRepository;

    @Transactional(readOnly = true)
    public DashboardStatsDTO getComprehensiveStats(int periodDays) {
        LocalDateTime since = LocalDateTime.now().minusDays(periodDays);
        LocalDateTime last30d = LocalDateTime.now().minusDays(30);

        // --- OVERVIEW ---
        var totalActiveUsersFuture = CompletableFuture.supplyAsync(() -> userRepository.count());
        var totalLearnersFuture = CompletableFuture.supplyAsync(() -> userRepository.countByRoleName("LEARNER"));
        var totalTrainersFuture = CompletableFuture.supplyAsync(() -> userRepository.countByRoleName("TRAINER"));
        var totalCourseManagersFuture = CompletableFuture.supplyAsync(() -> userRepository.countByRoleName("COURSE_MANAGER"));
        var totalAdminsFuture = CompletableFuture.supplyAsync(() -> userRepository.countByRoleName("ADMINISTRATOR"));

        var totalPublishedCoursesFuture = CompletableFuture.supplyAsync(() -> courseRepository.countByStatusAndDeletedAtIsNull("PUBLISHED"));
        var totalFreeCoursesFuture = CompletableFuture.supplyAsync(() -> courseRepository.countFreePublishedCourses());
        
        var totalEnrollmentsFuture = CompletableFuture.supplyAsync(() -> enrollmentRepository.count());
        var totalExamAttemptsFuture = CompletableFuture.supplyAsync(() -> examAttemptRepository.count());
        var totalCertificatesFuture = CompletableFuture.supplyAsync(() -> certificateRepository.count());
        
        var newUsersTodayFuture = CompletableFuture.supplyAsync(() -> userRepository.countUsersCreatedToday());
        var newEnrollmentsTodayFuture = CompletableFuture.supplyAsync(() -> enrollmentRepository.countEnrollmentsCreatedToday());
        var newCoursesTodayFuture = CompletableFuture.supplyAsync(() -> courseRepository.countCoursesPublishedToday());
        var newExamAttemptsTodayFuture = CompletableFuture.supplyAsync(() -> examAttemptRepository.countExamAttemptsToday());

        // --- REVENUE ---
        var totalRevenueFuture = CompletableFuture.supplyAsync(() -> paymentRepository.sumTotalRevenue());
        var totalPlatformFeeFuture = CompletableFuture.supplyAsync(() -> paymentRepository.sumTotalPlatformFee());
        var totalTrainerEarningsFuture = CompletableFuture.supplyAsync(() -> paymentRepository.sumTotalTrainerEarnings());
        var totalTxCountFuture = CompletableFuture.supplyAsync(() -> paymentRepository.countSuccessful());
        var monthlyRevenueFuture = CompletableFuture.supplyAsync(() -> paymentRepository.getMonthlyRevenueBreakdown(12));

        // --- CONTENT HEALTH ---
        var coursesByStatusFuture = CompletableFuture.supplyAsync(() -> courseRepository.countGroupedByStatus());
        var examsByStatusFuture = CompletableFuture.supplyAsync(() -> examRepository.countGroupedByStatus());
        var trainerAppsByStatusFuture = CompletableFuture.supplyAsync(() -> trainerProfileRepository.countGroupedByStatus());
        var oldestPendingCourseDateFuture = CompletableFuture.supplyAsync(() -> courseRepository.findOldestPendingCourseDate());
        var oldestPendingExamDateFuture = CompletableFuture.supplyAsync(() -> examRepository.findOldestPendingExamDate());
        
        // --- LEARNING PERFORMANCE ---
        var completedEnrollmentsFuture = CompletableFuture.supplyAsync(() -> enrollmentRepository.countCompletedEnrollments());
        var avgExamScoreFuture = CompletableFuture.supplyAsync(() -> examAttemptRepository.avgScore());
        var activeLearners30dFuture = CompletableFuture.supplyAsync(() -> enrollmentRepository.countActiveLearnersSince(last30d));
        var enrolledAtLeast1Future = CompletableFuture.supplyAsync(() -> enrollmentRepository.countDistinctEnrolledUsers());
        var completedAtLeast1Future = CompletableFuture.supplyAsync(() -> enrollmentRepository.countDistinctUsersCompletedAnyCourse());

        // --- TICKET HEALTH ---
        var ticketsByStatusFuture = CompletableFuture.supplyAsync(() -> ticketRepository.countGroupedByStatus());
        var ticketsByCategoryFuture = CompletableFuture.supplyAsync(() -> ticketRepository.countByCategory());
        var avgFirstResponseFuture = CompletableFuture.supplyAsync(() -> ticketRepository.avgFirstResponseHours());
        var avgResolutionFuture = CompletableFuture.supplyAsync(() -> ticketRepository.avgResolutionHours());

        // --- AI USAGE ---
        var totalAiCallsFuture = CompletableFuture.supplyAsync(() -> aiUsageLogRepository.count());
        var chatCallsFuture = CompletableFuture.supplyAsync(() -> aiUsageLogRepository.countByCallType("CHAT"));
        var embeddingCallsFuture = CompletableFuture.supplyAsync(() -> aiUsageLogRepository.countByCallType("EMBEDDING"));
        var aiSuccessCountFuture = CompletableFuture.supplyAsync(() -> aiUsageLogRepository.countBySuccess(true));
        var dailyAiUsageFuture = CompletableFuture.supplyAsync(() -> aiUsageLogRepository.getDailyUsageSince(since));
        var topAiUsersFuture = CompletableFuture.supplyAsync(() -> aiUsageLogRepository.findTopUsersByUsage());
        var avgAiSuccessDurationFuture = CompletableFuture.supplyAsync(() -> aiUsageLogRepository.avgSuccessDurationMs());

        // --- TRENDS ---
        var dailyUserRegistrationFuture = CompletableFuture.supplyAsync(() -> userRepository.countUsersRegisteredByDate(since));
        var dailyEnrollmentsFuture = CompletableFuture.supplyAsync(() -> enrollmentRepository.getDailyEnrollmentsSince(since));
        var dailyRevenueFuture = CompletableFuture.supplyAsync(() -> paymentRepository.getDailyRevenueSince(since));

        // --- PENDING ACTIONS ---
        var commentsByStatusFuture = CompletableFuture.supplyAsync(() -> commentRepository.countGroupedByStatus());
        var unsettledStatementsFuture = CompletableFuture.supplyAsync(() -> monthlyStatementRepository.countAndSumGroupedByStatus());

        CompletableFuture.allOf(
                totalActiveUsersFuture, totalLearnersFuture, totalTrainersFuture, totalCourseManagersFuture, totalAdminsFuture,
                totalPublishedCoursesFuture, totalFreeCoursesFuture, totalEnrollmentsFuture, totalExamAttemptsFuture, totalCertificatesFuture,
                newUsersTodayFuture, newEnrollmentsTodayFuture, newCoursesTodayFuture, newExamAttemptsTodayFuture,
                totalRevenueFuture, totalPlatformFeeFuture, totalTrainerEarningsFuture, totalTxCountFuture, monthlyRevenueFuture,
                coursesByStatusFuture, examsByStatusFuture, trainerAppsByStatusFuture, oldestPendingCourseDateFuture, oldestPendingExamDateFuture,
                completedEnrollmentsFuture, avgExamScoreFuture, activeLearners30dFuture, enrolledAtLeast1Future, completedAtLeast1Future,
                ticketsByStatusFuture, ticketsByCategoryFuture, avgFirstResponseFuture, avgResolutionFuture,
                totalAiCallsFuture, chatCallsFuture, embeddingCallsFuture, aiSuccessCountFuture, dailyAiUsageFuture, topAiUsersFuture, avgAiSuccessDurationFuture,
                dailyUserRegistrationFuture, dailyEnrollmentsFuture, dailyRevenueFuture,
                commentsByStatusFuture, unsettledStatementsFuture
        ).join();

        // 1. Overview Build
        DashboardStatsDTO.Overview overview = DashboardStatsDTO.Overview.builder()
                .totalActiveUsers(totalActiveUsersFuture.join())
                .totalLearners(totalLearnersFuture.join())
                .totalTrainers(totalTrainersFuture.join())
                .totalCourseManagers(totalCourseManagersFuture.join())
                .totalAdmins(totalAdminsFuture.join())
                .totalPublishedCourses(totalPublishedCoursesFuture.join())
                .totalFreeCourses(totalFreeCoursesFuture.join())
                .totalPaidCourses(totalPublishedCoursesFuture.join() - totalFreeCoursesFuture.join())
                .totalEnrollments(totalEnrollmentsFuture.join())
                .totalExamAttempts(totalExamAttemptsFuture.join())
                .totalCertificates(totalCertificatesFuture.join())
                .newUsersToday(newUsersTodayFuture.join())
                .newEnrollmentsToday(newEnrollmentsTodayFuture.join())
                .newCoursesToday(newCoursesTodayFuture.join())
                .newExamAttemptsToday(newExamAttemptsTodayFuture.join())
                .build();

        // 2. Revenue Build
        List<DashboardStatsDTO.MonthlyRevenue> monthlyRevenues = monthlyRevenueFuture.join().stream().map(row -> 
            DashboardStatsDTO.MonthlyRevenue.builder()
                .month(String.valueOf(row[0]))
                .total((BigDecimal) row[1])
                .platformFee((BigDecimal) row[2])
                .trainerEarnings((BigDecimal) row[3])
                .txCount(((Number) row[4]).longValue())
                .build()
        ).collect(Collectors.toList());
        
        DashboardStatsDTO.Revenue revenue = DashboardStatsDTO.Revenue.builder()
                .totalRevenue(totalRevenueFuture.join())
                .platformFee(totalPlatformFeeFuture.join())
                .trainerEarnings(totalTrainerEarningsFuture.join())
                .transactionCount(totalTxCountFuture.join())
                .avgTransactionValue(totalTxCountFuture.join() > 0 ? 
                        totalRevenueFuture.join().divide(BigDecimal.valueOf(totalTxCountFuture.join()), 2, RoundingMode.HALF_UP) 
                        : BigDecimal.ZERO)
                .revenueByMonth(monthlyRevenues)
                .build();

        // 3. Content Health Build
        Map<String, Long> courseStatusMap = mapGrouped(coursesByStatusFuture.join());
        Map<String, Long> examStatusMap = mapGrouped(examsByStatusFuture.join());
        Map<String, Long> trainerAppStatusMap = mapGrouped(trainerAppsByStatusFuture.join());
        
        long coursesPendingReview = courseStatusMap.getOrDefault("PENDING_APPROVAL", 0L);
        long examsPendingReview = examStatusMap.getOrDefault("PENDING_APPROVAL", 0L);
        long trainerAppsPending = trainerAppStatusMap.getOrDefault("PENDING_VERIFICATION", 0L) + trainerAppStatusMap.getOrDefault("AWAITING_APPROVAL", 0L);

        long rejectedCourses = courseStatusMap.getOrDefault("REJECTED", 0L);
        long publishedCourses = courseStatusMap.getOrDefault("PUBLISHED", 0L);
        double approvalRate = (publishedCourses + rejectedCourses > 0) ? 
                (double) publishedCourses / (publishedCourses + rejectedCourses) : 1.0;

        DashboardStatsDTO.ContentHealth contentHealth = DashboardStatsDTO.ContentHealth.builder()
                .coursesByStatus(courseStatusMap)
                .examsByStatus(examStatusMap)
                .trainerAppsByStatus(trainerAppStatusMap)
                .approvalRate(approvalRate)
                .oldestPendingCourseDate(oldestPendingCourseDateFuture.join())
                .oldestPendingExamDate(oldestPendingExamDateFuture.join())
                .build();

        // 4. Learning Performance Build
        long totalEnrolls = totalEnrollmentsFuture.join();
        double completionRate = totalEnrolls > 0 ? (double) completedEnrollmentsFuture.join() / totalEnrolls : 0.0;
        
        DashboardStatsDTO.LearningFunnel funnel = DashboardStatsDTO.LearningFunnel.builder()
                .registered(totalLearnersFuture.join())
                .enrolledAtLeast1(enrolledAtLeast1Future.join())
                .activelyLearning(activeLearners30dFuture.join())
                .completedAtLeast1Course(completedAtLeast1Future.join())
                .certified(totalCertificatesFuture.join())
                .build();

        DashboardStatsDTO.LearningPerformance learningPerf = DashboardStatsDTO.LearningPerformance.builder()
                .completionRate(completionRate)
                .avgExamScore(avgExamScoreFuture.join())
                .activeLearners30d(activeLearners30dFuture.join())
                .learningFunnel(funnel)
                .build();

        // 5. Ticket Health
        Map<String, Long> ticketStatusMap = mapGrouped(ticketsByStatusFuture.join());
        Map<String, Long> ticketCatMap = mapGrouped(ticketsByCategoryFuture.join());
        long ticketsPending = ticketStatusMap.getOrDefault("PENDING", 0L) + ticketStatusMap.getOrDefault("PROCESSING", 0L);
        
        DashboardStatsDTO.TicketHealth ticketHealth = DashboardStatsDTO.TicketHealth.builder()
                .byStatus(ticketStatusMap)
                .byCategory(ticketCatMap)
                .avgFirstResponseHours(avgFirstResponseFuture.join())
                .avgResolutionHours(avgResolutionFuture.join())
                .build();

        // 6. AI Usage
        long aiTotal = totalAiCallsFuture.join();
        double aiSuccessRate = aiTotal > 0 ? (double) aiSuccessCountFuture.join() / aiTotal : 0.0;
        
        List<DashboardStatsDTO.DailyAiUsage> dailyAiUsages = dailyAiUsageFuture.join().stream().map(row ->
            DashboardStatsDTO.DailyAiUsage.builder()
                .date(String.valueOf(row[0]))
                .count(((Number) row[1]).longValue())
                .success(((Number) row[2]).longValue())
                .failed(((Number) row[3]).longValue())
                .build()
        ).collect(Collectors.toList());

        List<DashboardStatsDTO.TopAiUser> topAiUsers = topAiUsersFuture.join().stream().map(row ->
            DashboardStatsDTO.TopAiUser.builder()
                .userId(((Number) row[0]).longValue())
                .fullName(String.valueOf(row[1]))
                .callCount(((Number) row[2]).longValue())
                .build()
        ).collect(Collectors.toList());

        DashboardStatsDTO.AiUsage aiUsage = DashboardStatsDTO.AiUsage.builder()
                .totalCalls(aiTotal)
                .chatCalls(chatCallsFuture.join())
                .embeddingCalls(embeddingCallsFuture.join())
                .successRate(aiSuccessRate)
                .avgSuccessDurationMs(avgAiSuccessDurationFuture.join())
                .callsByDay(dailyAiUsages)
                .topUsers(topAiUsers)
                .build();

        // 7. Trends
        Map<String, Long> enrollsByDay = mapDailyCounts(dailyEnrollmentsFuture.join());
        List<DashboardStatsDTO.DailyUserGrowth> userGrowth = dailyUserRegistrationFuture.join().stream().map(row -> {
            String date = String.valueOf(row[0]);
            long newUsers = ((Number) row[1]).longValue();
            return DashboardStatsDTO.DailyUserGrowth.builder()
                    .date(date)
                    .newUsers(newUsers)
                    .newEnrollments(enrollsByDay.getOrDefault(date, 0L))
                    .build();
        }).collect(Collectors.toList());

        List<DashboardStatsDTO.DailyRevenue> dailyRevenues = dailyRevenueFuture.join().stream().map(row ->
            DashboardStatsDTO.DailyRevenue.builder()
                .date(String.valueOf(row[0]))
                .amount((BigDecimal) row[1])
                .txCount(((Number) row[2]).longValue())
                .build()
        ).collect(Collectors.toList());

        DashboardStatsDTO.Trends trends = DashboardStatsDTO.Trends.builder()
                .userGrowthByDay(userGrowth)
                .revenueByDay(dailyRevenues)
                .build();

        // 8. Pending Actions
        Map<String, Long> commentsStatusMap = mapGrouped(commentsByStatusFuture.join());
        long commentsPending = commentsStatusMap.getOrDefault("PENDING", 0L);

        Map<String, Long> statementStatusMap = mapGrouped(unsettledStatementsFuture.join());
        long unsettled = statementStatusMap.getOrDefault("TRAINER_CONFIRMED", 0L);

        DashboardStatsDTO.PendingActions pendingActions = DashboardStatsDTO.PendingActions.builder()
                .coursesPendingReview(coursesPendingReview)
                .examsPendingReview(examsPendingReview)
                .trainerAppsPending(trainerAppsPending)
                .ticketsPending(ticketsPending)
                .commentsPendingModeration(commentsPending)
                .unsettledStatements(unsettled)
                .build();

        return DashboardStatsDTO.builder()
                .overview(overview)
                .revenue(revenue)
                .contentHealth(contentHealth)
                .learningPerformance(learningPerf)
                .ticketHealth(ticketHealth)
                .aiUsage(aiUsage)
                .trends(trends)
                .pendingActions(pendingActions)
                .recentActivity(Collections.emptyList()) // Requires advanced audit stream logic, omitting for now
                .build();
    }

    private Map<String, Long> mapGrouped(List<Object[]> queryResult) {
        return queryResult.stream()
                .collect(Collectors.toMap(
                        row -> String.valueOf(row[0]),
                        row -> ((Number) row[1]).longValue(),
                        (v1, v2) -> v1 // In case of duplicate keys
                ));
    }

    private Map<String, Long> mapDailyCounts(List<Object[]> queryResult) {
        return queryResult.stream()
                .collect(Collectors.toMap(
                        row -> String.valueOf(row[0]),
                        row -> ((Number) row[1]).longValue(),
                        (v1, v2) -> v1
                ));
    }
}
