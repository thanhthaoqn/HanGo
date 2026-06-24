package com.hango.hango_backend.service;

import com.hango.hango_backend.dto.TrainerCourseDTO;
import com.hango.hango_backend.dto.TrainerDashboardSummaryDTO;
import com.hango.hango_backend.dto.TrainerCourseDetailDTO;
import com.hango.hango_backend.dto.TrainerCoursesResponseDTO;
import com.hango.hango_backend.entity.User;
import com.hango.hango_backend.repository.*;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.List;
import java.util.stream.Collectors;

@Service
@RequiredArgsConstructor
public class TrainerDashboardServiceImpl implements TrainerDashboardService {

    private final UserRepository userRepository;
    private final CourseRepository courseRepository;
    private final EnrollmentRepository enrollmentRepository;
    private final ExamRepository examRepository;
    private final SystemParameterRepository systemParameterRepository;
    private final SectionRepository sectionRepository;
    private final LessonRepository lessonRepository;

    @Override
    @Transactional(readOnly = true)
    public TrainerDashboardSummaryDTO getTrainerDashboardSummary(String email) {
        User user = userRepository.findByEmail(email)
                .orElseThrow(() -> new RuntimeException("User not found with email: " + email));
        Long trainerId = user.getId();

        long coursesCount = courseRepository.countByCreatorIdAndDeletedAtIsNull(trainerId);
        long learnersCount = enrollmentRepository.countDistinctStudentsByCourseCreatorId(trainerId);
        long examsCount = examRepository.countByCreatedByIdAndDeletedAtIsNull(trainerId);

        List<TrainerCourseProjection> projections = courseRepository.findTrainerCourses(trainerId);
        List<TrainerCourseDTO> courses = projections.stream().map(p -> TrainerCourseDTO.builder()
                .id(p.getId())
                .title(p.getTitle())
                .learnersCount(p.getLearnersCount() != null ? p.getLearnersCount() : 0L)
                .lessonsCount(p.getLessonsCount() != null ? p.getLessonsCount() : 0L)
                .thumbnailUrl(p.getThumbnailUrl())
                .build()).collect(Collectors.toList());

        return TrainerDashboardSummaryDTO.builder()
                .coursesCount(coursesCount)
                .learnersCount(learnersCount)
                .examsCount(examsCount)
                .courses(courses)
                .build();
    }

    @Override
    @Transactional(readOnly = true)
    public TrainerCoursesResponseDTO getTrainerCourses(String email, String status, String search, String sortBy, String timePeriod) {
        User user = userRepository.findByEmail(email)
                .orElseThrow(() -> new RuntimeException("User not found with email: " + email));
        Long trainerId = user.getId();

        // 1. Status Counts
        long allCount = courseRepository.countByCreatorIdAndDeletedAtIsNull(trainerId);
        long draftCount = courseRepository.countByCreatorIdAndStatusAndDeletedAtIsNull(trainerId, "DRAFT");
        long publishedCount = courseRepository.countByCreatorIdAndStatusAndDeletedAtIsNull(trainerId, "PUBLISHED");
        long hiddenCount = courseRepository.countByCreatorIdAndStatusAndDeletedAtIsNull(trainerId, "HIDDEN");
        long pendingCount = courseRepository.countByCreatorIdAndStatusAndDeletedAtIsNull(trainerId, "PENDING");

        // 2. Fetch Base courses
        String searchParam = (search == null || search.trim().isEmpty()) ? null : search.trim();
        List<TrainerCourseDetailProjection> projections = courseRepository.findTrainerCoursesDetailBase(trainerId, status, searchParam);

        // 3. Time Period Filter in Java
        if (timePeriod != null && !timePeriod.equalsIgnoreCase("ALL")) {
            LocalDateTime cutoff = LocalDateTime.now();
            if (timePeriod.equalsIgnoreCase("THIS_WEEK")) {
                cutoff = cutoff.minusWeeks(1);
            } else if (timePeriod.equalsIgnoreCase("THIS_MONTH")) {
                cutoff = cutoff.minusMonths(1);
            }
            final LocalDateTime finalCutoff = cutoff;
            projections = projections.stream()
                    .filter(p -> p.getCreatedAt() != null && p.getCreatedAt().isAfter(finalCutoff))
                    .collect(Collectors.toList());
        }

        // 4. Sort in Java
        List<TrainerCourseDetailProjection> mutableProjections = new ArrayList<>(projections);
        if (sortBy != null) {
            if (sortBy.equalsIgnoreCase("OLDEST")) {
                mutableProjections.sort((p1, p2) -> {
                    if (p1.getCreatedAt() == null) return 1;
                    if (p2.getCreatedAt() == null) return -1;
                    return p1.getCreatedAt().compareTo(p2.getCreatedAt());
                });
            } else if (sortBy.equalsIgnoreCase("ALPHABETICAL")) {
                mutableProjections.sort((p1, p2) -> {
                    String t1 = p1.getTitle() != null ? p1.getTitle() : "";
                    String t2 = p2.getTitle() != null ? p2.getTitle() : "";
                    return t1.compareToIgnoreCase(t2);
                });
            } else { // "NEWEST"
                mutableProjections.sort((p1, p2) -> {
                    if (p1.getCreatedAt() == null) return 1;
                    if (p2.getCreatedAt() == null) return -1;
                    return p2.getCreatedAt().compareTo(p1.getCreatedAt());
                });
            }
        } else {
            // Default to newest
            mutableProjections.sort((p1, p2) -> {
                if (p1.getCreatedAt() == null) return 1;
                if (p2.getCreatedAt() == null) return -1;
                return p2.getCreatedAt().compareTo(p1.getCreatedAt());
            });
        }

        // 5. Map to DTOs
        List<TrainerCourseDetailDTO> courses = mutableProjections.stream().map(p -> TrainerCourseDetailDTO.builder()
                .id(p.getId())
                .title(p.getTitle())
                .status(p.getStatus())
                .description(p.getDescription())
                .learnersCount(p.getLearnersCount() != null ? p.getLearnersCount() : 0L)
                .lessonsCount(p.getLessonsCount() != null ? p.getLessonsCount() : 0L)
                .thumbnailUrl(p.getThumbnailUrl())
                .createdAt(p.getCreatedAt())
                .build()).collect(Collectors.toList());

        return TrainerCoursesResponseDTO.builder()
                .allCount(allCount)
                .draftCount(draftCount)
                .publishedCount(publishedCount)
                .hiddenCount(hiddenCount)
                .pendingCount(pendingCount)
                .courses(courses)
                .build();
    }

    @Override
    @Transactional
    public void createTrainerCourse(String email, com.hango.hango_backend.dto.TrainerCreateCourseRequestDTO request) {
        User user = userRepository.findByEmail(email)
                .orElseThrow(() -> new RuntimeException("User not found with email: " + email));

        String catKey = request.getCategoryKey().toUpperCase();
        if ("READING".equals(catKey)) {
            catKey = "READING_COMPREHENSION";
        } else if ("PRONUNCIATION".equals(catKey) || "SPEAKING".equals(catKey)) {
            catKey = "PRONUNCIATION";
        } else if ("WRITING".equals(catKey)) {
            catKey = "GRAMMAR";
        }

        String diffKey = request.getDifficultyKey().toUpperCase();
        if ("BEGINNER".equals(diffKey)) {
            diffKey = "BASIC";
        }

        com.hango.hango_backend.entity.SystemParameter category = systemParameterRepository
                .findByParamTypeAndParamKey("COURSE_CATEGORY", catKey)
                .orElseThrow(() -> new RuntimeException("Category not found: " + request.getCategoryKey()));

        com.hango.hango_backend.entity.SystemParameter difficulty = systemParameterRepository
                .findByParamTypeAndParamKey("ACADEMIC_LEVEL", diffKey)
                .orElseThrow(() -> new RuntimeException("Academic Level not found: " + request.getDifficultyKey()));

        com.hango.hango_backend.entity.Course course = com.hango.hango_backend.entity.Course.builder()
                .title(request.getTitle())
                .description(request.getDescription())
                .creator(user)
                .category(category)
                .difficulty(difficulty)
                .thumbnailUrl(request.getThumbnailUrl())
                .status("DRAFT")
                .build();

        courseRepository.save(course);
    }

    @Override
    public java.util.List<com.hango.hango_backend.entity.SystemParameter> getSystemParametersByType(String paramType) {
        return systemParameterRepository.findByParamTypeAndIsActiveTrue(paramType.toUpperCase());
    }

    @Override
    @org.springframework.transaction.annotation.Transactional
    public void updateTrainerCourse(Long id, String email, com.hango.hango_backend.dto.TrainerCreateCourseRequestDTO request) {
        com.hango.hango_backend.entity.Course course = courseRepository.findById(id)
                .orElseThrow(() -> new RuntimeException("Course not found with ID: " + id));

        if (!course.getCreator().getEmail().equalsIgnoreCase(email)) {
            throw new RuntimeException("You are not authorized to edit this course");
        }

        String catKey = request.getCategoryKey().toUpperCase();
        if ("READING".equals(catKey)) {
            catKey = "READING_COMPREHENSION";
        } else if ("PRONUNCIATION".equals(catKey) || "SPEAKING".equals(catKey)) {
            catKey = "PRONUNCIATION";
        } else if ("WRITING".equals(catKey)) {
            catKey = "GRAMMAR";
        }

        String diffKey = request.getDifficultyKey().toUpperCase();
        if ("BEGINNER".equals(diffKey)) {
            diffKey = "BASIC";
        }

        com.hango.hango_backend.entity.SystemParameter category = systemParameterRepository
                .findByParamTypeAndParamKey("COURSE_CATEGORY", catKey)
                .orElseThrow(() -> new RuntimeException("Category not found: " + request.getCategoryKey()));

        com.hango.hango_backend.entity.SystemParameter difficulty = systemParameterRepository
                .findByParamTypeAndParamKey("ACADEMIC_LEVEL", diffKey)
                .orElseThrow(() -> new RuntimeException("Academic Level not found: " + request.getDifficultyKey()));

        course.setTitle(request.getTitle());
        course.setDescription(request.getDescription());
        course.setCategory(category);
        course.setDifficulty(difficulty);
        if (request.getThumbnailUrl() != null && !request.getThumbnailUrl().isEmpty()) {
            course.setThumbnailUrl(request.getThumbnailUrl());
        }

        com.hango.hango_backend.entity.Course savedCourse = courseRepository.save(course);

        // Update sections and lessons
        List<com.hango.hango_backend.entity.Section> existingSections = sectionRepository.findByCourseIdOrderByDisplayOrderAsc(savedCourse.getId());
        List<com.hango.hango_backend.dto.CourseSessionDTO> sessionDTOs = request.getSessions();
        if (sessionDTOs == null) {
            sessionDTOs = new java.util.ArrayList<>();
        }

        java.util.Set<Long> requestSectionIds = sessionDTOs.stream()
                .map(com.hango.hango_backend.dto.CourseSessionDTO::getId)
                .filter(sid -> sid != null && sid < 1000000000000L)
                .collect(java.util.stream.Collectors.toSet());

        // Delete sections not in request
        for (com.hango.hango_backend.entity.Section existingSection : existingSections) {
            if (!requestSectionIds.contains(existingSection.getId())) {
                sectionRepository.delete(existingSection);
            }
        }

        // Save/update sections
        for (int sIdx = 0; sIdx < sessionDTOs.size(); sIdx++) {
            com.hango.hango_backend.dto.CourseSessionDTO sDto = sessionDTOs.get(sIdx);
            com.hango.hango_backend.entity.Section section;
            if (sDto.getId() != null && sDto.getId() < 1000000000000L) {
                section = sectionRepository.findById(sDto.getId())
                        .orElse(new com.hango.hango_backend.entity.Section());
            } else {
                section = new com.hango.hango_backend.entity.Section();
            }
            section.setCourse(savedCourse);
            section.setTitle(sDto.getTitle());
            section.setDisplayOrder(sIdx + 1);

            final com.hango.hango_backend.entity.Section savedSection = sectionRepository.save(section);

            // Update lessons in this section
            List<com.hango.hango_backend.entity.Lesson> existingLessons = lessonRepository.findBySectionIdOrderByDisplayOrderAsc(savedSection.getId());
            List<com.hango.hango_backend.dto.CourseLessonDTO> lessonDTOs = sDto.getLessons();
            if (lessonDTOs == null) {
                lessonDTOs = new java.util.ArrayList<>();
            }

            java.util.Set<Long> requestLessonIds = lessonDTOs.stream()
                    .map(com.hango.hango_backend.dto.CourseLessonDTO::getId)
                    .filter(lid -> lid != null && lid < 1000000000000L)
                    .collect(java.util.stream.Collectors.toSet());

            // Delete lessons not in request
            for (com.hango.hango_backend.entity.Lesson existingLesson : existingLessons) {
                if (!requestLessonIds.contains(existingLesson.getId())) {
                    lessonRepository.delete(existingLesson);
                }
            }

            // Save/update lessons
            for (int lIdx = 0; lIdx < lessonDTOs.size(); lIdx++) {
                com.hango.hango_backend.dto.CourseLessonDTO lDto = lessonDTOs.get(lIdx);
                com.hango.hango_backend.entity.Lesson lesson;
                if (lDto.getId() != null && lDto.getId() < 1000000000000L) {
                    lesson = lessonRepository.findById(lDto.getId())
                            .orElse(new com.hango.hango_backend.entity.Lesson());
                } else {
                    lesson = new com.hango.hango_backend.entity.Lesson();
                }
                lesson.setSection(savedSection);
                lesson.setTitle(lDto.getTitle());
                lesson.setLessonType(lDto.getItemType() != null ? lDto.getItemType() : "video");
                lesson.setDisplayOrder(lIdx + 1);
                
                // Set mandatory fields using Course category and difficulty parameters
                lesson.setSkill(savedCourse.getCategory());
                lesson.setDifficulty(savedCourse.getDifficulty());

                lessonRepository.save(lesson);
            }
        }
    }
}
