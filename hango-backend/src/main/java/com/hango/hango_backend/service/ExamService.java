package com.hango.hango_backend.service;

import com.hango.hango_backend.dto.ExamResponseDTO;
import com.hango.hango_backend.entity.Exam;
import com.hango.hango_backend.repository.ExamAttemptRepository;
import com.hango.hango_backend.repository.ExamQuestionRepository;
import com.hango.hango_backend.repository.ExamRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;

import java.util.List;
import java.util.stream.Collectors;

@Service
@RequiredArgsConstructor
public class ExamService {

    private final ExamRepository examRepository;
    private final ExamQuestionRepository examQuestionRepository;
    private final ExamAttemptRepository examAttemptRepository;

    public List<ExamResponseDTO> getAllExams(String status) {
        List<Exam> exams;
        if (status != null && !status.isEmpty() && !status.equalsIgnoreCase("All")) {
            exams = examRepository.findByDeletedAtIsNullAndStatus(status);
        } else {
            exams = examRepository.findAll().stream()
                    .filter(e -> e.getDeletedAt() == null)
                    .collect(Collectors.toList());
        }

        return exams.stream().map(this::mapToDTO).collect(Collectors.toList());
    }

    private ExamResponseDTO mapToDTO(Exam exam) {
        int questionCount = examQuestionRepository.countByIdExamId(exam.getId());
        int attemptCount = examAttemptRepository.countByExamId(exam.getId());

        // Mock rating between 4.5 and 5.0 for MVP
        double mockRating = 4.5 + (Math.random() * 0.5);

        String formattedLearners;
        if (attemptCount >= 1000) {
            formattedLearners = (attemptCount / 1000) + "k Learner";
        } else {
            formattedLearners = attemptCount + " Learner";
        }

        String creatorName = exam.getCreatedBy() != null ? exam.getCreatedBy().getFullName() : "Unknown";

        return ExamResponseDTO.builder()
                .id(exam.getId())
                .title(exam.getTitle())
                .description(exam.getDescription())
                .status(exam.getStatus())
                .creatorName(creatorName)
                .questionCount(questionCount)
                .durationMinutes(exam.getDurationMinutes())
                .rating(Math.round(mockRating * 10.0) / 10.0)
                .learnerCountFormatted(formattedLearners)
                .build();
    }
}
