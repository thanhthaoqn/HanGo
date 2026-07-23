package com.hango.hango_backend.service;

import com.hango.hango_backend.dto.CourseDetailDTO;
import com.hango.hango_backend.dto.CourseLessonDTO;
import com.hango.hango_backend.dto.CourseSessionDTO;
import com.hango.hango_backend.dto.CourseSummaryDTO;
import com.hango.hango_backend.entity.Course;
import com.hango.hango_backend.entity.Enrollment;
import com.hango.hango_backend.entity.Lesson;
import com.hango.hango_backend.entity.LessonProgress;
import com.hango.hango_backend.entity.LessonQuizAttempt;
import com.hango.hango_backend.entity.Section;
import com.hango.hango_backend.entity.User;
import com.hango.hango_backend.entity.CourseRating;
import com.hango.hango_backend.repository.CourseRatingRepository;
import com.hango.hango_backend.repository.CourseRepository;
import com.hango.hango_backend.repository.EnrollmentRepository;
import com.hango.hango_backend.repository.LessonProgressRepository;
import com.hango.hango_backend.repository.LessonQuizAttemptRepository;
import com.hango.hango_backend.repository.LessonRepository;
import com.hango.hango_backend.repository.SectionRepository;
import com.hango.hango_backend.repository.UserRepository;
import com.hango.hango_backend.repository.TrainerProfileRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.HashSet;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.Set;
import java.util.stream.Collectors;

@Service
@RequiredArgsConstructor
public class CourseServiceImpl implements CourseService {

    private final CourseRepository courseRepository;
    private final SectionRepository sectionRepository;
    private final LessonRepository lessonRepository;
    private final EnrollmentRepository enrollmentRepository;
    private final UserRepository userRepository;
    private final LessonProgressRepository lessonProgressRepository;
    private final LessonQuizAttemptRepository lessonQuizAttemptRepository;
    private final CourseRatingRepository courseRatingRepository;
    private final TrainerProfileRepository trainerProfileRepository;

    @Override
    public List<CourseSummaryDTO> getCourses(String search, String filterType, String difficulty) {
        Long enrolledUserId = null;
        String enrollmentStatus = null;
        
        if ("ENROLLED".equalsIgnoreCase(filterType) || "IN_PROGRESS".equalsIgnoreCase(filterType)) {
            org.springframework.security.core.Authentication auth = org.springframework.security.core.context.SecurityContextHolder.getContext().getAuthentication();
            if (auth != null && auth.getPrincipal() instanceof com.hango.hango_backend.sercurity.UserDetailsImpl) {
                enrolledUserId = ((com.hango.hango_backend.sercurity.UserDetailsImpl) auth.getPrincipal()).getId();
                if ("IN_PROGRESS".equalsIgnoreCase(filterType)) {
                    enrollmentStatus = "ENROLLED";
                }
            }
        } else if ("COMPLETED".equalsIgnoreCase(filterType)) {
            org.springframework.security.core.Authentication auth = org.springframework.security.core.context.SecurityContextHolder.getContext().getAuthentication();
            if (auth != null && auth.getPrincipal() instanceof com.hango.hango_backend.sercurity.UserDetailsImpl) {
                enrolledUserId = ((com.hango.hango_backend.sercurity.UserDetailsImpl) auth.getPrincipal()).getId();
                enrollmentStatus = "COMPLETED";
            }
        }

        // Difficulty: "ALL" means no filter. Otherwise "EASY", "MEDIUM", "HARD" etc.
        String diffFilter = null;
        if (difficulty != null && !difficulty.equalsIgnoreCase("ALL")) {
            diffFilter = difficulty.toUpperCase();
        }

        List<CourseSummaryDTO> dtos = courseRepository.findCoursesWithFilters(search, diffFilter, enrolledUserId, enrollmentStatus);
        for (CourseSummaryDTO dto : dtos) {
            Course c = courseRepository.findById(dto.getId()).orElse(null);
            if (c != null) {
                List<String> catNames = new ArrayList<>();
                if (c.getCategories() != null && !c.getCategories().isEmpty()) {
                    for (com.hango.hango_backend.entity.SystemParameter sp : c.getCategories()) {
                        catNames.add(sp.getParamValue());
                    }
                } else if (c.getCategory() != null) {
                    catNames.add(c.getCategory().getParamValue());
                }
                dto.setCategories(catNames);
                if (dto.getCategoryName() == null || dto.getCategoryName().isEmpty()) {
                    dto.setCategoryName(catNames.isEmpty() ? "" : String.join(", ", catNames));
                }
            }
        }
        return dtos;
    }

    @Override
    @Transactional(readOnly = true)
    public CourseDetailDTO getCourseDetail(Long id, Long currentUserId) {
        Course course = courseRepository.findById(id)
                .orElseThrow(() -> new RuntimeException("Course not found with ID: " + id));

        if (course.getDeletedAt() != null) {
            throw new RuntimeException("Course not found");
        }


        boolean isEnrolled = false;

        if (!"PUBLISHED".equalsIgnoreCase(course.getStatus())) {
            if (currentUserId == null || course.getCreator() == null || !course.getCreator().getId().equals(currentUserId)) {
                throw new RuntimeException("Course not found");
            }
        }

        Set<Long> completedLessonIds = new HashSet<>();
        boolean hasNewVersionAvailable = false;
        Long latestPublishedCourseId = null;
        String latestPublishedVersion = null;
 
        if (currentUserId != null) {
            Optional<Enrollment> enrollmentOpt = enrollmentRepository.findByUserIdAndCourseId(currentUserId, id);
            isEnrolled = enrollmentOpt.isPresent();
            completedLessonIds.addAll(lessonProgressRepository.findCompletedLessonIdsByUserIdAndCourseId(currentUserId, id));

            if (isEnrolled) {
                Enrollment enrollment = enrollmentOpt.get();
                Long enrolledVerId = enrollment.getEnrolledVersionId() != null ? enrollment.getEnrolledVersionId() : course.getId();

                Long targetLatestId = course.getLatestVersionId();
                Course latestCourse = null;
                if (targetLatestId != null) {
                    latestCourse = courseRepository.findById(targetLatestId).orElse(null);
                } else if (course.getCode() != null && !course.getCode().isBlank()) {
                    List<Course> publishedVersions = courseRepository.findPublishedByCodeOrderByPublishedAtDesc(course.getCode());
                    if (!publishedVersions.isEmpty()) {
                        latestCourse = publishedVersions.get(0);
                    }
                }

                if (latestCourse != null && !latestCourse.getId().equals(enrolledVerId)) {
                    hasNewVersionAvailable = true;
                    latestPublishedCourseId = latestCourse.getId();
                    latestPublishedVersion = latestCourse.getVersion();
                }
            }
        }
 
        List<Section> sections = sectionRepository.findByCourseIdOrderByDisplayOrderAsc(id);
        
        List<CourseSessionDTO> sessionDTOs = sections.stream().map(section -> {
            List<Lesson> lessons = lessonRepository.findBySectionIdOrderByDisplayOrderAsc(section.getId());
            List<CourseLessonDTO> lessonDTOs = lessons.stream().map(lesson -> {
                    Long examId = lesson.getExam() != null ? lesson.getExam().getId() : null;
                    int qCount = 0;
                    if ("quiz".equalsIgnoreCase(lesson.getLessonType()) || "practice".equalsIgnoreCase(lesson.getLessonType())) {
                        qCount = lessonRepository.countQuestionsByLessonId(lesson.getId());
                    }
                    int estTime = lesson.getEstimatedTime() != null ? lesson.getEstimatedTime() 
                                  : ("quiz".equalsIgnoreCase(lesson.getLessonType()) ? (10 + qCount * 2) : 15);
                    return CourseLessonDTO.builder()
                        .id(lesson.getId())
                        .title(lesson.getTitle())
                        .orderIndex(lesson.getDisplayOrder())
                        .itemType(lesson.getLessonType())
                        .examId(examId)
                        .questionCount(qCount)
                        .isCompleted(completedLessonIds.contains(lesson.getId()))
                        .description(lesson.getDescription())
                        .questionText(lesson.getContent())
                        .pdfName(lesson.getPdfName())
                        .questionImageUrl(lesson.getQuestionImageUrl())
                        .estimatedTime(estTime)
                        .build();
                }).collect(Collectors.toList());

            return CourseSessionDTO.builder()
                    .id(section.getId())
                    .title(section.getTitle())
                    .description(section.getDescription())
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
        String difficultyKey = "";
        try {
            if (course.getDifficulty() != null) {
                difficultyName = course.getDifficulty().getParamValue();
                difficultyKey = course.getDifficulty().getParamKey();
            }
        } catch (jakarta.persistence.EntityNotFoundException e) {
            // Ignore
        }

        List<String> categoryKeys = new ArrayList<>();
        List<String> categoryNames = new ArrayList<>();
        try {
            if (course.getCategories() != null && !course.getCategories().isEmpty()) {
                for (com.hango.hango_backend.entity.SystemParameter sp : course.getCategories()) {
                    categoryKeys.add(sp.getParamKey());
                    categoryNames.add(sp.getParamValue());
                }
            } else if (course.getCategory() != null) {
                categoryKeys.add(course.getCategory().getParamKey());
                categoryNames.add(course.getCategory().getParamValue());
            }
        } catch (jakarta.persistence.EntityNotFoundException e) {
            // Ignore
        }

        String categoryKey = categoryKeys.isEmpty() ? "" : categoryKeys.get(0);
        String categoryName = categoryNames.isEmpty() ? "" : String.join(", ", categoryNames);

        // Calculate average rating dynamically from DB reviews/ratings
        double averageRating = 0.0;
        List<CourseRating> ratings = courseRatingRepository.findByCourseIdOrderByCreatedAtDesc(id);
        if (!ratings.isEmpty()) {
            double sum = 0;
            for (CourseRating r : ratings) {
                sum += (r.getRating() != null ? r.getRating() : 0);
            }
            averageRating = sum / ratings.size();
            // Round to 1 decimal place
            averageRating = Math.round(averageRating * 10.0) / 10.0;
        }

        int estimatedDuration = course.getEstimatedDuration() != null ? course.getEstimatedDuration() : 12;
        return CourseDetailDTO.builder()
                .id(course.getId())
                .title(course.getTitle())
                .code(course.getCode())
                .creatorName(creatorName)
                .difficultyName(difficultyName)
                .difficultyKey(difficultyKey)
                .categoryKey(categoryKey)
                .categoryName(categoryName)
                .categoryKeys(categoryKeys)
                .categoryNames(categoryNames)
                .thumbnailUrl(course.getThumbnailUrl())
                .rating(averageRating)
                .learnersCount(learnersCount)
                .description(course.getDescription())
                .objectives(course.getObjectives())
                .price(course.getPrice())
                .version(course.getVersion())
                .isEnrolled(isEnrolled)
                .hasNewVersionAvailable(hasNewVersionAvailable)
                .latestPublishedCourseId(latestPublishedCourseId)
                .latestPublishedVersion(latestPublishedVersion)
                .estimatedDuration(estimatedDuration)
                .price(course.getPrice())
                .sessions(sessionDTOs)
                .build();
    }

    @Override
    @Transactional
    public void enrollCourse(Long courseId, Long userId) {
        Course requestedCourse = courseRepository.findById(courseId)
                .orElseThrow(() -> new RuntimeException("Course not found"));

        Long actualCourseId = (requestedCourse.getLatestVersionId() != null)
                ? requestedCourse.getLatestVersionId()
                : requestedCourse.getId();

        if (enrollmentRepository.existsByUserIdAndCourseId(userId, actualCourseId)) {
            throw new RuntimeException("User is already enrolled in this course");
        }

        User user = userRepository.findById(userId)
                .orElseThrow(() -> new RuntimeException("User not found"));

        Course courseToEnroll = actualCourseId.equals(courseId)
                ? requestedCourse
                : courseRepository.findById(actualCourseId).orElse(requestedCourse);

        if (courseToEnroll.getCreator() != null) {
            com.hango.hango_backend.entity.TrainerProfile profile = trainerProfileRepository.findById(courseToEnroll.getCreator().getId()).orElse(null);
            if (profile == null || !"VERIFIED".equalsIgnoreCase(profile.getStatus())) {
                throw new RuntimeException("Khóa học chưa được xuất bản hoặc giáo viên chưa được phê duyệt.");
            }
        }

        Enrollment enrollment = Enrollment.builder()
                .user(user)
                .course(courseToEnroll)
                .enrolledVersionId(courseToEnroll.getId())
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

    @Override
    @Transactional
    public void switchCourseVersion(Long courseId, Long userId) {
        Enrollment currentEnrollment = enrollmentRepository.findByUserIdAndCourseId(userId, courseId)
                .orElseThrow(() -> new RuntimeException("Enrollment not found for this course"));

        Course currentCourse = currentEnrollment.getCourse();
        if (currentCourse == null) {
            throw new RuntimeException("Course not found for enrollment");
        }

        Course latestPublishedCourse = null;
        if (currentCourse.getLatestVersionId() != null) {
            latestPublishedCourse = courseRepository.findById(currentCourse.getLatestVersionId()).orElse(null);
        }

        if (latestPublishedCourse == null && currentCourse.getCode() != null && !currentCourse.getCode().isBlank()) {
            List<Course> publishedVersions = courseRepository.findPublishedByCodeOrderByPublishedAtDesc(currentCourse.getCode());
            if (!publishedVersions.isEmpty()) {
                latestPublishedCourse = publishedVersions.get(0);
            }
        }

        if (latestPublishedCourse == null) {
            throw new RuntimeException("No published version available for this course");
        }

        if (latestPublishedCourse.getId().equals(currentCourse.getId())) {
            throw new RuntimeException("You are already on the latest course version");
        }

        // Map completed lesson progress from the old course to the latest published course version
        List<LessonProgress> completedProgress = lessonProgressRepository.findCompletedProgressByUserIdAndCourseId(userId, courseId);
        Map<String, LessonProgress> progressByLessonCode = new HashMap<>();
        Map<String, LessonProgress> progressByLessonTitle = new HashMap<>();

        for (LessonProgress progress : completedProgress) {
            Lesson lesson = progress.getLesson();
            if (lesson == null) continue;
            if (lesson.getCode() != null && !lesson.getCode().isBlank()) {
                progressByLessonCode.put(lesson.getCode().trim().toLowerCase(), progress);
            } else if (lesson.getTitle() != null && !lesson.getTitle().isBlank()) {
                progressByLessonTitle.put(lesson.getTitle().trim().toLowerCase(), progress);
            }
        }

        int totalLessons = 0;
        int carriedCompletedLessons = 0;
        List<Section> newSections = sectionRepository.findByCourseIdOrderByDisplayOrderAsc(latestPublishedCourse.getId());
        for (Section section : newSections) {
            List<Lesson> lessons = lessonRepository.findBySectionIdOrderByDisplayOrderAsc(section.getId());
            totalLessons += lessons.size();
            for (Lesson lesson : lessons) {
                boolean shouldCarry = false;
                LessonProgress matchedProgress = null;
                if (lesson.getCode() != null && !lesson.getCode().isBlank()) {
                    matchedProgress = progressByLessonCode.get(lesson.getCode().trim().toLowerCase());
                }
                if (matchedProgress == null && lesson.getTitle() != null && !lesson.getTitle().isBlank()) {
                    matchedProgress = progressByLessonTitle.get(lesson.getTitle().trim().toLowerCase());
                }
                if (matchedProgress != null) {
                    shouldCarry = true;
                }

                if (shouldCarry && !lessonProgressRepository.existsByUserIdAndLessonIdAndIsCompletedTrue(userId, lesson.getId())) {
                    LessonProgress newProgress = LessonProgress.builder()
                            .user(currentEnrollment.getUser())
                            .lesson(lesson)
                            .isCompleted(true)
                            .completedAt(matchedProgress.getCompletedAt())
                            .build();
                    lessonProgressRepository.save(newProgress);
                    carriedCompletedLessons++;
                } else if (shouldCarry) {
                    carriedCompletedLessons++;
                }
            }
        }

        currentEnrollment.setCourse(latestPublishedCourse);
        currentEnrollment.setEnrolledVersionId(latestPublishedCourse.getId());
        if (totalLessons > 0) {
            BigDecimal percentage = BigDecimal.valueOf((carriedCompletedLessons * 100.0) / totalLessons)
                    .setScale(2, RoundingMode.HALF_UP);
            currentEnrollment.setProgressPercentage(percentage);
            if (percentage.compareTo(BigDecimal.valueOf(100)) >= 0) {
                currentEnrollment.setStatus("COMPLETED");
            }
        } else {
            currentEnrollment.setProgressPercentage(BigDecimal.ZERO);
        }

        enrollmentRepository.save(currentEnrollment);
    }

    @Override
    @Transactional(readOnly = true)
    public List<Map<String, Object>> getCourseVersionHistory(Long courseId) {
        Course course = courseRepository.findById(courseId)
                .orElseThrow(() -> new RuntimeException("Course not found with ID: " + courseId));

        if (course.getCode() == null || course.getCode().isBlank()) {
            List<Map<String, Object>> singleVersion = new ArrayList<>();
            Map<String, Object> versionInfo = new LinkedHashMap<>();
            versionInfo.put("id", course.getId());
            versionInfo.put("version", course.getVersion());
            versionInfo.put("status", course.getStatus());
            versionInfo.put("publishedAt", course.getPublishedAt());
            versionInfo.put("title", course.getTitle());
            versionInfo.put("isCurrent", true);
            singleVersion.add(versionInfo);
            return singleVersion;
        }

        List<Course> allVersions = courseRepository.findByCodeAndDeletedAtIsNullOrderByCreatedAtDesc(course.getCode());
        List<Map<String, Object>> versionHistory = new ArrayList<>();
        
        for (Course version : allVersions) {
            Map<String, Object> versionInfo = new LinkedHashMap<>();
            versionInfo.put("id", version.getId());
            versionInfo.put("version", version.getVersion());
            versionInfo.put("status", version.getStatus());
            versionInfo.put("publishedAt", version.getPublishedAt());
            versionInfo.put("title", version.getTitle());
            versionInfo.put("isCurrent", version.getId().equals(courseId));
            versionInfo.put("learnersCount", enrollmentRepository.countByCourseId(version.getId()));
            versionHistory.add(versionInfo);
        }
        
        return versionHistory;
    }
}
