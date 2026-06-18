package com.hango.hango_backend.service;

import com.hango.hango_backend.dto.CourseSummaryDTO;
import java.util.List;

public interface CourseService {
    List<CourseSummaryDTO> getCourses(String search, String filterType, String difficulty);
}
