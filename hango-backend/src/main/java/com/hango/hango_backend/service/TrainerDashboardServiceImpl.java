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

import java.util.Map;

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
            section.setDescription(sDto.getDescription());
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
                lesson.setDescription(lDto.getDescription());
                lesson.setContent(lDto.getQuestionText());
                lesson.setPdfName(lDto.getPdfName());
                lesson.setQuestionImageUrl(lDto.getQuestionImageUrl());
                
                // Set mandatory fields using Course category and difficulty parameters
                lesson.setSkill(savedCourse.getCategory());
                lesson.setDifficulty(savedCourse.getDifficulty());

                lessonRepository.save(lesson);
            }
        }
    }

    @Override
    @Transactional(readOnly = true)
    public List<com.hango.hango_backend.dto.TrainerExamResponseDTO> getTrainerExams(String email) {
        User user = userRepository.findByEmail(email)
                .orElseThrow(() -> new RuntimeException("User not found with email: " + email));
        Long trainerId = user.getId();
        
        boolean isManager = user.getRoles().stream()
                .anyMatch(r -> r.getRoleName().equalsIgnoreCase("COURSE_MANAGER") || r.getRoleName().equalsIgnoreCase("TRAINER_LEAD") || r.getRoleName().equalsIgnoreCase("ADMINISTRATOR") || r.getRoleName().equalsIgnoreCase("ADMIN"));
        
        List<com.hango.hango_backend.entity.Exam> exams;
        if (isManager) {
            exams = examRepository.findByDeletedAtIsNullOrderByCreatedAtDesc();
            // Filter out DRAFT exams that belong to other users
            exams = exams.stream()
                    .filter(exam -> {
                        boolean isDraft = "DRAFT".equalsIgnoreCase(exam.getStatus());
                        boolean isOwn = exam.getCreatedBy() != null && exam.getCreatedBy().getId().equals(trainerId);
                        return !isDraft || isOwn;
                    })
                    .collect(Collectors.toList());
        } else {
            exams = examRepository.findByCreatedByIdAndDeletedAtIsNullOrderByCreatedAtDesc(trainerId);
        }

        // Sort exams by priority and then by createdAt descending
        exams.sort((e1, e2) -> {
            int p1 = getExamStatusPriority(e1.getStatus());
            int p2 = getExamStatusPriority(e2.getStatus());
            if (p1 != p2) {
                return Integer.compare(p1, p2);
            }
            if (e1.getCreatedAt() == null && e2.getCreatedAt() == null) return 0;
            if (e1.getCreatedAt() == null) return 1;
            if (e2.getCreatedAt() == null) return -1;
            return e2.getCreatedAt().compareTo(e1.getCreatedAt());
        });

        return exams.stream().map(exam -> {
            int questionCount = examQuestionRepository.countByIdExamId(exam.getId());
            return com.hango.hango_backend.dto.TrainerExamResponseDTO.builder()
                    .id(exam.getId())
                    .title(exam.getTitle())
                    .createdAt(exam.getCreatedAt())
                    .questionCount(questionCount)
                    .expectedQuestionCount(exam.getExpectedQuestionCount())
                    .durationMinutes(exam.getDurationMinutes())
                    .status(exam.getStatus() != null ? exam.getStatus() : "private")
                    .visibility(exam.getVisibility() != null ? exam.getVisibility() : "PRIVATE")
                    .thumbnailUrl(exam.getThumbnailUrl())
                    .creatorId(exam.getCreatedBy() != null ? exam.getCreatedBy().getId() : null)
                    .build();
        }).collect(Collectors.toList());
    }

    private int getExamStatusPriority(String status) {
        if (status == null) return 4;
        String s = status.toUpperCase();
        if ("SUBMITTED".equals(s)) return 1;
        if ("PUBLISHED".equals(s) || "REJECTED".equals(s) || "HIDDEN".equals(s)) return 2;
        if ("DRAFT".equals(s)) return 3;
        return 4;
    }

    @Override
    @Transactional
    public void createTrainerExam(String email, com.hango.hango_backend.dto.TrainerCreateExamRequestDTO request) {
        User user = userRepository.findByEmail(email)
                .orElseThrow(() -> new RuntimeException("User not found with email: " + email));
        
        com.hango.hango_backend.entity.Exam exam = new com.hango.hango_backend.entity.Exam();
        exam.setTitle(request.getTitle());
        exam.setDescription(request.getDescription());
        exam.setExpectedQuestionCount(request.getExpectedQuestionCount());
        exam.setPassingScore(request.getPassingScore());
        exam.setDurationMinutes(request.getDurationMinutes());
        exam.setThumbnailUrl(request.getThumbnailUrl());
        
        exam.setStatus("DRAFT");
        exam.setVisibility("PRIVATE");
        exam.setCreatedBy(user);
        
        examRepository.save(exam);
    }

    @Override
    @Transactional
    public void saveExamQuestions(Long examId, String email, com.hango.hango_backend.dto.TrainerSaveExamQuestionsRequestDTO request) {
        com.hango.hango_backend.entity.Exam exam = examRepository.findById(examId)
                .orElseThrow(() -> new RuntimeException("Exam not found with id: " + examId));
                
        if (!exam.getCreatedBy().getEmail().equals(email)) {
            throw new RuntimeException("Unauthorized to edit this exam");
        }
        
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
    }

    @Override
    @Transactional(readOnly = true)
    public com.hango.hango_backend.dto.TrainerSaveExamQuestionsRequestDTO getExamQuestions(Long examId, String email) {
        com.hango.hango_backend.entity.Exam exam = examRepository.findById(examId)
                .orElseThrow(() -> new RuntimeException("Exam not found"));
                
        List<com.hango.hango_backend.entity.Question> questions = questionRepository.findByExamIdOrderByQuestionOrder(examId);

        List<com.hango.hango_backend.dto.CreateGroupQuestionRequestDTO> blocks = new ArrayList<>();
        com.hango.hango_backend.dto.CreateGroupQuestionRequestDTO currentBlock = null;
        Long currentGroupId = null;

        for (com.hango.hango_backend.entity.Question q : questions) {
            Long groupId = q.getQuestionGroup() != null ? q.getQuestionGroup().getId() : null;
            
            if (groupId == null || !groupId.equals(currentGroupId) || currentBlock == null) {
                currentBlock = new com.hango.hango_backend.dto.CreateGroupQuestionRequestDTO();
                currentBlock.setCategoryId(q.getCategory() != null ? q.getCategory().getId() : null);
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

        com.hango.hango_backend.dto.TrainerSaveExamQuestionsRequestDTO response = new com.hango.hango_backend.dto.TrainerSaveExamQuestionsRequestDTO();
        response.setBlocks(blocks);
        return response;
    }

    @Override
    @Transactional
    public void updateExamStatus(Long examId, String email, String status) {
        User user = userRepository.findByEmail(email)
                .orElseThrow(() -> new RuntimeException("User not found with email: " + email));
        
        com.hango.hango_backend.entity.Exam exam = examRepository.findById(examId)
                .orElseThrow(() -> new RuntimeException("Exam not found"));
                
        boolean isManager = user.getRoles().stream()
                .anyMatch(r -> r.getRoleName().equalsIgnoreCase("COURSE_MANAGER") || r.getRoleName().equalsIgnoreCase("TRAINER_LEAD") || r.getRoleName().equalsIgnoreCase("ADMINISTRATOR") || r.getRoleName().equalsIgnoreCase("ADMIN"));

        // verify that the user is the creator of the exam or is a manager
        if (!isManager && !exam.getCreatedBy().getId().equals(user.getId())) {
            throw new RuntimeException("User is not authorized to update this exam");
        }
        
        exam.setStatus(status);
        examRepository.save(exam);
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
    @org.springframework.transaction.annotation.Transactional
    public void publishTrainerCourse(Long id, String email) {
        com.hango.hango_backend.entity.Course course = courseRepository.findById(id)
                .orElseThrow(() -> new RuntimeException("Course not found with ID: " + id));

        if (!course.getCreator().getEmail().equalsIgnoreCase(email)) {
            throw new RuntimeException("You are not authorized to publish this course");
        }

        com.hango.hango_backend.entity.TrainerProfile profile = trainerProfileRepository.findById(course.getCreator().getId()).orElse(null);
        if (profile == null || !"VERIFIED".equalsIgnoreCase(profile.getStatus())) {
            throw new IllegalStateException("Bạn cần hoàn thiện hồ sơ và được Admin phê duyệt để bắt đầu bán khóa học.");
        }

        course.setStatus("PUBLISHED");
        courseRepository.save(course);
    }
}
