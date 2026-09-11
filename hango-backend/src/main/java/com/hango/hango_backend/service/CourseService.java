package com.hango.hango_backend.service;

import com.hango.hango_backend.dto.CourseDetailDTO;
import com.hango.hango_backend.dto.CourseSummaryDTO;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import java.util.List;
import java.util.Map;

public interface CourseService {
    Page<CourseSummaryDTO> getCourses(String search, String filterType, String difficulty, Pageable pageable);
    CourseDetailDTO getCourseDetail(Long id, Long currentUserId);
    void enrollCourse(Long courseId, Long userId);
    void unenrollCourse(Long courseId, Long userId);
    void switchCourseVersion(Long courseId, Long userId);
    List<Map<String, Object>> getCourseVersionHistory(Long courseId);
}
