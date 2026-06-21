package com.hango.hango_backend.service;

import com.hango.hango_backend.dto.CourseDetailDTO;
import com.hango.hango_backend.dto.CourseLessonDTO;
import com.hango.hango_backend.dto.CourseSessionDTO;
import com.hango.hango_backend.dto.CourseSummaryDTO;
import com.hango.hango_backend.entity.Course;
import com.hango.hango_backend.entity.Lesson;
import com.hango.hango_backend.entity.Section;
import com.hango.hango_backend.repository.LessonRepository;
import com.hango.hango_backend.repository.CourseRepository;
import com.hango.hango_backend.repository.SectionRepository;
import com.hango.hango_backend.repository.EnrollmentRepository;
import com.hango.hango_backend.repository.UserRepository;
import com.hango.hango_backend.entity.Enrollment;
import com.hango.hango_backend.entity.User;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.ArrayList;
import java.util.List;
import java.util.stream.Collectors;

import java.util.List;

@Service
@RequiredArgsConstructor
public class CourseServiceImpl implements CourseService {

    private final CourseRepository courseRepository;
    private final SectionRepository sectionRepository;
    private final LessonRepository lessonRepository;
    private final EnrollmentRepository enrollmentRepository;
    private final UserRepository userRepository;

    @Override
    public List<CourseSummaryDTO> getCourses(String search, String filterType, String difficulty) {
        Long enrolledUserId = null;
        
        if ("ENROLLED".equalsIgnoreCase(filterType)) {
            org.springframework.security.core.Authentication auth = org.springframework.security.core.context.SecurityContextHolder.getContext().getAuthentication();
            if (auth != null && auth.getPrincipal() instanceof com.hango.hango_backend.sercurity.UserDetailsImpl) {
                enrolledUserId = ((com.hango.hango_backend.sercurity.UserDetailsImpl) auth.getPrincipal()).getId();
            }
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

    @Override
    @Transactional(readOnly = true)
    public CourseDetailDTO getCourseDetail(Long id, Long currentUserId) {
        Course course = courseRepository.findById(id)
                .orElseThrow(() -> new RuntimeException("Course not found with ID: " + id));

        boolean isEnrolled = false;
        if (currentUserId != null) {
            isEnrolled = enrollmentRepository.existsByUserIdAndCourseId(currentUserId, id);
        }

        List<Section> sections = sectionRepository.findByCourseIdOrderByDisplayOrderAsc(id);
        
        List<CourseSessionDTO> sessionDTOs = sections.stream().map(section -> {
            List<Lesson> lessons = lessonRepository.findBySectionIdOrderByDisplayOrderAsc(section.getId());
            List<CourseLessonDTO> lessonDTOs = lessons.stream().map(lesson -> 
                CourseLessonDTO.builder()
                    .id(lesson.getId())
                    .title(lesson.getTitle())
                    .orderIndex(lesson.getDisplayOrder())
                    .itemType(lesson.getLessonType())
                    .examId(null) // Not directly linked in the Lesson entity for now
                    .build()
            ).collect(Collectors.toList());

            return CourseSessionDTO.builder()
                    .id(section.getId())
                    .title(section.getTitle())
                    .orderIndex(section.getDisplayOrder())
                    .lessons(lessonDTOs)
                    .build();
        }).collect(Collectors.toList());

        // For Learners Count and Rating
        int learnersCount = enrollmentRepository.countByCourseId(id);
        
        String creatorName = "Unknown Trainer";
        try {
            if (course.getCreator() != null) {
                creatorName = course.getCreator().getFullName();
            }
        } catch (jakarta.persistence.EntityNotFoundException e) {
            // Ignore
        }

        String difficultyName = "Unknown Level";
        try {
            if (course.getDifficulty() != null) {
                difficultyName = course.getDifficulty().getParamValue();
            }
        } catch (jakarta.persistence.EntityNotFoundException e) {
            // Ignore
        }

        return CourseDetailDTO.builder()
                .id(course.getId())
                .title(course.getTitle())
                .creatorName(creatorName)
                .difficultyName(difficultyName)
                .rating(4.3) // Keeping mock rating until Review system is fully implemented
                .learnersCount(learnersCount)
                .description(course.getDescription())
                .objectives(course.getObjectives())
                .isEnrolled(isEnrolled)
                .sessions(sessionDTOs)
                .build();
    }

    @Override
    @Transactional
    public void enrollCourse(Long courseId, Long userId) {
        if (enrollmentRepository.existsByUserIdAndCourseId(userId, courseId)) {
            throw new RuntimeException("User is already enrolled in this course");
        }

        User user = userRepository.findById(userId)
                .orElseThrow(() -> new RuntimeException("User not found"));
        Course course = courseRepository.findById(courseId)
                .orElseThrow(() -> new RuntimeException("Course not found"));

        Enrollment enrollment = Enrollment.builder()
                .user(user)
                .course(course)
                .status("ENROLLED")
                .progressPercentage(java.math.BigDecimal.ZERO)
                .build();

        enrollmentRepository.save(enrollment);
    }

    @Override
    @Transactional
    public void unenrollCourse(Long courseId, Long userId) {
        if (!enrollmentRepository.existsByUserIdAndCourseId(userId, courseId)) {
            throw new RuntimeException("User is not enrolled in this course");
        }
        enrollmentRepository.deleteByUserIdAndCourseId(userId, courseId);
    }
}
