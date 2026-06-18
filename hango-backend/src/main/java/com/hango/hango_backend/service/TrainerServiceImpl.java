package com.hango.hango_backend.service;

import com.hango.hango_backend.dto.TrainerCourseDTO;
import com.hango.hango_backend.dto.TrainerDashboardDTO;
import com.hango.hango_backend.entity.User;
import com.hango.hango_backend.repository.*;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.security.core.userdetails.UsernameNotFoundException;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;
import java.util.stream.Collectors;

@Service
@RequiredArgsConstructor
public class TrainerServiceImpl implements TrainerService {

    private final UserRepository userRepository;
    private final CourseRepository courseRepository;
    private final ExamRepository examRepository;
    private final EnrollmentRepository enrollmentRepository;

    @Override
    @Transactional(readOnly = true)
    public TrainerDashboardDTO getTrainerDashboard(String trainerEmail, Pageable pageable) {
        User trainer = userRepository.findByEmail(trainerEmail)
                .orElseThrow(() -> new UsernameNotFoundException("Trainer not found with email: " + trainerEmail));

        Long trainerId = trainer.getId();

        long coursesCount = courseRepository.countByCreatorIdAndDeletedAtIsNull(trainerId);
        long examsCount = examRepository.countByCreatedByIdAndDeletedAtIsNull(trainerId);
        long learnersCount = enrollmentRepository.countDistinctLearnersByTrainerId(trainerId);

        Page<TrainerCourseProjection> coursesPage = courseRepository.findTrainerCoursesPaginated(trainerId, pageable);

        List<TrainerCourseDTO> courses = coursesPage.getContent().stream()
                .map(proj -> TrainerCourseDTO.builder()
                        .id(proj.getId())
                        .title(proj.getTitle())
                        .thumbnailUrl(proj.getThumbnailUrl())
                        .status(proj.getStatus())
                        .learnersCount(proj.getLearnersCount() != null ? proj.getLearnersCount() : 0L)
                        .lessonsCount(proj.getLessonsCount() != null ? proj.getLessonsCount() : 0L)
                        .build())
                .collect(Collectors.toList());

        return TrainerDashboardDTO.builder()
                .coursesCount(coursesCount)
                .learnersCount(learnersCount)
                .examsCount(examsCount)
                .courses(courses)
                .totalPages(coursesPage.getTotalPages())
                .totalElements(coursesPage.getTotalElements())
                .currentPage(coursesPage.getNumber())
                .pageSize(coursesPage.getSize())
                .build();
    }
}
