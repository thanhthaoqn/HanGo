package com.hango.hango_backend.controller;

import com.hango.hango_backend.dto.CourseSummaryDTO;
import com.hango.hango_backend.service.CourseService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api/v1/courses")
@RequiredArgsConstructor
public class CourseController {

    private final CourseService courseService;

    @GetMapping
    public ResponseEntity<List<CourseSummaryDTO>> getCourses(
            @RequestParam(required = false) String search,
            @RequestParam(required = false, defaultValue = "ALL") String filterType,
            @RequestParam(required = false, defaultValue = "ALL") String difficulty) {
        
        List<CourseSummaryDTO> courses = courseService.getCourses(search, filterType, difficulty);
        return ResponseEntity.ok(courses);
    }
}
