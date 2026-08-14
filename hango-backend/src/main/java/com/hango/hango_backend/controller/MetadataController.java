package com.hango.hango_backend.controller;

import com.hango.hango_backend.entity.QuestionCategory;
import com.hango.hango_backend.entity.SystemParameter;
import com.hango.hango_backend.repository.CourseRepository;
import com.hango.hango_backend.repository.ExamRepository;
import com.hango.hango_backend.repository.QuestionCategoryRepository;
import com.hango.hango_backend.repository.SystemParameterRepository;
import com.hango.hango_backend.repository.UserRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.Map;

@CrossOrigin(origins = "*", maxAge = 3600)
@RestController
@RequestMapping("/api/v1/metadata")
@RequiredArgsConstructor
public class MetadataController {

    private final SystemParameterRepository systemParameterRepository;
    private final QuestionCategoryRepository questionCategoryRepository;
    private final CourseRepository courseRepository;
    private final UserRepository userRepository;
    private final ExamRepository examRepository;

    @GetMapping("/parameters")
    public ResponseEntity<List<SystemParameter>> getParameters(@RequestParam String type) {
        return ResponseEntity.ok(systemParameterRepository.findByParamTypeAndIsActiveTrue(type));
    }

    @GetMapping("/categories")
    public ResponseEntity<List<QuestionCategory>> getCategories() {
        return ResponseEntity.ok(questionCategoryRepository.findAll());
    }

    @GetMapping("/public-stats")
    public ResponseEntity<Map<String, Object>> getPublicStats() {
        long courses = courseRepository.countByStatusAndDeletedAtIsNull("PUBLISHED");
        if (courses == 0) courses = courseRepository.count();

        // Real count of learners/users from MySQL DB
        long learners = userRepository.countTotalLearners();
        if (learners == 0) learners = userRepository.count();

        long freeExams = examRepository.findByDeletedAtIsNullAndStatus("PUBLISHED").size();
        if (freeExams == 0) freeExams = examRepository.count();

        return ResponseEntity.ok(Map.of(
            "coursesCount", courses,
            "learnersCount", learners,
            "freeExamsCount", freeExams
        ));
    }
}
