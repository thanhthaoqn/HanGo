package com.hango.hango_backend;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.CommandLineRunner;
import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Component;

import java.util.List;
import java.util.Map;

@SpringBootApplication
public class CheckDBApp {
    public static void main(String[] args) {
        SpringApplication.run(CheckDBApp.class, args);
    }
}

@Component
class Checker implements CommandLineRunner {
    @Autowired
    private com.hango.hango_backend.repository.CourseRepository courseRepository;
    @Autowired
    private com.hango.hango_backend.repository.ExamRepository examRepository;

    @Override
    public void run(String... args) throws Exception {
        System.out.println("====== EXAM REPOSITORY CHECK ======");
        List<com.hango.hango_backend.entity.Exam> exams = examRepository.findByDeletedAtIsNullAndStatus("PUBLISHED");
        System.out.println("Published Exams Count: " + exams.size());
        for (com.hango.hango_backend.entity.Exam e : exams) {
            System.out.println("Exam ID: " + e.getId() + ", Title: " + e.getTitle() + ", Status: " + e.getStatus());
        }

        System.out.println("====== COURSE REPOSITORY CHECK ======");
        List<com.hango.hango_backend.dto.CourseSummaryDTO> courses = courseRepository.findCoursesWithFilters(null, null, null, null);
        System.out.println("Published Courses Count (findCoursesWithFilters): " + courses.size());
        for (com.hango.hango_backend.dto.CourseSummaryDTO c : courses) {
            System.out.println("Course ID: " + c.getId() + ", Title: " + c.getTitle() + ", Category: " + c.getCategoryName() + ", Diff: " + c.getDifficultyName());
        }
        System.out.println("===========================");
    }
}
