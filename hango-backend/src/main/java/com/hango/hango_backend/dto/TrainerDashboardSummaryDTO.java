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
    private long examsCount;
    private List<TrainerCourseDTO> courses;
}
