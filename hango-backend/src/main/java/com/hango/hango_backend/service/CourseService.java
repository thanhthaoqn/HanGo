package com.hango.hango_backend.service;

import com.hango.hango_backend.dto.CourseDetailDTO;
import com.hango.hango_backend.dto.CourseSummaryDTO;
import java.util.List;
import java.util.Map;

public interface CourseService {
    List<CourseSummaryDTO> getCourses(String search, String filterType, String difficulty);
    CourseDetailDTO getCourseDetail(Long id, Long currentUserId);
    void enrollCourse(Long courseId, Long userId);
    void unenrollCourse(Long courseId, Long userId);
    void switchCourseVersion(Long courseId, Long userId);
    List<Map<String, Object>> getCourseVersionHistory(Long courseId);
}
