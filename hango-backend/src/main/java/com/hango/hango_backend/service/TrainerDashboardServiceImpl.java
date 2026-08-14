package com.hango.hango_backend.service;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.hango.hango_backend.dto.TrainerCourseDTO;
import com.hango.hango_backend.dto.TrainerDashboardSummaryDTO;
import com.hango.hango_backend.dto.TrainerCourseDetailDTO;
import com.hango.hango_backend.dto.TrainerCoursesResponseDTO;
import com.hango.hango_backend.entity.User;
import com.hango.hango_backend.repository.*;
import com.hango.hango_backend.util.ExamQuestionDiffUtil;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.stream.Collectors;

@Service
@RequiredArgsConstructor
public class TrainerDashboardServiceImpl implements TrainerDashboardService {

    private final UserRepository userRepository;
    private final CourseRepository courseRepository;
    private final EnrollmentRepository enrollmentRepository;
    private final ExamRepository examRepository;
    private final ExamQuestionRepository examQuestionRepository;
    private final SystemParameterRepository systemParameterRepository;
    private final SectionRepository sectionRepository;
    private final LessonRepository lessonRepository;
    private final TrainerQuestionService trainerQuestionService;
    private final QuestionRepository questionRepository;
    private final TrainerProfileRepository trainerProfileRepository;
    private final PaymentRepository paymentRepository;
    private final CourseRatingRepository courseRatingRepository;
    private final YouTubeTranscriptService youtubeTranscriptService;
    private final NotificationService notificationService;
    private final CloudinaryService cloudinaryService;
    private final ExamHistoryService examHistoryService;
    private final ObjectMapper objectMapper = new ObjectMapper();

    private String getBaseCode(String code, Long id) {
        if (code == null || code.isBlank()) return String.valueOf(id);
        return code.replaceAll("-V\\d+$", "").toUpperCase();
    }

    @Override
    @Transactional(readOnly = true)
    public TrainerDashboardSummaryDTO getTrainerDashboardSummary(String email) {
        User user = userRepository.findByEmail(email)
                .orElseThrow(() -> new RuntimeException("User not found with email: " + email));
        Long trainerId = user.getId();

        long learnersCount = enrollmentRepository.countDistinctStudentsByCourseCreatorId(trainerId);
        long examsCount = examRepository.countByCreatedByIdAndDeletedAtIsNull(trainerId);

        java.math.BigDecimal totalRevenue = paymentRepository.sumRevenueByTrainerId(trainerId);
        if (totalRevenue == null) {
            totalRevenue = java.math.BigDecimal.ZERO;
        }

        Double averageRating = courseRatingRepository.getAverageRatingByTrainerId(trainerId);
        if (averageRating == null) {
            averageRating = 0.0;
        }

        List<TrainerCourseDetailProjection> baseProjections = courseRepository.findTrainerCoursesDetailBase(trainerId,
                "ALL", null);
        
        Map<String, List<TrainerCourseDetailProjection>> groupedByCode = baseProjections.stream()
                .collect(Collectors.groupingBy(p -> getBaseCode(p.getCode(), p.getId())));

        long coursesCount = groupedByCode.values().stream()
                .filter(group -> group.stream().anyMatch(p -> "PUBLISHED".equalsIgnoreCase(p.getStatus())))
                .count();

        List<Long> allFamilyIds = baseProjections.stream()
                .map(p -> p.getId())
                .collect(Collectors.toList());
                
        Map<Long, Double> sumMap = new java.util.HashMap<>();
        Map<Long, Long> countMap = new java.util.HashMap<>();
        
        if (!allFamilyIds.isEmpty()) {
            List<Object[]> ratingStats = courseRatingRepository.getRatingStatsByCourseIds(allFamilyIds);
            for (Object[] stat : ratingStats) {
                Long courseId = (Long) stat[0];
                Double avg = (Double) stat[1];
                Long cnt = (Long) stat[2];
                if (avg != null && cnt != null && cnt > 0) {
                    sumMap.put(courseId, avg * cnt);
                    countMap.put(courseId, cnt);
                }
            }
        }

        List<TrainerCourseDTO> courses = groupedByCode.values().stream()
                .map(group -> {
                    // Try to find the latest PUBLISHED version
                    TrainerCourseDetailProjection latest = group.stream()
                            .filter(p -> "PUBLISHED".equalsIgnoreCase(p.getStatus()))
                            .max((p1, p2) -> {
                                if (p1.getCreatedAt() == null) return -1;
                                if (p2.getCreatedAt() == null) return 1;
                                return p1.getCreatedAt().compareTo(p2.getCreatedAt());
                            })
                            // If no PUBLISHED version, fallback to the latest version of ANY status
                            .orElseGet(() -> group.stream()
                                    .max((p1, p2) -> {
                                        if (p1.getCreatedAt() == null) return -1;
                                        if (p2.getCreatedAt() == null) return 1;
                                        return p1.getCreatedAt().compareTo(p2.getCreatedAt());
                                    }).orElse(group.get(0))
                            );
                            
                    List<Long> familyIds = group.stream().map(com.hango.hango_backend.repository.TrainerCourseDetailProjection::getId).collect(Collectors.toList());
                    double totalSum = 0;
                    long totalCount = 0;
                    for (Long fid : familyIds) {
                        if (sumMap.containsKey(fid)) {
                            totalSum += sumMap.get(fid);
                            totalCount += countMap.get(fid);
                        }
                    }
                    Double avgRating = totalCount > 0 ? totalSum / totalCount : 0.0;
                    
                    return TrainerCourseDTO.builder()
                            .id(latest.getId())
                            .title(latest.getTitle())
                            .learnersCount(group.stream().mapToLong(p -> p.getLearnersCount() != null ? p.getLearnersCount() : 0L).sum())
                            .lessonsCount(latest.getLessonsCount() != null ? latest.getLessonsCount() : 0L)
                            .thumbnailUrl(latest.getThumbnailUrl())
                            .versionsCount((long) group.size())
                            .price(latest.getPrice() != null ? latest.getPrice() : java.math.BigDecimal.ZERO)
                            .rating(avgRating)
                            .build();
                })
                .sorted((c1, c2) -> {
                    int learnerCompare = Long.compare(c2.getLearnersCount(), c1.getLearnersCount());
                    if (learnerCompare != 0) return learnerCompare;
                    int ratingCompare = Double.compare(c2.getRating() != null ? c2.getRating() : 0.0, c1.getRating() != null ? c1.getRating() : 0.0);
                    if (ratingCompare != 0) return ratingCompare;
                    return c2.getId().compareTo(c1.getId());
                })
                .collect(Collectors.toList());

        // Monthly Revenues
        List<Object[]> rawRevenues = paymentRepository.getRevenueByMonthForCurrentYear(trainerId);
        List<com.hango.hango_backend.dto.MonthlyRevenueDTO> monthlyRevenues = new ArrayList<>();
        for (int i = 1; i <= 12; i++) {
            monthlyRevenues.add(new com.hango.hango_backend.dto.MonthlyRevenueDTO(i, java.math.BigDecimal.ZERO));
        }
        for (Object[] row : rawRevenues) {
            int month = ((Number) row[0]).intValue();
            java.math.BigDecimal rev = (java.math.BigDecimal) row[1];
            if (month >= 1 && month <= 12) {
                monthlyRevenues.get(month - 1).setRevenue(rev);
            }
        }

        // Recent Activities
        List<com.hango.hango_backend.dto.RecentActivityDTO> recentActivities = new ArrayList<>();

        List<com.hango.hango_backend.entity.Payment> recentPayments = paymentRepository
                .findTop20ByCourseCreatorIdAndStatusOrderByCreatedAtDesc(trainerId, "SUCCESS");
        for (com.hango.hango_backend.entity.Payment p : recentPayments) {
            recentActivities.add(com.hango.hango_backend.dto.RecentActivityDTO.builder()
                    .type("PAYMENT")
                    .action("Sold course")
                    .target(p.getCourse().getTitle())
                    .timestamp(p.getCreatedAt())
                    .build());
        }

        List<com.hango.hango_backend.entity.Enrollment> recentEnrollments = enrollmentRepository
                .findTop20ByCourseCreatorIdOrderByEnrolledAtDesc(trainerId);
        for (com.hango.hango_backend.entity.Enrollment e : recentEnrollments) {
            recentActivities.add(com.hango.hango_backend.dto.RecentActivityDTO.builder()
                    .type("ENROLLMENT")
                    .action("New student enrolled in")
                    .target(e.getCourse().getTitle())
                    .timestamp(e.getEnrolledAt())
                    .build());
        }

        List<com.hango.hango_backend.entity.CourseRating> recentRatings = courseRatingRepository
                .findTop20ByCourseCreatorIdOrderByCreatedAtDesc(trainerId);
        for (com.hango.hango_backend.entity.CourseRating r : recentRatings) {
            recentActivities.add(com.hango.hango_backend.dto.RecentActivityDTO.builder()
                    .type("RATING")
                    .action("New " + r.getRating() + "-star review on")
                    .target(r.getCourse().getTitle())
                    .timestamp(r.getCreatedAt())
                    .build());
        }

        recentActivities.sort((a1, a2) -> {
            if (a1.getTimestamp() == null)
                return 1;
            if (a2.getTimestamp() == null)
                return -1;
            return a2.getTimestamp().compareTo(a1.getTimestamp());
        });

        if (recentActivities.size() > 20) {
            recentActivities = recentActivities.subList(0, 20);
        }

        java.time.LocalDateTime now = java.time.LocalDateTime.now();
        for (com.hango.hango_backend.dto.RecentActivityDTO act : recentActivities) {
            if (act.getTimestamp() != null) {
                long minutes = java.time.Duration.between(act.getTimestamp(), now).toMinutes();
                if (minutes < 60) {
                    act.setTime(minutes + " mins ago");
                } else if (minutes < 1440) {
                    act.setTime((minutes / 60) + " hours ago");
                } else {
                    act.setTime((minutes / 1440) + " days ago");
                }
            } else {
                act.setTime("Unknown");
            }
        }

        return TrainerDashboardSummaryDTO.builder()
                .coursesCount(coursesCount)
                .learnersCount(learnersCount)
                .examsCount(examsCount)
                .totalRevenue(totalRevenue)
                .averageRating(averageRating)
                .courses(courses)
                .recentActivities(recentActivities)
                .monthlyRevenues(monthlyRevenues)
                .build();
    }

    @Override
    @Transactional(readOnly = true)
    public TrainerCoursesResponseDTO getTrainerCourses(String email, String status, String search, String sortBy,
            String timePeriod) {
        User user = userRepository.findByEmail(email)
                .orElseThrow(() -> new RuntimeException("User not found with email: " + email));
        Long trainerId = user.getId();

        // 1. Fetch All courses for the trainer
        List<TrainerCourseDetailProjection> allProjections = courseRepository.findTrainerCoursesDetailBase(trainerId,
                "ALL", null);

        // 2. Group by Root Code and get the Latest Version for each course
        Map<String, List<TrainerCourseDetailProjection>> groupedByCode = allProjections.stream()
                .collect(Collectors.groupingBy(p -> getBaseCode(p.getCode(), p.getId())));

        List<TrainerCourseDetailProjection> latestProjections = groupedByCode.values().stream()
                .map(group -> group.stream()
                        .max((p1, p2) -> {
                            if (p1.getCreatedAt() == null)
                                return -1;
                            if (p2.getCreatedAt() == null)
                                return 1;
                            return p1.getCreatedAt().compareTo(p2.getCreatedAt());
                        }).orElse(group.get(0)))
                .collect(Collectors.toList());

        // 3. Status Counts based on the Latest Versions
        long allCount = latestProjections.size();
        long draftCount = latestProjections.stream().filter(p -> "DRAFT".equalsIgnoreCase(p.getStatus())).count();
        long publishedCount = latestProjections.stream().filter(p -> "PUBLISHED".equalsIgnoreCase(p.getStatus()))
                .count();
        long hiddenCount = latestProjections.stream().filter(p -> "HIDDEN".equalsIgnoreCase(p.getStatus())).count();
        long pendingCount = latestProjections.stream().filter(p -> "PENDING_APPROVAL".equalsIgnoreCase(p.getStatus()))
                .count();
        long rejectedCount = latestProjections.stream().filter(p -> "REJECTED".equalsIgnoreCase(p.getStatus())).count();

        // 4. Apply Filters (Status, Search, Time Period)
        String searchParam = (search == null || search.trim().isEmpty()) ? null : search.trim().toLowerCase();

        List<TrainerCourseDetailProjection> filteredProjections = latestProjections.stream()
                .filter(p -> status.equalsIgnoreCase("ALL") || status.equalsIgnoreCase(p.getStatus()))
                .filter(p -> searchParam == null
                        || (p.getTitle() != null && p.getTitle().toLowerCase().contains(searchParam)))
                .filter(p -> {
                    if (timePeriod == null || timePeriod.equalsIgnoreCase("ALL"))
                        return true;
                    if (p.getCreatedAt() == null)
                        return false;
                    LocalDateTime cutoff = LocalDateTime.now();
                    if (timePeriod.equalsIgnoreCase("THIS_WEEK"))
                        cutoff = cutoff.minusWeeks(1);
                    else if (timePeriod.equalsIgnoreCase("THIS_MONTH"))
                        cutoff = cutoff.minusMonths(1);
                    return p.getCreatedAt().isAfter(cutoff);
                })
                .collect(Collectors.toList());

        // 5. Sort
        if (sortBy != null) {
            if (sortBy.equalsIgnoreCase("OLDEST")) {
                filteredProjections.sort((p1, p2) -> {
                    if (p1.getCreatedAt() == null)
                        return 1;
                    if (p2.getCreatedAt() == null)
                        return -1;
                    return p1.getCreatedAt().compareTo(p2.getCreatedAt());
                });
            } else if (sortBy.equalsIgnoreCase("ALPHABETICAL")) {
                filteredProjections.sort((p1, p2) -> {
                    String t1 = p1.getTitle() != null ? p1.getTitle() : "";
                    String t2 = p2.getTitle() != null ? p2.getTitle() : "";
                    return t1.compareToIgnoreCase(t2);
                });
            } else { // "NEWEST"
                filteredProjections.sort((p1, p2) -> {
                    if (p1.getCreatedAt() == null)
                        return 1;
                    if (p2.getCreatedAt() == null)
                        return -1;
                    return p2.getCreatedAt().compareTo(p1.getCreatedAt());
                });
            }
        } else {
            filteredProjections.sort((p1, p2) -> {
                if (p1.getCreatedAt() == null)
                    return 1;
                if (p2.getCreatedAt() == null)
                    return -1;
                return p2.getCreatedAt().compareTo(p1.getCreatedAt());
            });
        }

        // 6. Map to DTOs
        List<Long> filteredCourseIds = filteredProjections.stream()
                .map(p -> p.getId())
                .collect(Collectors.toList());

        Map<Long, List<String>> courseCategoryKeys = new java.util.HashMap<>();
        Map<Long, List<String>> courseCategoryNames = new java.util.HashMap<>();

        if (!filteredCourseIds.isEmpty()) {
            List<Object[]> multipleCats = courseRepository.findCategoryDetailsByCourseIds(filteredCourseIds);
            for (Object[] row : multipleCats) {
                Long cid = (Long) row[0];
                String key = (String) row[1];
                String val = (String) row[2];
                courseCategoryKeys.computeIfAbsent(cid, k -> new ArrayList<>()).add(key);
                courseCategoryNames.computeIfAbsent(cid, k -> new ArrayList<>()).add(val);
            }
            List<Object[]> singleCats = courseRepository.findSingleCategoryDetailsByCourseIds(filteredCourseIds);
            for (Object[] row : singleCats) {
                Long cid = (Long) row[0];
                String key = (String) row[1];
                String val = (String) row[2];
                if (!courseCategoryKeys.containsKey(cid)) {
                    courseCategoryKeys.computeIfAbsent(cid, k -> new ArrayList<>()).add(key);
                    courseCategoryNames.computeIfAbsent(cid, k -> new ArrayList<>()).add(val);
                }
            }
        }

        List<TrainerCourseDetailDTO> courses = filteredProjections.stream().map(p -> {
            List<String> catKeys = courseCategoryKeys.getOrDefault(p.getId(), new ArrayList<>());
            List<String> catNames = courseCategoryNames.getOrDefault(p.getId(), new ArrayList<>());

            return TrainerCourseDetailDTO.builder()
                    .id(p.getId())
                    .title(p.getTitle())
                    .status(p.getStatus())
                    .description(p.getDescription())
                    .categoryKeys(catKeys)
                    .categories(catNames)
                    .learnersCount(p.getLearnersCount() != null ? p.getLearnersCount() : 0L)
                    .lessonsCount(p.getLessonsCount() != null ? p.getLessonsCount() : 0L)
                    .thumbnailUrl(p.getThumbnailUrl())
                    .createdAt(p.getCreatedAt())
                    .code(p.getCode())
                    .version(p.getVersion())
                    .parentId(p.getParentId())
                    .rejectionReason(p.getRejectionReason())
                    .price(p.getPrice())
                    .suggestedPrice(p.getSuggestedPrice())
                    .priceNote(p.getPriceNote())
                    .build();
        }).collect(Collectors.toList());

        return TrainerCoursesResponseDTO.builder()
                .allCount(allCount)
                .draftCount(draftCount)
                .publishedCount(publishedCount)
                .hiddenCount(hiddenCount)
                .pendingCount(pendingCount)
                .rejectedCount(rejectedCount)
                .courses(courses)
                .build();
    }

    private java.util.Set<com.hango.hango_backend.entity.SystemParameter> resolveCategories(
            com.hango.hango_backend.dto.TrainerCreateCourseRequestDTO request) {
        List<String> rawKeys = request.getCategoryKeys();
        if (rawKeys == null || rawKeys.isEmpty()) {
            if (request.getCategoryKey() != null && !request.getCategoryKey().isBlank()) {
                rawKeys = List.of(request.getCategoryKey());
            } else {
                rawKeys = new ArrayList<>();
            }
        }

        if (rawKeys.isEmpty() || rawKeys.size() > 3) {
            throw new IllegalArgumentException("Course must have between 1 and 3 categories selected");
        }

        java.util.Set<com.hango.hango_backend.entity.SystemParameter> categorySet = new java.util.HashSet<>();
        for (String rawKey : rawKeys) {
            if (rawKey == null || rawKey.isBlank())
                continue;
            String catKey = rawKey.toUpperCase().trim();
            if ("READING".equals(catKey)) {
                catKey = "READING_COMPREHENSION";
            } else if ("PRONUNCIATION".equals(catKey) || "SPEAKING".equals(catKey)) {
                catKey = "PRONUNCIATION";
            } else if ("WRITING".equals(catKey)) {
                catKey = "GRAMMAR";
            }

            String finalKey = catKey;
            com.hango.hango_backend.entity.SystemParameter param = systemParameterRepository
                    .findByParamTypeAndParamKey("COURSE_CATEGORY", finalKey)
                    .orElseThrow(() -> new RuntimeException("Category not found: " + finalKey));
            categorySet.add(param);
        }

        if (categorySet.isEmpty()) {
            throw new IllegalArgumentException("Course must have between 1 and 3 valid categories selected");
        }

        return categorySet;
    }

    @Override
    @Transactional
    public void createTrainerCourse(String email, com.hango.hango_backend.dto.TrainerCreateCourseRequestDTO request) {
        User user = userRepository.findByEmail(email)
                .orElseThrow(() -> new RuntimeException("User not found with email: " + email));

        java.util.Set<com.hango.hango_backend.entity.SystemParameter> categorySet = resolveCategories(request);
        com.hango.hango_backend.entity.SystemParameter firstCategory = categorySet.iterator().next();

        String diffKey = request.getDifficultyKey() != null ? request.getDifficultyKey().toUpperCase() : "BASIC";
        if ("BEGINNER".equals(diffKey)) {
            diffKey = "BASIC";
        }

        com.hango.hango_backend.entity.SystemParameter difficulty = systemParameterRepository
                .findByParamTypeAndParamKey("ACADEMIC_LEVEL", diffKey)
                .orElseThrow(() -> new RuntimeException("Academic Level not found: " + request.getDifficultyKey()));

        // Auto-generate a unique course code to avoid DB unique constraint violations
        String generatedCode = generateUniqueCourseCode();

        com.hango.hango_backend.entity.TrainerProfile profile = trainerProfileRepository.findById(user.getId()).orElse(null);
        int durationMinutes = request.getEstimatedDuration() != null ? request.getEstimatedDuration() : 0;
        java.math.BigDecimal calculatedPrice = calculateCoursePrice(user.getId(), generatedCode, profile, difficulty, 0, durationMinutes);

        com.hango.hango_backend.entity.Course course = com.hango.hango_backend.entity.Course.builder()
                .title(request.getTitle())
                .code(generatedCode)
                .description(request.getDescription())
                .objectives(request.getObjectives())
                .creator(user)
                .category(firstCategory)
                .categories(categorySet)
                .difficulty(difficulty)
                .thumbnailUrl(request.getThumbnailUrl())
                .price(calculatedPrice)
                .suggestedPrice(calculatedPrice)
                .priceNote("")
                .version("v1")
                .estimatedDuration(request.getEstimatedDuration())
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
    public Long updateTrainerCourse(Long id, String email,
            com.hango.hango_backend.dto.TrainerCreateCourseRequestDTO request) {
        com.hango.hango_backend.entity.Course course = courseRepository.findById(id)
                .orElseThrow(() -> new RuntimeException("Course not found with ID: " + id));

        if (!course.getCreator().getEmail().equalsIgnoreCase(email)) {
            throw new RuntimeException("You are not authorized to edit this course");
        }

        java.util.Set<com.hango.hango_backend.entity.SystemParameter> categorySet = resolveCategories(request);
        com.hango.hango_backend.entity.SystemParameter firstCategory = categorySet.iterator().next();

        String diffKey = request.getDifficultyKey() != null ? request.getDifficultyKey().toUpperCase() : "BASIC";
        if ("BEGINNER".equals(diffKey)) {
            diffKey = "BASIC";
        }

        com.hango.hango_backend.entity.SystemParameter difficulty = systemParameterRepository
                .findByParamTypeAndParamKey("ACADEMIC_LEVEL", diffKey)
                .orElseThrow(() -> new RuntimeException("Academic Level not found: " + request.getDifficultyKey()));

        course.setCategory(firstCategory);
        course.setCategories(categorySet);
        course.setDifficulty(difficulty);

        boolean needsNewDraftVersion = "PUBLISHED".equalsIgnoreCase(course.getStatus());

        List<com.hango.hango_backend.dto.CourseSessionDTO> sessionDTOs = request.getSessions();
        if (sessionDTOs == null) {
            sessionDTOs = new java.util.ArrayList<>();
        }

        com.hango.hango_backend.entity.TrainerProfile profile = trainerProfileRepository.findById(course.getCreator().getId()).orElse(null);
        int lessonCount = 0;
        int durationMinutes = 0;
        if (sessionDTOs != null) {
            for (com.hango.hango_backend.dto.CourseSessionDTO sDto : sessionDTOs) {
                if (sDto.getLessons() != null) {
                    lessonCount += sDto.getLessons().size();
                    for (com.hango.hango_backend.dto.CourseLessonDTO lDto : sDto.getLessons()) {
                        if (lDto.getEstimatedTimeMinutes() != null) {
                            durationMinutes += lDto.getEstimatedTimeMinutes();
                        } else if (lDto.getEstimatedTime() != null) {
                            durationMinutes += lDto.getEstimatedTime();
                        }
                    }
                }
            }
        }
        java.math.BigDecimal calculatedPrice = calculateCoursePrice(course.getCreator().getId(), course.getCode(), profile, difficulty, lessonCount, durationMinutes);

        if (needsNewDraftVersion) {
            // Clone V1 → V2: Create a new DRAFT version preserving the original published
            // course (V1).
            // V2 links back to V1 via parentId for version tracking.
            String newVersion = incrementVersion(course.getVersion());
            String baseCode = course.getCode() != null ? course.getCode() : "COURSE";
            if (baseCode.matches(".*-V\\d+$")) {
                baseCode = baseCode.replaceAll("-V\\d+$", "");
            }
            String newCode = baseCode + "-" + newVersion.toUpperCase();

            int suffix = 1;
            String candidateCode = newCode;
            while (courseRepository.existsByCodeIgnoreCase(candidateCode)) {
                candidateCode = newCode + "_" + suffix++;
            }
            newCode = candidateCode;

            com.hango.hango_backend.entity.Course draftCourse = com.hango.hango_backend.entity.Course.builder()
                    .title(request.getTitle())
                    .code(newCode)
                    .description(request.getDescription())
                    .objectives(request.getObjectives())
                    .creator(course.getCreator())
                    .category(firstCategory)
                    .categories(categorySet)
                    .difficulty(difficulty)
                    .thumbnailUrl(request.getThumbnailUrl())
                    .price(calculatedPrice)
                    .priceNote("")
                    .suggestedPrice(calculatedPrice)
                    .version(newVersion)
                    .estimatedDuration(durationMinutes)
                    .status("DRAFT")
                    .parentId(course.getId())
                    .build();

            com.hango.hango_backend.entity.Course savedDraftCourse = courseRepository.save(draftCourse);
            saveSectionsAndLessonsForCourse(savedDraftCourse, sessionDTOs, firstCategory, difficulty);
            return savedDraftCourse.getId();
        }

        course.setTitle(request.getTitle());

        if (request.getCode() != null && !request.getCode().equalsIgnoreCase(course.getCode())) {
            if (courseRepository.existsByCodeIgnoreCaseAndIdNot(request.getCode(), course.getId())) {
                throw new RuntimeException(
                        "Course code " + request.getCode() + " already exists. Please choose another code.");
            }
            course.setCode(request.getCode());
        }
        course.setDescription(request.getDescription());
        course.setObjectives(request.getObjectives());
        course.setCategory(firstCategory);
        course.setCategories(categorySet);
        course.setDifficulty(difficulty);
        course.setPrice(calculatedPrice);
        course.setSuggestedPrice(calculatedPrice);
        course.setPriceNote("");
        course.setEstimatedDuration(durationMinutes);
        if (request.getThumbnailUrl() != null && !request.getThumbnailUrl().isEmpty()) {
            if (course.getThumbnailUrl() != null && !course.getThumbnailUrl().equals(request.getThumbnailUrl())) {
                cloudinaryService.deleteFile(course.getThumbnailUrl());
            }
            course.setThumbnailUrl(request.getThumbnailUrl());
        }

        com.hango.hango_backend.entity.Course savedCourse = courseRepository.save(course);

        // Update sections and lessons in place for the existing course record.
        List<com.hango.hango_backend.entity.Section> existingSections = sectionRepository
                .findByCourseIdOrderByDisplayOrderAsc(savedCourse.getId());

        java.util.Set<Long> requestSectionIds = sessionDTOs.stream()
                .map(com.hango.hango_backend.dto.CourseSessionDTO::getId)
                .filter(sid -> sid != null && sid < 1000000000000L)
                .collect(java.util.stream.Collectors.toSet());

        // Delete sections that were removed
        for (com.hango.hango_backend.entity.Section existingSection : existingSections) {
            if (!requestSectionIds.contains(existingSection.getId())) {
                List<com.hango.hango_backend.entity.Lesson> lessonsToDel = lessonRepository.findBySectionIdOrderByDisplayOrderAsc(existingSection.getId());
                for (com.hango.hango_backend.entity.Lesson l : lessonsToDel) {
                    if (l.getContent() != null) cloudinaryService.deleteFile(l.getContent());
                }
                sectionRepository.delete(existingSection);
            }
        }

        for (int sIdx = 0; sIdx < sessionDTOs.size(); sIdx++) {
            com.hango.hango_backend.dto.CourseSessionDTO sDto = sessionDTOs.get(sIdx);
            com.hango.hango_backend.entity.Section section;
            if (sDto.getId() != null && sDto.getId() < 1000000000000L) {
                section = sectionRepository.findById(sDto.getId()).orElse(new com.hango.hango_backend.entity.Section());
            } else {
                section = new com.hango.hango_backend.entity.Section();
            }
            section.setCourse(savedCourse);
            section.setTitle(sDto.getTitle());
            section.setDescription(sDto.getDescription());
            section.setDisplayOrder(sIdx + 1);
            section.setVersion(savedCourse.getVersion());

            final com.hango.hango_backend.entity.Section savedSection = sectionRepository.save(section);

            List<com.hango.hango_backend.entity.Lesson> existingLessons = lessonRepository
                    .findBySectionIdOrderByDisplayOrderAsc(savedSection.getId());
            List<com.hango.hango_backend.dto.CourseLessonDTO> lessonDTOs = sDto.getLessons();
            if (lessonDTOs == null) {
                lessonDTOs = new java.util.ArrayList<>();
            }

            java.util.Set<Long> requestLessonIds = lessonDTOs.stream()
                    .map(com.hango.hango_backend.dto.CourseLessonDTO::getId)
                    .filter(lid -> lid != null && lid < 1000000000000L)
                    .collect(java.util.stream.Collectors.toSet());

            for (com.hango.hango_backend.entity.Lesson existingLesson : existingLessons) {
                if (!requestLessonIds.contains(existingLesson.getId())) {
                    if (existingLesson.getContent() != null) cloudinaryService.deleteFile(existingLesson.getContent());
                    lessonRepository.delete(existingLesson);
                }
            }

            for (int lIdx = 0; lIdx < lessonDTOs.size(); lIdx++) {
                com.hango.hango_backend.dto.CourseLessonDTO lDto = lessonDTOs.get(lIdx);
                com.hango.hango_backend.entity.Lesson lesson;
                if (lDto.getId() != null && lDto.getId() < 1000000000000L) {
                    lesson = lessonRepository.findById(lDto.getId())
                            .orElse(new com.hango.hango_backend.entity.Lesson());
                            
                    // Check if old content changed
                    String oldContent = lesson.getContent();
                    
                    String newContent = lDto.getQuestionText();
                    
                    if (oldContent != null && !oldContent.equals(newContent)) {
                        cloudinaryService.deleteFile(oldContent);
                    }
                } else {
                    lesson = new com.hango.hango_backend.entity.Lesson();
                }
                lesson.setSection(savedSection);
                lesson.setTitle(lDto.getTitle());
                String type = lDto.getItemType();
                if (lDto.getQuestionText() != null && lDto.getQuestionText().contains("youtu")) {
                    type = "video";
                }
                lesson.setLessonType(type != null ? type : "video");
                lesson.setDisplayOrder(lIdx + 1);
                lesson.setDescription(lDto.getDescription());
                lesson.setContent(lDto.getQuestionText());

                if (lDto.getVideoTranscript() != null && !lDto.getVideoTranscript().isBlank()) {
                    lesson.setVideoTranscript(lDto.getVideoTranscript());
                } else if (lDto.getQuestionText() != null && lDto.getQuestionText().contains("youtu")) {
                    String transcript = youtubeTranscriptService.fetchTranscript(lDto.getQuestionText());
                    lesson.setVideoTranscript(transcript);
                } else {
                    lesson.setVideoTranscript(null);
                }

                lesson.setPdfName(lDto.getPdfName());
                lesson.setQuestionImageUrl(lDto.getQuestionImageUrl());
                
                lesson.setEstimatedTime(lDto.getEstimatedTime());
                lesson.setCode(lDto.getLessonCode());
                lesson.setMediaDurationSeconds(lDto.getMediaDurationSeconds());
                lesson.setMediaSizeBytes(lDto.getMediaSizeBytes());
                lesson.setEstimatedTimeMinutes(lDto.getEstimatedTimeMinutes());
                lesson.setLearningObjectives(lDto.getLearningObjectives());

                lesson.setVersion(savedCourse.getVersion());
                lesson.setSkill(savedCourse.getCategory());
                lesson.setDifficulty(savedCourse.getDifficulty());

                if (lDto.getExamId() != null) {
                    lesson.setExam(examRepository.findById(lDto.getExamId()).orElse(null));
                }
                lessonRepository.save(lesson);
            }
        }

        return savedCourse.getId();
    }

    private void saveSectionsAndLessonsForCourse(com.hango.hango_backend.entity.Course course,
            List<com.hango.hango_backend.dto.CourseSessionDTO> sessionDTOs,
            com.hango.hango_backend.entity.SystemParameter category,
            com.hango.hango_backend.entity.SystemParameter difficulty) {
        for (int sIdx = 0; sIdx < sessionDTOs.size(); sIdx++) {
            com.hango.hango_backend.dto.CourseSessionDTO sDto = sessionDTOs.get(sIdx);
            com.hango.hango_backend.entity.Section section = com.hango.hango_backend.entity.Section.builder()
                    .course(course)
                    .title(sDto.getTitle())
                    .description(sDto.getDescription())
                    .displayOrder(sIdx + 1)
                    .version(course.getVersion())
                    .build();
            section = sectionRepository.save(section);

            List<com.hango.hango_backend.dto.CourseLessonDTO> lessonDTOs = sDto.getLessons();
            if (lessonDTOs == null) {
                lessonDTOs = new java.util.ArrayList<>();
            }

            for (int lIdx = 0; lIdx < lessonDTOs.size(); lIdx++) {
                com.hango.hango_backend.dto.CourseLessonDTO lDto = lessonDTOs.get(lIdx);
                String type2 = lDto.getItemType();
                if (lDto.getQuestionText() != null && lDto.getQuestionText().contains("youtu")) {
                    type2 = "video";
                }
                com.hango.hango_backend.entity.Lesson lesson = com.hango.hango_backend.entity.Lesson.builder()
                        .section(section)
                        .title(lDto.getTitle())
                        .lessonType(type2 != null ? type2 : "video")
                        .displayOrder(lIdx + 1)
                        .description(lDto.getDescription())
                        .content(lDto.getQuestionText())
                        .pdfName(lDto.getPdfName())
                        .questionImageUrl(lDto.getQuestionImageUrl())
                        .estimatedTime(lDto.getEstimatedTime())
                        .code(lDto.getLessonCode())
                        .mediaDurationSeconds(lDto.getMediaDurationSeconds())
                        .mediaSizeBytes(lDto.getMediaSizeBytes())
                        .estimatedTimeMinutes(lDto.getEstimatedTimeMinutes())
                        .learningObjectives(lDto.getLearningObjectives())
                        .version(course.getVersion())
                        .skill(category)
                        .difficulty(difficulty)
                        .build();

                if (lDto.getQuestionText() != null && lDto.getQuestionText().contains("youtu")) {
                    String transcript = youtubeTranscriptService.fetchTranscript(lDto.getQuestionText());
                    lesson.setVideoTranscript(transcript);
                }

                if (lDto.getExamId() != null) {
                    lesson.setExam(examRepository.findById(lDto.getExamId()).orElse(null));
                }
                lessonRepository.save(lesson);
            }
        }
    }

    @Override
    @Transactional
    public void submitTrainerCourse(Long id, String email) {
        com.hango.hango_backend.entity.Course course = courseRepository.findById(id)
                .orElseThrow(() -> new RuntimeException("Course not found with ID: " + id));

        if (!course.getCreator().getEmail().equalsIgnoreCase(email)) {
            throw new RuntimeException("You are not authorized to submit this course");
        }

        if (!"DRAFT".equalsIgnoreCase(course.getStatus()) && !"REJECTED".equalsIgnoreCase(course.getStatus())) {
            throw new RuntimeException("Only draft or rejected courses can be submitted for review");
        }

        boolean isManager = course.getCreator().getRoles().stream()
                .anyMatch(r -> r.getRoleName().equalsIgnoreCase("COURSE_MANAGER")
                        || r.getRoleName().equalsIgnoreCase("COURSE_MANAGER")
                        || r.getRoleName().equalsIgnoreCase("ADMINISTRATOR")
                        || r.getRoleName().equalsIgnoreCase("ADMIN"));

        if (courseRepository.countDistinctCourseCodesByCreatorId(course.getCreator().getId()) <= 1) {
            course.setPrice(java.math.BigDecimal.ZERO);
            course.setSuggestedPrice(java.math.BigDecimal.ZERO);
        }

        if (isManager) {
            course.setStatus("PUBLISHED");
            course.setPublishedAt(java.time.LocalDateTime.now());
            course.setLatestVersionId(course.getId());
            courseRepository.save(course);

            if (course.getParentId() != null) {
                com.hango.hango_backend.entity.Course originalCourse = courseRepository.findById(course.getParentId())
                        .orElseThrow(() -> new RuntimeException("Original course (V1) not found"));
                if ("PUBLISHED".equalsIgnoreCase(originalCourse.getStatus())) {
                    originalCourse.setLatestVersionId(course.getId());
                    courseRepository.save(originalCourse);
                }
            }
        } else {
            course.setStatus("PENDING_APPROVAL");
            course.setRejectionReason(null);
            courseRepository.save(course);
            notificationService.notifyCourseManagers(NotificationService.TYPE_COURSE_SUBMITTED, "Course Submitted",
                    "Course '" + course.getTitle() + "' has been submitted for review by " + email, course);
        }
    }

    @Override
    @Transactional(readOnly = true)
    public List<com.hango.hango_backend.dto.TrainerExamResponseDTO> getTrainerExams(String email) {
        User user = userRepository.findByEmail(email)
                .orElseThrow(() -> new RuntimeException("User not found with email: " + email));
        Long trainerId = user.getId();

        boolean isManager = user.getRoles().stream()
                .anyMatch(r -> r.getRoleName().equalsIgnoreCase("COURSE_MANAGER")
                        || r.getRoleName().equalsIgnoreCase("COURSE_MANAGER")
                        || r.getRoleName().equalsIgnoreCase("ADMINISTRATOR")
                        || r.getRoleName().equalsIgnoreCase("ADMIN"));

        List<Object[]> exams;
        if (isManager) {
            exams = examRepository.findTrainerExamsForManager(trainerId);
        } else {
            exams = examRepository.findTrainerExamsForTrainer(trainerId);
        }

        // Sort exams by priority and then by createdAt descending
        exams.sort((e1, e2) -> {
            int p1 = getExamStatusPriority((String) e1[5]);
            int p2 = getExamStatusPriority((String) e2[5]);
            if (p1 != p2) {
                return Integer.compare(p1, p2);
            }
            java.time.LocalDateTime d1 = (java.time.LocalDateTime) e1[2];
            java.time.LocalDateTime d2 = (java.time.LocalDateTime) e2[2];
            if (d1 == null && d2 == null)
                return 0;
            if (d1 == null)
                return 1;
            if (d2 == null)
                return -1;
            return d2.compareTo(d1);
        });

        List<Long> examIds = exams.stream().map(e -> (Long) e[0]).collect(Collectors.toList());
        java.util.Map<Long, Integer> questionCounts = new java.util.HashMap<>();
        if (!examIds.isEmpty()) {
            List<Object[]> questionRows = examQuestionRepository.countQuestionsByExamIds(examIds);
            if (questionRows != null) {
                for (Object[] row : questionRows) {
                    questionCounts.put(((Number) row[0]).longValue(), ((Number) row[1]).intValue());
                }
            }
        }

        return exams.stream().map(exam -> {
            Long id = (Long) exam[0];
            String title = (String) exam[1];
            java.time.LocalDateTime createdAt = (java.time.LocalDateTime) exam[2];
            Integer expectedQuestionCount = (Integer) exam[3];
            Integer durationMinutes = (Integer) exam[4];
            String status = (String) exam[5];
            String visibility = (String) exam[6];
            String thumbnailUrl = (String) exam[7];
            String description = (String) exam[8];
            Double passingScore = (Double) exam[9];
            Long creatorId = (Long) exam[10];
            String creatorName = (String) exam[11];

            int questionCount = questionCounts.getOrDefault(id, 0);
            return com.hango.hango_backend.dto.TrainerExamResponseDTO.builder()
                    .id(id)
                    .title(title)
                    .description(description)
                    .createdAt(createdAt)
                    .questionCount(questionCount)
                    .expectedQuestionCount(expectedQuestionCount)
                    .passingScore(passingScore)
                    .durationMinutes(durationMinutes)
                    .status(status != null ? status : "private")
                    .visibility(visibility != null ? visibility : "PRIVATE")
                    .thumbnailUrl(thumbnailUrl)
                    .creatorId(creatorId)
                    .creatorName(creatorName != null ? creatorName : "Unknown")
                    .build();
        }).collect(Collectors.toList());
    }

    private int getExamStatusPriority(String status) {
        if (status == null)
            return 4;
        String s = status.toUpperCase();
        if ("SUBMITTED".equals(s))
            return 1;
        if ("PUBLISHED".equals(s) || "REJECTED".equals(s) || "HIDDEN".equals(s))
            return 2;
        if ("DRAFT".equals(s))
            return 3;
        return 4;
    }

    @Override
    @Transactional
    public Long createTrainerExam(String email, com.hango.hango_backend.dto.TrainerCreateExamRequestDTO request) {
        User user = userRepository.findByEmail(email)
                .orElseThrow(() -> new RuntimeException("User not found with email: " + email));

        com.hango.hango_backend.entity.Exam exam = new com.hango.hango_backend.entity.Exam();
        exam.setTitle(request.getTitle());
        exam.setDescription(request.getDescription());
        exam.setExpectedQuestionCount(request.getExpectedQuestionCount());
        exam.setPassingScore(request.getPassingScore());
        exam.setDurationMinutes(request.getDurationMinutes());
        exam.setThumbnailUrl(com.hango.hango_backend.entity.Exam.resolveThumbnailUrl(request.getThumbnailUrl()));

        exam.setStatus("DRAFT");
        exam.setVisibility("PRIVATE");
        exam.setCreatedBy(user);

        exam = examRepository.save(exam);
        examHistoryService.log(exam, ExamHistoryService.ACTION_CREATED, null, "DRAFT", null, null);
        return exam.getId();
    }

    @Override
    @Transactional
    public void updateTrainerExamBasicInfo(Long examId, String email, com.hango.hango_backend.dto.TrainerUpdateExamInfoRequestDTO request) {
        User user = userRepository.findByEmail(email)
                .orElseThrow(() -> new RuntimeException("User not found with email: " + email));
        boolean isCourseManagerOrAdmin = user.getRoles().stream()
                .anyMatch(role -> role.getRoleName().equals("COURSE_MANAGER") || role.getRoleName().equals("ADMINISTRATOR"));

        com.hango.hango_backend.entity.Exam exam = examRepository.findById(examId)
                .orElseThrow(() -> new RuntimeException("Exam not found"));

        if (!isCourseManagerOrAdmin && !exam.getCreatedBy().getId().equals(user.getId())) {
            throw new RuntimeException("You do not have permission to edit this exam");
        }

        String oldStatus = exam.getStatus();

        exam.setTitle(request.getTitle());
        exam.setDescription(request.getDescription());
        exam.setExpectedQuestionCount(request.getExpectedQuestionCount());
        exam.setPassingScore(request.getPassingScore());
        exam.setDurationMinutes(request.getDurationMinutes());
        exam.setThumbnailUrl(com.hango.hango_backend.entity.Exam.resolveThumbnailUrl(request.getThumbnailUrl()));

        if ("PUBLISHED".equals(exam.getStatus()) && !isCourseManagerOrAdmin) {
            exam.setStatus("SUBMITTED");
        }

        exam = examRepository.save(exam);

        String newStatus = exam.getStatus();
        if (!oldStatus.equals(newStatus)) {
            examHistoryService.log(exam, ExamHistoryService.ACTION_SUBMITTED, oldStatus, newStatus, null, "Exam metadata updated, status downgraded to SUBMITTED");
        } else {
            examHistoryService.log(exam, ExamHistoryService.ACTION_EDITED, oldStatus, newStatus, null, "Exam basic info updated");
        }
    }

    @Override
    @Transactional
    public void saveExamQuestions(Long examId, String email,
            com.hango.hango_backend.dto.TrainerSaveExamQuestionsRequestDTO request) {
        com.hango.hango_backend.entity.Exam exam = examRepository.findById(examId)
                .orElseThrow(() -> new RuntimeException("Exam not found with id: " + examId));

        if (!exam.getCreatedBy().getEmail().equals(email)) {
            throw new RuntimeException("Unauthorized to edit this exam");
        }

        if ("PUBLISHED".equalsIgnoreCase(exam.getStatus())) {
            User user = userRepository.findByEmail(email)
                    .orElseThrow(() -> new RuntimeException("User not found with email: " + email));
            boolean isCourseManagerOrAdmin = user.getRoles().stream()
                    .anyMatch(role -> role.getRoleName().equals("COURSE_MANAGER") || role.getRoleName().equals("ADMINISTRATOR"));
            if (!isCourseManagerOrAdmin) {
                exam.setStatus("SUBMITTED");
                exam = examRepository.save(exam);
            }
        }

        List<com.hango.hango_backend.dto.CreateGroupQuestionRequestDTO> oldBlocks = buildBlocksFromQuestions(examId);

        examQuestionRepository.deleteByIdExamId(examId);

        int order = 1;
        if (request.getBlocks() != null) {
            for (com.hango.hango_backend.dto.CreateGroupQuestionRequestDTO block : request.getBlocks()) {
                Map<String, Object> res = trainerQuestionService.createQuestionBankGroup(email, block);

                if (res != null && res.containsKey("questionIds")) {
                    @SuppressWarnings("unchecked")
                    List<Long> qIds = (List<Long>) res.get("questionIds");
                    if (qIds != null) {
                        for (Long qId : qIds) {
                            com.hango.hango_backend.entity.ExamQuestion eq = new com.hango.hango_backend.entity.ExamQuestion();
                            eq.setId(new com.hango.hango_backend.entity.ExamQuestionId(examId, qId));
                            eq.setQuestionOrder(order++);
                            examQuestionRepository.save(eq);
                        }
                    }
                }
            }
        }

        logExamEdit(exam, oldBlocks, request.getBlocks());
    }

    private void logExamEdit(com.hango.hango_backend.entity.Exam exam,
            List<com.hango.hango_backend.dto.CreateGroupQuestionRequestDTO> oldBlocks,
            List<com.hango.hango_backend.dto.CreateGroupQuestionRequestDTO> newBlocks) {
        String diffJson;
        try {
            diffJson = objectMapper.writeValueAsString(ExamQuestionDiffUtil.diff(oldBlocks, newBlocks));
        } catch (com.fasterxml.jackson.core.JsonProcessingException e) {
            diffJson = null;
        }
        examHistoryService.log(exam, ExamHistoryService.ACTION_EDITED, null, null, null, diffJson);
    }

    @Override
    @Transactional(readOnly = true)
    public com.hango.hango_backend.dto.TrainerSaveExamQuestionsRequestDTO getExamQuestions(Long examId, String email) {
        examRepository.findById(examId)
                .orElseThrow(() -> new RuntimeException("Exam not found"));

        com.hango.hango_backend.dto.TrainerSaveExamQuestionsRequestDTO response = new com.hango.hango_backend.dto.TrainerSaveExamQuestionsRequestDTO();
        response.setBlocks(buildBlocksFromQuestions(examId));
        return response;
    }

    private List<com.hango.hango_backend.dto.CreateGroupQuestionRequestDTO> buildBlocksFromQuestions(Long examId) {
        List<com.hango.hango_backend.entity.Question> questions = questionRepository
                .findByExamIdOrderByQuestionOrder(examId);

        List<com.hango.hango_backend.dto.CreateGroupQuestionRequestDTO> blocks = new ArrayList<>();
        com.hango.hango_backend.dto.CreateGroupQuestionRequestDTO currentBlock = null;
        Long currentGroupId = null;

        for (com.hango.hango_backend.entity.Question q : questions) {
            Long groupId = q.getQuestionGroup() != null ? q.getQuestionGroup().getId() : null;

            if (groupId == null || !groupId.equals(currentGroupId) || currentBlock == null) {
                currentBlock = new com.hango.hango_backend.dto.CreateGroupQuestionRequestDTO();
                currentBlock.setCategoryId((groupId != null && q.getQuestionGroup() != null
                        && q.getQuestionGroup().getGroupTypeParam() != null)
                                ? q.getQuestionGroup().getGroupTypeParam().getId()
                                : null);
                currentBlock.setSkillParamId(q.getSkillParam() != null ? q.getSkillParam().getId() : null);
                currentBlock.setDifficultyId(q.getDifficulty() != null ? q.getDifficulty().getId() : null);
                currentBlock.setSectionId(q.getSection() != null ? q.getSection().getId() : null);
                currentBlock.setSubQuestions(new ArrayList<>());

                if (groupId != null && q.getQuestionGroup() != null) {
                    currentBlock.setPassageText(q.getQuestionGroup().getContextText());
                } else {
                    currentBlock.setPassageText(null);
                }

                blocks.add(currentBlock);
                currentGroupId = groupId;
            }

            com.hango.hango_backend.dto.CreateSubQuestionDTO subQ = new com.hango.hango_backend.dto.CreateSubQuestionDTO();
            subQ.setQuestionText(q.getQuestionText());
            subQ.setExplanation(q.getExplanation());
            subQ.setSkillParamId(q.getSkillParam() != null ? q.getSkillParam().getId() : null);
            subQ.setDifficultyId(q.getDifficulty() != null ? q.getDifficulty().getId() : null);

            List<com.hango.hango_backend.dto.CreateOptionDTO> options = new ArrayList<>();
            if (q.getOptions() != null) {
                for (com.hango.hango_backend.entity.QuestionOption opt : q.getOptions()) {
                    com.hango.hango_backend.dto.CreateOptionDTO oDto = new com.hango.hango_backend.dto.CreateOptionDTO();
                    oDto.setOptionText(opt.getOptionText());
                    oDto.setIsCorrect(opt.getIsCorrect());
                    options.add(oDto);
                }
            }
            subQ.setOptions(options);

            currentBlock.getSubQuestions().add(subQ);
        }

        return blocks;
    }

    @Override
    @Transactional
    public void updateExamStatus(Long examId, String email, String status) {
        User user = userRepository.findByEmail(email)
                .orElseThrow(() -> new RuntimeException("User not found with email: " + email));

        com.hango.hango_backend.entity.Exam exam = examRepository.findById(examId)
                .orElseThrow(() -> new RuntimeException("Exam not found"));

        boolean isManager = user.getRoles().stream()
                .anyMatch(r -> r.getRoleName().equalsIgnoreCase("COURSE_MANAGER")
                        || r.getRoleName().equalsIgnoreCase("COURSE_MANAGER")
                        || r.getRoleName().equalsIgnoreCase("ADMINISTRATOR")
                        || r.getRoleName().equalsIgnoreCase("ADMIN"));

        // verify that the user is the creator of the exam or is a manager
        if (!isManager && !exam.getCreatedBy().getId().equals(user.getId())) {
            throw new RuntimeException("User is not authorized to update this exam");
        }

        // A trainer may only move their own exam between DRAFT/SUBMITTED/HIDDEN-style
        // states; publishing, approving, or rejecting is the Course Manager's call
        // (normally made via the dedicated /course-manager/exams/{id}/publish|reject
        // endpoints, which is why this generic status endpoint stays permissive for
        // managers rather than routing every transition through those two).
        boolean isPublishOrApprove = "PUBLISHED".equalsIgnoreCase(status) || "APPROVED".equalsIgnoreCase(status);
        boolean isReject = "REJECTED".equalsIgnoreCase(status);
        if (!isManager && (isPublishOrApprove || isReject)) {
            throw new org.springframework.security.access.AccessDeniedException(
                    "Only managers can publish, approve, or reject exams");
        }

        String oldStatus = exam.getStatus();
        exam.setStatus(status);
        examRepository.save(exam);
        examHistoryService.log(exam, mapStatusChangeToAction(oldStatus, status), oldStatus, status, null, null);
    }

    private String mapStatusChangeToAction(String oldStatus, String newStatus) {
        String upper = newStatus != null ? newStatus.toUpperCase() : "";
        if ("SUBMITTED".equals(upper)) {
            return ExamHistoryService.ACTION_SUBMITTED;
        }
        if ("HIDDEN".equals(upper)) {
            return ExamHistoryService.ACTION_HIDDEN;
        }
        if ("REJECTED".equals(upper)) {
            return ExamHistoryService.ACTION_REJECTED;
        }
        if ("PUBLISHED".equals(upper) || "APPROVED".equals(upper)) {
            return "HIDDEN".equalsIgnoreCase(oldStatus) ? ExamHistoryService.ACTION_UNHIDDEN
                    : ExamHistoryService.ACTION_PUBLISHED;
        }
        return upper;
    }

    @Override
    @Transactional
    public void updateExamVisibility(Long examId, String email, String visibility) {
        User user = userRepository.findByEmail(email)
                .orElseThrow(() -> new RuntimeException("User not found with email: " + email));

        com.hango.hango_backend.entity.Exam exam = examRepository.findById(examId)
                .orElseThrow(() -> new RuntimeException("Exam not found"));

        // Only the creator can change the visibility of an exam
        if (!exam.getCreatedBy().getId().equals(user.getId())) {
            throw new RuntimeException("User is not authorized to update visibility of this exam");
        }

        exam.setVisibility(visibility);
        examRepository.save(exam);
    }

    @Override
    @Transactional
    public void deleteTrainerExam(Long examId, String email) {
        User user = userRepository.findByEmail(email)
                .orElseThrow(() -> new RuntimeException("User not found with email: " + email));

        com.hango.hango_backend.entity.Exam exam = examRepository.findById(examId)
                .orElseThrow(() -> new RuntimeException("Exam not found"));

        if (!exam.getCreatedBy().getId().equals(user.getId())) {
            throw new RuntimeException("User is not authorized to delete this exam");
        }

        exam.setDeletedAt(java.time.LocalDateTime.now());
        examRepository.save(exam);
    }

    @Override
    @Transactional
    public void deleteTrainerCourse(Long id, String email) {
        User user = userRepository.findByEmail(email)
                .orElseThrow(() -> new RuntimeException("User not found with email: " + email));

        com.hango.hango_backend.entity.Course course = courseRepository.findById(id)
                .orElseThrow(() -> new RuntimeException("Course not found with ID: " + id));

        if (!course.getCreator().getId().equals(user.getId())) {
            throw new RuntimeException("You are not authorized to delete this course");
        }

        String status = course.getStatus() != null ? course.getStatus().toUpperCase() : "";
        if (!"DRAFT".equals(status) && !"REJECTED".equals(status)) {
            throw new RuntimeException("Chỉ có thể xoá khóa học ở trạng thái Nháp (Draft) hoặc Bị từ chối (Rejected).");
        }

        // Hard delete sections which will cascade to lessons, questions, etc.
        java.util.List<com.hango.hango_backend.entity.Section> sections = sectionRepository.findByCourseIdOrderByDisplayOrderAsc(course.getId());
        sectionRepository.deleteAll(sections);
        
        // Hard delete the course itself
        courseRepository.delete(course);
    }

    private String generateUniqueCourseCode() {
        String baseCode = "COURSE-" + java.time.Instant.now().toEpochMilli();
        // Keep trying with incrementing suffix if base timestamp collides
        String candidate = baseCode;
        int suffix = 0;
        while (courseRepository.existsByCodeIgnoreCase(candidate)) {
            candidate = baseCode + "-" + (++suffix);
        }
        return candidate;
    }

    private String incrementVersion(String currentVersion) {
        if (currentVersion == null || currentVersion.isBlank()) {
            return "v1";
        }
        try {
            String numPart = currentVersion.replaceAll("[^0-9]", "");
            int num = Integer.parseInt(numPart);
            return "v" + (num + 1);
        } catch (NumberFormatException e) {
            return "v1";
        }
    }

    @Override
    @org.springframework.transaction.annotation.Transactional
    public void publishTrainerCourse(Long id, String email) {
        // Legacy direct publish (for new courses without enrolled learners)
        com.hango.hango_backend.entity.Course course = courseRepository.findById(id)
                .orElseThrow(() -> new RuntimeException("Course not found with ID: " + id));

        if (!course.getCreator().getEmail().equalsIgnoreCase(email)) {
            throw new RuntimeException("You are not authorized to publish this course");
        }

        com.hango.hango_backend.entity.TrainerProfile profile = trainerProfileRepository
                .findById(course.getCreator().getId()).orElse(null);
        if (profile == null || !"VERIFIED".equalsIgnoreCase(profile.getStatus())) {
            throw new IllegalStateException(
                    "Bạn cần hoàn thiện hồ sơ và được Admin phê duyệt để bắt đầu bán khóa học.");
        }

        course.setStatus("PUBLISHED");
        course.setPublishedAt(java.time.LocalDateTime.now());
        course.setLatestVersionId(course.getId());
        courseRepository.save(course);
    }

    private java.math.BigDecimal calculateCoursePrice(Long creatorId, String courseCode, com.hango.hango_backend.entity.TrainerProfile profile,
            com.hango.hango_backend.entity.SystemParameter difficulty, int lessonCount, int durationMinutes) {
        long price = 0;
        if (profile != null) {
            if ("PROFESSIONAL".equalsIgnoreCase(profile.getTrainerType())) {
                price += 300000;
            } else if ("PEER_TUTOR".equalsIgnoreCase(profile.getTrainerType())) {
                price += 150000;
            }
            if (profile.getScoreReportUrl() != null && !profile.getScoreReportUrl().isBlank()) {
                price += 150000;
            }
        }
        if (difficulty != null) {
            String level = difficulty.getParamKey();
            if ("ADVANCED".equalsIgnoreCase(level)) {
                price += 200000;
            } else if ("INTERMEDIATE".equalsIgnoreCase(level)) {
                price += 100000;
            } else if ("BASIC".equalsIgnoreCase(level)) {
                price += 50000;
            }
        }
        price += (lessonCount * 10000L);
        price += (durationMinutes * 1000L);
        
        if (courseRepository.isEligibleForFirstCoursePromotion(creatorId, courseCode)) {
            return java.math.BigDecimal.ZERO;
        }
        
        return java.math.BigDecimal.valueOf(price);
    }

    @Override
    @org.springframework.transaction.annotation.Transactional
    public void reEvaluateCoursePrice(Long id, String email) {
        com.hango.hango_backend.entity.Course course = courseRepository.findById(id)
                .orElseThrow(() -> new RuntimeException("Course not found with ID: " + id));

        if (!course.getCreator().getEmail().equalsIgnoreCase(email)) {
            throw new RuntimeException("You are not authorized to edit this course");
        }

        com.hango.hango_backend.entity.TrainerProfile profile = trainerProfileRepository
                .findById(course.getCreator().getId()).orElse(null);

        int lessonCount = 0;
        int durationMinutes = 0;
        java.util.List<com.hango.hango_backend.entity.Section> sections = sectionRepository
                .findByCourseIdOrderByDisplayOrderAsc(course.getId());
        for (com.hango.hango_backend.entity.Section sec : sections) {
            java.util.List<com.hango.hango_backend.entity.Lesson> lessons = lessonRepository.findBySectionIdOrderByDisplayOrderAsc(sec.getId());
            lessonCount += lessons.size();
            for (com.hango.hango_backend.entity.Lesson l : lessons) {
                if (l.getEstimatedTimeMinutes() != null) {
                    durationMinutes += l.getEstimatedTimeMinutes();
                } else if (l.getEstimatedTime() != null) {
                    durationMinutes += l.getEstimatedTime();
                }
            }
        }

        course.setEstimatedDuration(durationMinutes);
        java.math.BigDecimal calculatedPrice = calculateCoursePrice(course.getCreator().getId(), course.getCode(), profile, course.getDifficulty(), lessonCount, durationMinutes);
        
        course.setPrice(calculatedPrice);
        course.setSuggestedPrice(calculatedPrice);
        courseRepository.save(course);
    }

}
