package com.hango.hango_backend.service.impl;

import com.hango.hango_backend.dto.CourseManagerDashboardSummaryDTO;
import com.hango.hango_backend.dto.CourseReviewDetailDTO;
import com.hango.hango_backend.dto.CourseLessonDTO;
import com.hango.hango_backend.dto.CourseSessionDTO;
import com.hango.hango_backend.entity.Course;
import com.hango.hango_backend.entity.Lesson;
import com.hango.hango_backend.repository.CourseRepository;
import com.hango.hango_backend.repository.ExamRepository;
import com.hango.hango_backend.repository.LessonRepository;
import com.hango.hango_backend.repository.EnrollmentRepository;
import com.hango.hango_backend.repository.SectionRepository;
import com.hango.hango_backend.repository.UserRepository;
import com.hango.hango_backend.service.CourseManagerDashboardService;
import com.hango.hango_backend.service.ExamHistoryService;
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
    private final ExamHistoryService examHistoryService;
    private final org.springframework.jdbc.core.JdbcTemplate jdbcTemplate;

    @Override
    @Transactional(readOnly = true)
    public CourseManagerDashboardSummaryDTO getDashboardSummary() {
        // === Original KPI cards ===
        long registeredUsersCount = userRepository.countByRoleName("LEARNER");
        long activeCoursesCount = courseRepository.countByStatusAndDeletedAtIsNull("PUBLISHED");
        long draftCoursesCount = courseRepository.countByStatusAndDeletedAtIsNull("DRAFT");
        long hiddenCoursesCount = courseRepository.countByStatusAndDeletedAtIsNull("HIDDEN");
        long rejectedCoursesCount = courseRepository.countByStatusAndDeletedAtIsNull("REJECTED");
        long pendingCoursesCount = courseRepository.countByStatusAndDeletedAtIsNull("PENDING_APPROVAL");
        long archivedCoursesCount = courseRepository.countByStatusAndDeletedAtIsNull("ARCHIVED");
        long inactiveCoursesCount = draftCoursesCount + archivedCoursesCount + hiddenCoursesCount + pendingCoursesCount;
        long examsCount = examRepository.count();

        // === Enhanced KPI cards ===
        long pendingExamsCount = 0;
        try {
            pendingExamsCount = jdbcTemplate.queryForObject(
                    "SELECT COUNT(*) FROM exams WHERE (status = 'PENDING_APPROVAL' OR status = 'SUBMITTED') AND deleted_at IS NULL", Long.class);
        } catch (Exception ignored) {}

        long activeLearnerCount = 0;
        try {
            activeLearnerCount = jdbcTemplate.queryForObject(
                    "SELECT COUNT(DISTINCT user_id) FROM enrollments", Long.class);
        } catch (Exception ignored) {}

        double avgCourseRating = 0.0;
        try {
            Double avg = jdbcTemplate.queryForObject("SELECT AVG(rating) FROM course_ratings", Double.class);
            avgCourseRating = avg != null ? Math.round(avg * 10.0) / 10.0 : 0.0;
        } catch (Exception ignored) {}

        // === Weekly deltas ===
        double coursesGrowthPercent = computeWeeklyGrowth("courses", "created_at");
        double learnersGrowthPercent = computeWeeklyGrowth("enrollments", "enrolled_at");
        double examsGrowthPercent = computeWeeklyGrowth("exams", "created_at");

        // === Enrollment trend (8 weeks) ===
        List<com.hango.hango_backend.dto.WeeklyEnrollmentDTO> enrollmentTrend = computeEnrollmentTrend();

        // === Top 5 courses by enrollment ===
        List<com.hango.hango_backend.dto.TopCourseDTO> topCoursesByEnrollment = computeTopCourses();

        // === Top 5 trainers by rating ===
        List<com.hango.hango_backend.dto.TopTrainerDTO> topTrainersByRating = computeTopTrainers();

        // === Content quality metrics ===
        long coursesWithoutDescription = 0;
        long coursesWithFewLessons = 0;
        long examsWithoutQuestions = 0;
        double avgLessonsPerCourse = 0.0;
        long lowRatedCourses = 0;
        try {
            coursesWithoutDescription = jdbcTemplate.queryForObject(
                    "SELECT COUNT(*) FROM courses WHERE deleted_at IS NULL AND status = 'PUBLISHED' AND (description IS NULL OR description = '')", Long.class);
            coursesWithFewLessons = jdbcTemplate.queryForObject(
                    "SELECT COUNT(*) FROM courses c WHERE c.deleted_at IS NULL AND c.status = 'PUBLISHED' " +
                    "AND (SELECT COUNT(*) FROM lessons l JOIN sections s ON l.section_id = s.id WHERE s.course_id = c.id) < 3", Long.class);
            examsWithoutQuestions = jdbcTemplate.queryForObject(
                    "SELECT COUNT(*) FROM exams e WHERE e.deleted_at IS NULL AND (e.expected_question_count IS NULL OR e.expected_question_count = 0)", Long.class);
            Double avgLessons = jdbcTemplate.queryForObject(
                    "SELECT AVG(lesson_cnt) FROM (SELECT c.id, COUNT(l.id) AS lesson_cnt FROM courses c " +
                    "LEFT JOIN sections s ON s.course_id = c.id LEFT JOIN lessons l ON l.section_id = s.id " +
                    "WHERE c.deleted_at IS NULL AND c.status = 'PUBLISHED' GROUP BY c.id) sub", Double.class);
            avgLessonsPerCourse = avgLessons != null ? Math.round(avgLessons * 10.0) / 10.0 : 0.0;
            lowRatedCourses = jdbcTemplate.queryForObject(
                    "SELECT COUNT(DISTINCT cr.course_id) FROM course_ratings cr " +
                    "JOIN courses c ON c.id = cr.course_id WHERE c.deleted_at IS NULL " +
                    "GROUP BY cr.course_id HAVING AVG(cr.rating) < 3.0", Long.class);
        } catch (Exception ignored) {}

        // === Course distribution by category ===
        java.util.Map<String, Long> coursesByCategory = new java.util.LinkedHashMap<>();
        try {
            List<java.util.Map<String, Object>> rows = jdbcTemplate.queryForList(
                    "SELECT COALESCE(sp.param_value, 'Uncategorized') AS cat, COUNT(c.id) AS cnt " +
                    "FROM courses c LEFT JOIN system_parameters sp ON c.category_param_id = sp.id " +
                    "WHERE c.deleted_at IS NULL AND c.status = 'PUBLISHED' " +
                    "GROUP BY cat ORDER BY cnt DESC");
            for (java.util.Map<String, Object> row : rows) {
                coursesByCategory.put((String) row.get("cat"), ((Number) row.get("cnt")).longValue());
            }
        } catch (Exception e) {
            e.printStackTrace();
        }

        return CourseManagerDashboardSummaryDTO.builder()
                .registeredUsersCount(registeredUsersCount)
                .activeCoursesCount(activeCoursesCount)
                .inactiveCoursesCount(inactiveCoursesCount)
                .examsCount(examsCount)
                .pendingCoursesCount(pendingCoursesCount)
                .pendingExamsCount(pendingExamsCount)
                .activeLearnerCount(activeLearnerCount)
                .avgCourseRating(avgCourseRating)
                .draftCoursesCount(draftCoursesCount)
                .publishedCoursesCount(activeCoursesCount)
                .rejectedCoursesCount(rejectedCoursesCount)
                .hiddenCoursesCount(hiddenCoursesCount)
                .coursesGrowthPercent(coursesGrowthPercent)
                .learnersGrowthPercent(learnersGrowthPercent)
                .examsGrowthPercent(examsGrowthPercent)
                .enrollmentTrend(enrollmentTrend)
                .topCoursesByEnrollment(topCoursesByEnrollment)
                .topTrainersByRating(topTrainersByRating)
                .coursesWithoutDescription(coursesWithoutDescription)
                .coursesWithFewLessons(coursesWithFewLessons)
                .examsWithoutQuestions(examsWithoutQuestions)
                .avgLessonsPerCourse(avgLessonsPerCourse)
                .lowRatedCourses(lowRatedCourses)
                .coursesByCategory(coursesByCategory)
                .build();
    }

    // ---- Helper methods for dashboard computations ----

    private double computeWeeklyGrowth(String table, String dateColumn) {
        try {
            Long thisWeek = jdbcTemplate.queryForObject(
                    "SELECT COUNT(*) FROM " + table + " WHERE " + dateColumn + " >= DATE_SUB(CURDATE(), INTERVAL 7 DAY)", Long.class);
            Long lastWeek = jdbcTemplate.queryForObject(
                    "SELECT COUNT(*) FROM " + table + " WHERE " + dateColumn + " >= DATE_SUB(CURDATE(), INTERVAL 14 DAY) AND " + dateColumn + " < DATE_SUB(CURDATE(), INTERVAL 7 DAY)", Long.class);
            if (lastWeek == null || lastWeek == 0) return thisWeek != null && thisWeek > 0 ? 100.0 : 0.0;
            return Math.round(((thisWeek - lastWeek) * 100.0 / lastWeek) * 10.0) / 10.0;
        } catch (Exception e) {
            return 0.0;
        }
    }

    private List<com.hango.hango_backend.dto.WeeklyEnrollmentDTO> computeEnrollmentTrend() {
        List<com.hango.hango_backend.dto.WeeklyEnrollmentDTO> trend = new java.util.ArrayList<>();
        try {
            // Generate 8 weeks of data
            for (int i = 7; i >= 0; i--) {
                int startDay = i * 7;
                int endDay = (i - 1) * 7;
                String label;
                if (i == 0) {
                    label = "This week";
                } else {
                    java.time.LocalDate weekStart = java.time.LocalDate.now().minusDays(startDay);
                    label = weekStart.format(java.time.format.DateTimeFormatter.ofPattern("dd/MM"));
                }
                Long count = jdbcTemplate.queryForObject(
                        "SELECT COUNT(*) FROM enrollments WHERE enrolled_at >= DATE_SUB(CURDATE(), INTERVAL ? DAY)" +
                        (i > 0 ? " AND enrolled_at < DATE_SUB(CURDATE(), INTERVAL ? DAY)" : ""),
                        i > 0 ? new Object[]{startDay, endDay} : new Object[]{startDay},
                        Long.class);
                trend.add(com.hango.hango_backend.dto.WeeklyEnrollmentDTO.builder()
                        .weekLabel(label)
                        .count(count != null ? count : 0)
                        .build());
            }
        } catch (Exception e) {
            e.printStackTrace();
            // Return empty trend on error
        }
        return trend;
    }

    private List<com.hango.hango_backend.dto.TopCourseDTO> computeTopCourses() {
        List<com.hango.hango_backend.dto.TopCourseDTO> topCourses = new java.util.ArrayList<>();
        try {
            List<java.util.Map<String, Object>> rows = jdbcTemplate.queryForList(
                    "SELECT c.id, c.title, u.full_name AS trainer_name, COUNT(e.id) AS enroll_count, " +
                    "(SELECT AVG(cr.rating) FROM course_ratings cr WHERE cr.course_id = c.id) AS avg_rating " +
                    "FROM courses c " +
                    "JOIN users u ON c.created_by = u.id " +
                    "LEFT JOIN enrollments e ON e.course_id = c.id " +
                    "WHERE c.deleted_at IS NULL AND c.status = 'PUBLISHED' " +
                    "GROUP BY c.id, c.title, u.full_name " +
                    "ORDER BY enroll_count DESC LIMIT 5");
            for (java.util.Map<String, Object> row : rows) {
                topCourses.add(com.hango.hango_backend.dto.TopCourseDTO.builder()
                        .id(((Number) row.get("id")).longValue())
                        .title((String) row.get("title"))
                        .trainerName((String) row.get("trainer_name"))
                        .enrollmentCount(((Number) row.get("enroll_count")).longValue())
                        .avgRating(row.get("avg_rating") != null ? ((Number) row.get("avg_rating")).doubleValue() : null)
                        .build());
            }
        } catch (Exception e) {
            e.printStackTrace();
            // Return empty on error
        }
        return topCourses;
    }

    private List<com.hango.hango_backend.dto.TopTrainerDTO> computeTopTrainers() {
        List<com.hango.hango_backend.dto.TopTrainerDTO> topTrainers = new java.util.ArrayList<>();
        try {
            List<java.util.Map<String, Object>> rows = jdbcTemplate.queryForList(
                    "SELECT u.id, u.full_name, u.avatar_url, AVG(cr.rating) AS avg_rating, " +
                    "COUNT(DISTINCT c.id) AS course_count, " +
                    "(SELECT COUNT(*) FROM enrollments en JOIN courses cc ON en.course_id = cc.id WHERE cc.created_by = u.id) AS total_enrollments " +
                    "FROM users u " +
                    "JOIN courses c ON c.created_by = u.id " +
                    "JOIN course_ratings cr ON cr.course_id = c.id " +
                    "WHERE c.deleted_at IS NULL AND c.status = 'PUBLISHED' " +
                    "GROUP BY u.id, u.full_name, u.avatar_url " +
                    "HAVING COUNT(cr.id) >= 1 " +
                    "ORDER BY avg_rating DESC LIMIT 5");
            for (java.util.Map<String, Object> row : rows) {
                topTrainers.add(com.hango.hango_backend.dto.TopTrainerDTO.builder()
                        .id(((Number) row.get("id")).longValue())
                        .fullName((String) row.get("full_name"))
                        .avatarUrl((String) row.get("avatar_url"))
                        .avgRating(Math.round(((Number) row.get("avg_rating")).doubleValue() * 10.0) / 10.0)
                        .courseCount(((Number) row.get("course_count")).longValue())
                        .totalEnrollments(((Number) row.get("total_enrollments")).longValue())
                        .build());
            }
        } catch (Exception e) {
            e.printStackTrace();
            // Return empty on error
        }
        return topTrainers;
    }

    @Override
    @Transactional(readOnly = true)
    public org.springframework.data.domain.Page<CourseReviewDetailDTO> getCoursesForReview(String status, int page, int size) {
        String normalizedStatus = normalizeStatus(status);
        org.springframework.data.domain.Pageable pageable = org.springframework.data.domain.PageRequest.of(page, size);
        org.springframework.data.domain.Page<Course> coursePage;
        
        if ("ALL".equals(normalizedStatus)) {
            coursePage = courseRepository.findByDeletedAtIsNullOrderByCreatedAtDesc(pageable);
        } else {
            coursePage = courseRepository.findByStatusAndDeletedAtIsNullOrderByCreatedAtDesc(normalizedStatus, pageable);
        }

        return coursePage.map(course -> mapCourse(course, false));
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

        if (courseRepository.isEligibleForFirstCoursePromotion(course.getCreator().getId(), course.getCode())) {
            course.setPrice(java.math.BigDecimal.ZERO);
            course.setSuggestedPrice(java.math.BigDecimal.ZERO);
        }

        course.setStatus("PUBLISHED");
        course.setRejectionReason(null);
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
                originalCourse.setStatus("ARCHIVED");
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
    public void rejectCourse(Long courseId, String reason) {
        Course course = courseRepository.findById(courseId)
                .filter(c -> c.getDeletedAt() == null)
                .orElseThrow(() -> new RuntimeException("Course not found with ID: " + courseId));

        if (!"PENDING_APPROVAL".equalsIgnoreCase(course.getStatus())) {
            throw new RuntimeException("Only courses in PENDING_APPROVAL status can be rejected");
        }

        course.setStatus("REJECTED");
        course.setRejectionReason(reason);
        courseRepository.save(course);
        // V1 remains PUBLISHED untouched - no changes needed

        notificationService.notifyUser(course.getCreator(), NotificationService.TYPE_CONTENT_REJECTED,
                "Course rejected",
                "Your course \"" + course.getTitle() + "\" was rejected" + (reason != null && !reason.isBlank() ? " with reason: " + reason : "."), course);
    }

    @Override
    @Transactional
    public void hideCourse(Long courseId) {
        Course course = courseRepository.findById(courseId)
                .filter(c -> c.getDeletedAt() == null)
                .orElseThrow(() -> new RuntimeException("Course not found with ID: " + courseId));

        if (!"PUBLISHED".equalsIgnoreCase(course.getStatus())) {
            throw new RuntimeException("Only courses in PUBLISHED status can be hidden");
        }

        course.setStatus("HIDDEN");
        courseRepository.save(course);
    }

    @Override
    @Transactional
    public void unhideCourse(Long courseId) {
        Course course = courseRepository.findById(courseId)
                .filter(c -> c.getDeletedAt() == null)
                .orElseThrow(() -> new RuntimeException("Course not found with ID: " + courseId));

        if (!"HIDDEN".equalsIgnoreCase(course.getStatus()) && !"ARCHIVED".equalsIgnoreCase(course.getStatus())) {
            throw new RuntimeException("Only hidden or archived courses can be unhidden");
        }

        course.setStatus("PUBLISHED");
        courseRepository.save(course);
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
        int sectionsCount = includeSessions ? sectionRepository.findByCourseIdOrderByDisplayOrderAsc(course.getId()).size() : (int) sectionRepository.countByCourseId(course.getId());
        int lessonsCount = (int) lessonRepository.countByCourseId(course.getId());

        List<CourseSessionDTO> sessions = includeSessions
                ? sectionRepository.findByCourseIdOrderByDisplayOrderAsc(course.getId()).stream().map(section -> {
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
                                    .lessonCode(lesson.getCode())
                                    .mediaDurationSeconds(lesson.getMediaDurationSeconds())
                                    .mediaSizeBytes(lesson.getMediaSizeBytes())
                                    .estimatedTimeMinutes(lesson.getEstimatedTimeMinutes())
                                    .learningObjectives(lesson.getLearningObjectives())
                                    .videoTranscript(lesson.getVideoTranscript())
                                    .questions("quiz".equalsIgnoreCase(lesson.getLessonType()) ? 
                                            jdbcTemplate.query(
                                                "SELECT q.id AS question_id, q.question_text, q.explanation, qg.context_text AS passage " +
                                                "FROM lesson_quizzes lq " +
                                                "JOIN questions q ON lq.question_id = q.id " +
                                                "LEFT JOIN question_groups qg ON q.group_id = qg.id " +
                                                "WHERE lq.lesson_id = ? " +
                                                "ORDER BY lq.display_order ASC",
                                                (rs, rowNum) -> {
                                                    Long qId = rs.getLong("question_id");
                                                    String questionText = rs.getString("question_text");
                                                    String explanation = rs.getString("explanation");
                                                    String passage = rs.getString("passage");
                                                    
                                                    java.util.List<java.util.Map<String, Object>> optionsRows = jdbcTemplate.queryForList(
                                                            "SELECT option_text, is_correct FROM question_options WHERE question_id = ? ORDER BY id ASC",
                                                            qId
                                                    );
                                                    
                                                    java.util.List<String> options = new java.util.ArrayList<>();
                                                    Integer correctIndex = 0;
                                                    for (int i = 0; i < optionsRows.size(); i++) {
                                                        java.util.Map<String, Object> row = optionsRows.get(i);
                                                        options.add((String) row.get("option_text"));
                                                        Object isCorrectObj = row.get("is_correct");
                                                        boolean isCorrect = false;
                                                        if (isCorrectObj instanceof Boolean) {
                                                            isCorrect = (Boolean) isCorrectObj;
                                                        } else if (isCorrectObj instanceof Number) {
                                                            isCorrect = ((Number) isCorrectObj).intValue() == 1;
                                                        }
                                                        if (isCorrect) {
                                                            correctIndex = i;
                                                        }
                                                    }
                                                    
                                                    return com.hango.hango_backend.dto.QuizQuestionDTO.builder()
                                                            .id(qId)
                                                            .passage(passage)
                                                            .questionText(questionText)
                                                            .explanation(explanation)
                                                            .options(options)
                                                            .correctIndex(correctIndex)
                                                            .build();
                                                },
                                                lesson.getId()
                                            )
                                            : null
                                    )
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
                .suggestedPrice(course.getSuggestedPrice())
                .priceNote(course.getPriceNote())
                .version(course.getVersion())
                .status(course.getStatus())
                .thumbnailUrl(course.getThumbnailUrl())
                .sectionsCount(sectionsCount)
                .lessonsCount(lessonsCount)
                .submittedAt(course.getCreatedAt())
                .rejectionReason(course.getRejectionReason())
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
                    .creatorId(exam.getCreatedBy() != null ? exam.getCreatedBy().getId() : null)
                    .questionCount(questionCount)
                    .expectedQuestionCount(exam.getExpectedQuestionCount())
                    .passingScore(exam.getPassingScore())
                    .durationMinutes(exam.getDurationMinutes())
                    .thumbnailUrl(exam.getThumbnailUrl())
                    .rejectionReason(exam.getRejectionReason())
                    .createdAt(exam.getCreatedAt())
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

        String oldStatus = exam.getStatus();
        exam.setStatus("PUBLISHED");
        exam.setRejectionReason(null);
        examRepository.save(exam);
        examHistoryService.log(exam, ExamHistoryService.ACTION_PUBLISHED, oldStatus, "PUBLISHED", null, null);

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

        String oldStatus = exam.getStatus();
        exam.setStatus("REJECTED");
        exam.setRejectionReason(reason);
        examRepository.save(exam);
        examHistoryService.log(exam, ExamHistoryService.ACTION_REJECTED, oldStatus, "REJECTED", reason, null);

        notificationService.notifyUser(exam.getCreatedBy(), NotificationService.TYPE_CONTENT_REJECTED,
                "Exam rejected",
                "Your exam \"" + exam.getTitle() + "\" was rejected" + (reason != null && !reason.isBlank() ? ": " + reason : "."),
                null);
    }
}
