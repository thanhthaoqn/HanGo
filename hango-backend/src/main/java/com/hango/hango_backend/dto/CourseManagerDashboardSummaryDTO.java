package com.hango.hango_backend.dto;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class CourseManagerDashboardSummaryDTO {
    private long registeredUsersCount;
    private long activeCoursesCount;
    private long inactiveCoursesCount;
    private long examsCount;
}
