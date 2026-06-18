package com.hango.hango_backend.service;

import com.hango.hango_backend.dto.CourseSummaryDTO;
import com.hango.hango_backend.repository.CourseRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;

import java.util.List;

@Service
@RequiredArgsConstructor
public class CourseServiceImpl implements CourseService {

    private final CourseRepository courseRepository;

    @Override
    public List<CourseSummaryDTO> getCourses(String search, String filterType, String difficulty) {
        Long enrolledUserId = null;
        
        // "ALL" vs "ENROLLED". If ENROLLED, we need the current user's ID. 
        // For demonstration purposes or before auth is fully set up, we mock userId = 4 (minhlearner)
        if ("ENROLLED".equalsIgnoreCase(filterType)) {
            // TODO: Extract from SecurityContextHolder when Authentication is ready.
            enrolledUserId = 4L;
        }

        // Difficulty: "ALL" means no filter. Otherwise "EASY", "MEDIUM", "HARD" etc.
        String diffFilter = null;
        if (difficulty != null && !difficulty.equalsIgnoreCase("ALL")) {
            // Frontend might send "Beginner", we map it if needed, or frontend sends "EASY"
            // Assuming frontend sends "EASY", "MEDIUM", "HARD" matching the DB paramKey
            diffFilter = difficulty.toUpperCase();
        }

        return courseRepository.findCoursesWithFilters(search, diffFilter, enrolledUserId);
    }
}
