package com.hango.hango_backend.service;

import com.hango.hango_backend.dto.CourseManagerDashboardSummaryDTO;
import com.hango.hango_backend.dto.CourseReviewDetailDTO;
import com.hango.hango_backend.dto.ExamResponseDTO;
import java.util.List;

public interface CourseManagerDashboardService {
    CourseManagerDashboardSummaryDTO getDashboardSummary();
    List<CourseReviewDetailDTO> getCoursesForReview(String status);
    CourseReviewDetailDTO getCourseReviewDetail(Long courseId);
    void publishCourse(Long courseId);
    void returnCourseToDraft(Long courseId);
    void hideCourse(Long courseId);
    void unhideCourse(Long courseId);

    List<ExamResponseDTO> getExamsForReview(String status);
    void publishExam(Long examId);
    void returnExamToDraft(Long examId, String reason);
}
