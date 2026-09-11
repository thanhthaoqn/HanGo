package com.hango.hango_backend.dto;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.util.List;
import java.util.Map;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class CourseManagerDashboardSummaryDTO {
    // Original KPI cards
    private long registeredUsersCount;
    private long activeCoursesCount;
    private long inactiveCoursesCount;
    private long examsCount;

    // Enhanced KPI cards
    private long pendingCoursesCount;
    private long pendingExamsCount;
    private long activeLearnerCount;
    private double avgCourseRating;

    // Pipeline counts
    private long draftCoursesCount;
    private long publishedCoursesCount;
    private long rejectedCoursesCount;
    private long hiddenCoursesCount;

    // Weekly deltas (percent change vs previous week)
    private double coursesGrowthPercent;
    private double learnersGrowthPercent;
    private double examsGrowthPercent;

    // Enrollment trend (8 weeks)
    private List<WeeklyEnrollmentDTO> enrollmentTrend;

    // Top courses & trainers
    private List<TopCourseDTO> topCoursesByEnrollment;
    private List<TopTrainerDTO> topTrainersByRating;

    // Content quality
    private long coursesWithoutDescription;
    private long coursesWithFewLessons;
    private long examsWithoutQuestions;
    private double avgLessonsPerCourse;
    private long lowRatedCourses;

    // Course distribution by category
    private Map<String, Long> coursesByCategory;
}

