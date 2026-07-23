package com.hango.hango_backend.service.impl;

import com.hango.hango_backend.dto.CourseManagerDashboardSummaryDTO;
import com.hango.hango_backend.dto.CourseReviewDetailDTO;
import com.hango.hango_backend.dto.CourseLessonDTO;
import com.hango.hango_backend.dto.CourseSessionDTO;
import com.hango.hango_backend.entity.Course;
import com.hango.hango_backend.entity.Lesson;
import com.hango.hango_backend.entity.Section;
import com.hango.hango_backend.repository.CourseRepository;
import com.hango.hango_backend.repository.ExamRepository;
import com.hango.hango_backend.repository.LessonRepository;
import com.hango.hango_backend.repository.SectionRepository;
import com.hango.hango_backend.repository.UserRepository;
import com.hango.hango_backend.service.CourseManagerDashboardService;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;
import java.util.Locale;
import java.util.stream.Collectors;

@Service
@RequiredArgsConstructor
public class CourseManagerDashboardServiceImpl implements CourseManagerDashboardService {

    private final UserRepository userRepository;
    private final CourseRepository courseRepository;
    private final ExamRepository examRepository;
    private final SectionRepository sectionRepository;
    private final LessonRepository lessonRepository;

    @Override
    @Transactional(readOnly = true)
    public CourseManagerDashboardSummaryDTO getDashboardSummary() {
        long registeredUsersCount = userRepository.countByRoleName("LEARNER");
        long activeCoursesCount = courseRepository.countByStatusAndDeletedAtIsNull("PUBLISHED");
        long inactiveCoursesCount = courseRepository.countByStatusAndDeletedAtIsNull("DRAFT")
                + courseRepository.countByStatusAndDeletedAtIsNull("ARCHIVED")
                + courseRepository.countByStatusAndDeletedAtIsNull("PENDING");
        long examsCount = examRepository.count();

        return CourseManagerDashboardSummaryDTO.builder()
                .registeredUsersCount(registeredUsersCount)
                .activeCoursesCount(activeCoursesCount)
                .inactiveCoursesCount(inactiveCoursesCount)
                .examsCount(examsCount)
                .build();
    }

    @Override
    @Transactional(readOnly = true)
    public List<CourseReviewDetailDTO> getCoursesForReview(String status) {
        String normalizedStatus = normalizeStatus(status);
        List<Course> courses;
        if ("ALL".equals(normalizedStatus)) {
            courses = courseRepository.findAll().stream()
                    .filter(course -> course.getDeletedAt() == null)
                    .sorted((left, right) -> {
                        if (left.getCreatedAt() == null && right.getCreatedAt() == null) return 0;
                        if (left.getCreatedAt() == null) return 1;
                        if (right.getCreatedAt() == null) return -1;
                        return right.getCreatedAt().compareTo(left.getCreatedAt());
                    })
                    .collect(Collectors.toList());
        } else {
            courses = courseRepository.findByStatusAndDeletedAtIsNullOrderByCreatedAtDesc(normalizedStatus);
        }

        return courses.stream()
                .map(course -> mapCourse(course, false))
                .collect(Collectors.toList());
    }

    @Override
    @Transactional(readOnly = true)
    public CourseReviewDetailDTO getCourseReviewDetail(Long courseId) {
        Course course = courseRepository.findById(courseId)
                .filter(c -> c.getDeletedAt() == null)
                .orElseThrow(() -> new RuntimeException("Course not found with ID: " + courseId));
        return mapCourse(course, true);
    }

    @Override
    @Transactional
    public void publishCourse(Long courseId) {
        Course course = courseRepository.findById(courseId)
                .filter(c -> c.getDeletedAt() == null)
                .orElseThrow(() -> new RuntimeException("Course not found with ID: " + courseId));

        if (!"PENDING_APPROVAL".equalsIgnoreCase(course.getStatus())) {
            throw new RuntimeException("Only courses in PENDING_APPROVAL status can be published");
        }

        if (course.getParentId() != null) {
            Course originalCourse = courseRepository.findById(course.getParentId()).orElse(null);
            if (originalCourse != null) {
                mergeDraftIntoOriginal(course, originalCourse);
                return;
            }
        }

        course.setStatus("PUBLISHED");
        course.setPublishedAt(java.time.LocalDateTime.now());
        course.setLatestVersionId(course.getId());
        courseRepository.save(course);
    }

    private void mergeDraftIntoOriginal(Course draft, Course original) {
        original.setTitle(draft.getTitle());
        original.setDescription(draft.getDescription());
        original.setObjectives(draft.getObjectives());
        original.setCategory(draft.getCategory());
        if (draft.getCategories() != null) {
            original.setCategories(new java.util.HashSet<>(draft.getCategories()));
        } else {
            original.setCategories(new java.util.HashSet<>());
        }
        original.setDifficulty(draft.getDifficulty());
        original.setThumbnailUrl(draft.getThumbnailUrl());
        original.setPrice(draft.getPrice());
        original.setVersion(draft.getVersion());
        original.setEstimatedDuration(draft.getEstimatedDuration());
        
        courseRepository.save(original);

        List<Section> draftSections = sectionRepository.findByCourseIdOrderByDisplayOrderAsc(draft.getId());
        List<Section> originalSections = sectionRepository.findByCourseIdOrderByDisplayOrderAsc(original.getId());

        for (Section draftSec : draftSections) {
            Section match = originalSections.stream()
                .filter(s -> s.getTitle() != null && s.getTitle().equalsIgnoreCase(draftSec.getTitle()))
                .findFirst()
                .orElse(null);
                
            if (match != null) {
                match.setDescription(draftSec.getDescription());
                match.setDisplayOrder(draftSec.getDisplayOrder());
                match.setVersion(draftSec.getVersion());
                sectionRepository.save(match);
                
                mergeLessons(draftSec, match);
                originalSections.remove(match);
            } else {
                Section newSec = new Section();
                newSec.setCourse(original);
                newSec.setTitle(draftSec.getTitle());
                newSec.setDescription(draftSec.getDescription());
                newSec.setDisplayOrder(draftSec.getDisplayOrder());
                newSec.setVersion(draftSec.getVersion());
                Section savedSec = sectionRepository.save(newSec);
                
                mergeLessons(draftSec, savedSec);
            }
        }
        
        for (Section oldSec : originalSections) {
            List<Lesson> oldLessons = lessonRepository.findBySectionIdOrderByDisplayOrderAsc(oldSec.getId());
            lessonRepository.deleteAll(oldLessons);
            sectionRepository.delete(oldSec);
        }
        
        for (Section draftSec : draftSections) {
            List<Lesson> dLessons = lessonRepository.findBySectionIdOrderByDisplayOrderAsc(draftSec.getId());
            lessonRepository.deleteAll(dLessons);
            sectionRepository.delete(draftSec);
        }
        courseRepository.delete(draft);
    }
    
    private void mergeLessons(Section draftSec, Section targetSec) {
        List<Lesson> draftLessons = lessonRepository.findBySectionIdOrderByDisplayOrderAsc(draftSec.getId());
        List<Lesson> targetLessons = lessonRepository.findBySectionIdOrderByDisplayOrderAsc(targetSec.getId());
        
        for (Lesson draftLes : draftLessons) {
            Lesson match = targetLessons.stream()
                .filter(l -> l.getTitle() != null && l.getTitle().equalsIgnoreCase(draftLes.getTitle()))
                .findFirst()
                .orElse(null);
                
            if (match != null) {
                match.setLessonType(draftLes.getLessonType());
                match.setDisplayOrder(draftLes.getDisplayOrder());
                match.setDescription(draftLes.getDescription());
                match.setContent(draftLes.getContent());
                match.setPdfName(draftLes.getPdfName());
                match.setQuestionImageUrl(draftLes.getQuestionImageUrl());
                match.setEstimatedTime(draftLes.getEstimatedTime());
                match.setCode(draftLes.getCode());
                match.setMediaDurationSeconds(draftLes.getMediaDurationSeconds());
                match.setMediaSizeBytes(draftLes.getMediaSizeBytes());
                match.setEstimatedTimeMinutes(draftLes.getEstimatedTimeMinutes());
                match.setLearningObjectives(draftLes.getLearningObjectives());
                match.setVersion(draftLes.getVersion());
                match.setSkill(draftLes.getSkill());
                match.setDifficulty(draftLes.getDifficulty());
                match.setExam(draftLes.getExam());
                lessonRepository.save(match);
                targetLessons.remove(match);
            } else {
                Lesson newLes = new Lesson();
                newLes.setSection(targetSec);
                newLes.setTitle(draftLes.getTitle());
                newLes.setLessonType(draftLes.getLessonType());
                newLes.setDisplayOrder(draftLes.getDisplayOrder());
                newLes.setDescription(draftLes.getDescription());
                newLes.setContent(draftLes.getContent());
                newLes.setPdfName(draftLes.getPdfName());
                newLes.setQuestionImageUrl(draftLes.getQuestionImageUrl());
                newLes.setEstimatedTime(draftLes.getEstimatedTime());
                newLes.setCode(draftLes.getCode());
                newLes.setMediaDurationSeconds(draftLes.getMediaDurationSeconds());
                newLes.setMediaSizeBytes(draftLes.getMediaSizeBytes());
                newLes.setEstimatedTimeMinutes(draftLes.getEstimatedTimeMinutes());
                newLes.setLearningObjectives(draftLes.getLearningObjectives());
                newLes.setVersion(draftLes.getVersion());
                newLes.setSkill(draftLes.getSkill());
                newLes.setDifficulty(draftLes.getDifficulty());
                newLes.setExam(draftLes.getExam());
                lessonRepository.save(newLes);
            }
        }
        
        lessonRepository.deleteAll(targetLessons);
    }

    @Override
    @Transactional
    public void returnCourseToDraft(Long courseId) {
        Course course = courseRepository.findById(courseId)
                .filter(c -> c.getDeletedAt() == null)
                .orElseThrow(() -> new RuntimeException("Course not found with ID: " + courseId));

        if (!"PENDING_APPROVAL".equalsIgnoreCase(course.getStatus())) {
            throw new RuntimeException("Only courses in PENDING_APPROVAL status can be returned to draft");
        }

        course.setStatus("DRAFT");
        courseRepository.save(course);
        // V1 remains PUBLISHED untouched - no changes needed
    }

    private String normalizeStatus(String status) {
        if (status == null || status.isBlank()) {
            return "PENDING_APPROVAL";
        }
        String normalized = status.trim().toUpperCase(Locale.ROOT);
        if ("SUBMITTED".equals(normalized) || "PENDING".equals(normalized)) {
            return "PENDING_APPROVAL";
        }
        return normalized;
    }

    private CourseReviewDetailDTO mapCourse(Course course, boolean includeSessions) {
        List<Section> sections = sectionRepository.findByCourseIdOrderByDisplayOrderAsc(course.getId());
        int lessonsCount = sections.stream()
                .mapToInt(section -> lessonRepository.findBySectionIdOrderByDisplayOrderAsc(section.getId()).size())
                .sum();

        List<CourseSessionDTO> sessions = includeSessions
                ? sections.stream().map(section -> {
                    List<Lesson> lessons = lessonRepository.findBySectionIdOrderByDisplayOrderAsc(section.getId());
                    List<CourseLessonDTO> lessonDTOs = lessons.stream()
                            .map(lesson -> CourseLessonDTO.builder()
                                    .id(lesson.getId())
                                    .title(lesson.getTitle())
                                    .orderIndex(lesson.getDisplayOrder())
                                    .itemType(lesson.getLessonType())
                                    .description(lesson.getDescription())
                                    .questionText(lesson.getContent())
                                    .pdfName(lesson.getPdfName())
                                    .questionImageUrl(lesson.getQuestionImageUrl())
                                    .estimatedTime(lesson.getEstimatedTime())
                                    .build())
                            .collect(Collectors.toList());
                    return CourseSessionDTO.builder()
                            .id(section.getId())
                            .title(section.getTitle())
                            .description(section.getDescription())
                            .orderIndex(section.getDisplayOrder())
                            .lessons(lessonDTOs)
                            .build();
                }).collect(Collectors.toList())
                : List.of();

        return CourseReviewDetailDTO.builder()
                .id(course.getId())
                .title(course.getTitle())
                .code(course.getCode())
                .creatorName(course.getCreator() != null ? course.getCreator().getFullName() : "Unknown trainer")
                .categoryName(course.getCategory() != null ? course.getCategory().getParamValue() : "Uncategorized")
                .difficultyName(course.getDifficulty() != null ? course.getDifficulty().getParamValue() : "N/A")
                .description(course.getDescription())
                .objectives(course.getObjectives())
                .price(course.getPrice())
                .version(course.getVersion())
                .status(course.getStatus())
                .thumbnailUrl(course.getThumbnailUrl())
                .sectionsCount(sections.size())
                .lessonsCount(lessonsCount)
                .submittedAt(course.getCreatedAt())
                .sessions(sessions)
                .build();
    }

    @Override
    @Transactional(readOnly = true)
    public List<com.hango.hango_backend.dto.ExamResponseDTO> getExamsForReview(String status) {
        String normalizedStatus = normalizeStatus(status);
        List<com.hango.hango_backend.entity.Exam> exams;
        if ("ALL".equals(normalizedStatus)) {
            exams = examRepository.findByDeletedAtIsNullOrderByCreatedAtDesc();
        } else if ("PENDING_APPROVAL".equals(normalizedStatus)) {
            exams = examRepository.findByStatusInAndDeletedAtIsNullOrderByCreatedAtDesc(
                    java.util.Arrays.asList("PENDING_APPROVAL", "SUBMITTED"));
        } else {
            exams = examRepository.findByStatusAndDeletedAtIsNullOrderByCreatedAtDesc(normalizedStatus);
        }

        return exams.stream().map(exam -> {
            int questionCount = exam.getExpectedQuestionCount() != null ? exam.getExpectedQuestionCount() : 0;
            return com.hango.hango_backend.dto.ExamResponseDTO.builder()
                    .id(exam.getId())
                    .title(exam.getTitle())
                    .description(exam.getDescription())
                    .status(exam.getStatus())
                    .creatorName(exam.getCreatedBy() != null ? exam.getCreatedBy().getFullName() : "Unknown")
                    .questionCount(questionCount)
                    .durationMinutes(exam.getDurationMinutes())
                    .thumbnailUrl(exam.getThumbnailUrl())
                    .rejectionReason(exam.getRejectionReason())
                    .build();
        }).collect(Collectors.toList());
    }

    @Override
    @Transactional
    public void publishExam(Long examId) {
        com.hango.hango_backend.entity.Exam exam = examRepository.findById(examId)
                .filter(e -> e.getDeletedAt() == null)
                .orElseThrow(() -> new RuntimeException("Exam not found with ID: " + examId));

        if (!"PENDING_APPROVAL".equalsIgnoreCase(exam.getStatus()) && !"SUBMITTED".equalsIgnoreCase(exam.getStatus())) {
            throw new RuntimeException("Only exams in PENDING_APPROVAL or SUBMITTED status can be published");
        }

        exam.setStatus("PUBLISHED");
        exam.setRejectionReason(null);
        examRepository.save(exam);
    }

    @Override
    @Transactional
    public void returnExamToDraft(Long examId, String reason) {
        com.hango.hango_backend.entity.Exam exam = examRepository.findById(examId)
                .filter(e -> e.getDeletedAt() == null)
                .orElseThrow(() -> new RuntimeException("Exam not found with ID: " + examId));

        if (!"PENDING_APPROVAL".equalsIgnoreCase(exam.getStatus()) && !"SUBMITTED".equalsIgnoreCase(exam.getStatus())) {
            throw new RuntimeException("Only exams in PENDING_APPROVAL or SUBMITTED status can be returned to draft");
        }

        exam.setStatus("DRAFT");
        exam.setRejectionReason(reason);
        examRepository.save(exam);
    }
}
