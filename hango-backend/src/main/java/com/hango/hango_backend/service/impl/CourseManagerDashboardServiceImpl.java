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
import com.hango.hango_backend.repository.EnrollmentRepository;
import com.hango.hango_backend.repository.SectionRepository;
import com.hango.hango_backend.repository.UserRepository;
import com.hango.hango_backend.service.CourseManagerDashboardService;
import com.hango.hango_backend.service.NotificationService;
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
    private final EnrollmentRepository enrollmentRepository;
    private final NotificationService notificationService;

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

        course.setStatus("PUBLISHED");
        course.setPublishedAt(java.time.LocalDateTime.now());
        course.setLatestVersionId(course.getId());
        courseRepository.save(course);

        notificationService.notifyUser(course.getCreator(), NotificationService.TYPE_CONTENT_APPROVED,
                "Course published",
                "Your course \"" + course.getTitle() + "\" has been approved and published.", course);

        if (course.getParentId() != null) {
            Course originalCourse = courseRepository.findById(course.getParentId())
                    .orElse(null);
            if (originalCourse != null && "PUBLISHED".equalsIgnoreCase(originalCourse.getStatus())) {
                originalCourse.setLatestVersionId(course.getId());
                courseRepository.save(originalCourse);
            }

            List<Long> priorVersionIds = courseRepository.findByCodeAndDeletedAtIsNullOrderByCreatedAtDesc(course.getCode())
                    .stream()
                    .map(Course::getId)
                    .filter(id -> !id.equals(course.getId()))
                    .collect(Collectors.toList());
            if (!priorVersionIds.isEmpty()) {
                enrollmentRepository.findByCourseIdIn(priorVersionIds).stream()
                        .map(enrollment -> enrollment.getUser())
                        .distinct()
                        .forEach(learner -> notificationService.notifyUser(learner, NotificationService.TYPE_COURSE_UPDATED,
                                "Course updated",
                                "\"" + course.getTitle() + "\" has a new version (" + course.getVersion() + ") available.",
                                course));
            }
        }
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

        notificationService.notifyUser(course.getCreator(), NotificationService.TYPE_CONTENT_REJECTED,
                "Course returned to draft",
                "Your course \"" + course.getTitle() + "\" was returned to draft by the course manager.", course);
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

        notificationService.notifyUser(exam.getCreatedBy(), NotificationService.TYPE_CONTENT_APPROVED,
                "Exam published",
                "Your exam \"" + exam.getTitle() + "\" has been approved and published.", null);
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

        notificationService.notifyUser(exam.getCreatedBy(), NotificationService.TYPE_CONTENT_REJECTED,
                "Exam returned to draft",
                "Your exam \"" + exam.getTitle() + "\" was returned to draft" + (reason != null && !reason.isBlank() ? ": " + reason : "."),
                null);
    }
}
