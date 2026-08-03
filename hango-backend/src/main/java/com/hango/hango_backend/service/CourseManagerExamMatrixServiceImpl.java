package com.hango.hango_backend.service;

import com.hango.hango_backend.dto.ExamMatrixCreateRequestDTO;
import com.hango.hango_backend.dto.ExamMatrixDTO;
import com.hango.hango_backend.dto.ExamMatrixDetailDTO;
import com.hango.hango_backend.entity.Exam;
import com.hango.hango_backend.entity.ExamMatrix;
import com.hango.hango_backend.entity.ExamMatrixDetail;
import com.hango.hango_backend.entity.ExamQuestion;
import com.hango.hango_backend.entity.ExamQuestionId;
import com.hango.hango_backend.entity.Question;
import com.hango.hango_backend.entity.QuestionCategory;
import com.hango.hango_backend.entity.SystemParameter;
import com.hango.hango_backend.entity.User;
import com.hango.hango_backend.repository.ExamMatrixDetailRepository;
import com.hango.hango_backend.repository.ExamMatrixRepository;
import com.hango.hango_backend.repository.ExamQuestionRepository;
import com.hango.hango_backend.repository.ExamRepository;
import com.hango.hango_backend.repository.QuestionCategoryRepository;
import com.hango.hango_backend.repository.QuestionRepository;
import com.hango.hango_backend.repository.SystemParameterRepository;
import com.hango.hango_backend.repository.UserRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDateTime;
import java.util.List;
import java.util.stream.Collectors;

@Service
@RequiredArgsConstructor
public class CourseManagerExamMatrixServiceImpl implements CourseManagerExamMatrixService {

    private final ExamMatrixRepository examMatrixRepository;
    private final ExamMatrixDetailRepository examMatrixDetailRepository;
    private final UserRepository userRepository;
    private final SystemParameterRepository systemParameterRepository;
    private final QuestionRepository questionRepository;
    private final ExamRepository examRepository;
    private final ExamQuestionRepository examQuestionRepository;
    private final QuestionCategoryRepository questionCategoryRepository;

    @Override
    @Transactional(readOnly = true)
    public List<ExamMatrixDTO> getAllExamMatrices() {
        return examMatrixRepository.findAllByIsPublicTrueOrderByCreatedAtDesc().stream().map(matrix -> {
            List<ExamMatrixDetailDTO> details = examMatrixDetailRepository.findByMatrixId(matrix.getId()).stream()
                    .map(detail -> ExamMatrixDetailDTO.builder()
                            .id(detail.getId())
                            .skillParamId(detail.getSkillParam() != null ? detail.getSkillParam().getId() : null)
                            .skillParamName(
                                    detail.getSkillParam() != null ? detail.getSkillParam().getParamValue() : "N/A")
                            .difficultyParamId(
                                    detail.getDifficultyParam() != null ? detail.getDifficultyParam().getId() : null)
                            .difficultyParamName(
                                    detail.getDifficultyParam() != null ? detail.getDifficultyParam().getParamValue()
                                            : "N/A")
                            .groupTypeId(detail.getGroupTypeParam() != null ? detail.getGroupTypeParam().getId() : null)
                            .groupTypeName(
                                    detail.getGroupTypeParam() != null ? detail.getGroupTypeParam().getParamValue() : "N/A")
                            .quantity(detail.getQuantity())
                            .build())
                    .collect(Collectors.toList());

            return ExamMatrixDTO.builder()
                    .id(matrix.getId())
                    .title(matrix.getTitle())
                    .description(matrix.getDescription())
                    .createdBy(matrix.getCreatedBy() != null ? matrix.getCreatedBy().getId() : null)
                    .createdAt(matrix.getCreatedAt())
                    .isPublic(matrix.getIsPublic())
                    .details(details)
                    .build();
        }).collect(Collectors.toList());
    }

    @Override
    @Transactional(readOnly = true)
    public List<ExamMatrixDTO> getAllMatricesForManager() {
        return examMatrixRepository.findAllByOrderByCreatedAtDesc().stream().map(matrix -> {
            List<ExamMatrixDetailDTO> details = examMatrixDetailRepository.findByMatrixId(matrix.getId()).stream()
                    .map(detail -> ExamMatrixDetailDTO.builder()
                            .id(detail.getId())
                            .skillParamId(detail.getSkillParam() != null ? detail.getSkillParam().getId() : null)
                            .skillParamName(
                                    detail.getSkillParam() != null ? detail.getSkillParam().getParamValue() : "N/A")
                            .difficultyParamId(
                                    detail.getDifficultyParam() != null ? detail.getDifficultyParam().getId() : null)
                            .difficultyParamName(
                                    detail.getDifficultyParam() != null ? detail.getDifficultyParam().getParamValue()
                                            : "N/A")
                            .groupTypeId(detail.getGroupTypeParam() != null ? detail.getGroupTypeParam().getId() : null)
                            .groupTypeName(
                                    detail.getGroupTypeParam() != null ? detail.getGroupTypeParam().getParamValue() : "N/A")
                            .quantity(detail.getQuantity())
                            .build())
                    .collect(Collectors.toList());

            return ExamMatrixDTO.builder()
                    .id(matrix.getId())
                    .title(matrix.getTitle())
                    .description(matrix.getDescription())
                    .createdBy(matrix.getCreatedBy() != null ? matrix.getCreatedBy().getId() : null)
                    .createdAt(matrix.getCreatedAt())
                    .isPublic(matrix.getIsPublic())
                    .details(details)
                    .build();
        }).collect(Collectors.toList());
    }

    @Override
    @Transactional
    public void createExamMatrix(String email, ExamMatrixCreateRequestDTO request) {
        User user = userRepository.findByEmail(email)
                .orElseThrow(() -> new RuntimeException("User not found: " + email));

        ExamMatrix matrix = new ExamMatrix();
        matrix.setTitle(request.getTitle());
        matrix.setDescription(request.getDescription());
        matrix.setCreatedBy(user);
        matrix.setIsPublic(true);
        final ExamMatrix savedMatrix = examMatrixRepository.save(matrix);

        if (request.getDetails() != null) {
            for (ExamMatrixCreateRequestDTO.DetailRequest detailReq : request.getDetails()) {
                SystemParameter skill = systemParameterRepository.findById(detailReq.getSkillParamId())
                        .orElseThrow(() -> new RuntimeException("Skill not found: " + detailReq.getSkillParamId()));
                SystemParameter diff = systemParameterRepository.findById(detailReq.getDifficultyParamId())
                        .orElseThrow(() -> new RuntimeException(
                                "Difficulty not found: " + detailReq.getDifficultyParamId()));

                ExamMatrixDetail detail = new ExamMatrixDetail();
                detail.setMatrix(savedMatrix);
                detail.setSkillParam(skill);
                detail.setDifficultyParam(diff);
                if (detailReq.getGroupTypeId() != null) {
                    SystemParameter groupType = systemParameterRepository.findById(detailReq.getGroupTypeId()).orElse(null);
                    detail.setGroupTypeParam(groupType);
                }
                if (detailReq.getCategoryId() != null) {
                    QuestionCategory category = questionCategoryRepository.findById(detailReq.getCategoryId()).orElse(null);
                    detail.setCategory(category);
                }
                detail.setQuantity(detailReq.getQuantity());
                examMatrixDetailRepository.save(detail);
            }
        }
    }

    @Override
    @Transactional
    public Long generateExamFromMatrix(Long matrixId, String examTitle, String description, Integer expectedQuestionCount, Double passingScore, Integer durationMinutes, String email) {
        User user = userRepository.findByEmail(email)
                .orElseThrow(() -> new RuntimeException("User not found: " + email));

        ExamMatrix matrix = examMatrixRepository.findById(matrixId)
                .orElseThrow(() -> new RuntimeException("Matrix not found: " + matrixId));

        List<ExamMatrixDetail> details = examMatrixDetailRepository.findByMatrixId(matrixId);

        // Calculate expected question count from matrix
        int totalQuestions = details.stream().mapToInt(ExamMatrixDetail::getQuantity).sum();
        if (expectedQuestionCount != null && expectedQuestionCount > 0) {
            totalQuestions = expectedQuestionCount; // use provided count if valid, although matrix defines minimums
        }

        // Create new DRAFT exam
        Exam exam = new Exam();
        exam.setTitle(examTitle != null && !examTitle.isBlank() ? examTitle : matrix.getTitle() + " - Generated");
        exam.setDescription(description != null ? description : "Generated from matrix: " + matrix.getTitle());
        exam.setExpectedQuestionCount(totalQuestions);
        exam.setPassingScore(passingScore != null ? passingScore : 0.0);
        exam.setDurationMinutes(durationMinutes != null ? durationMinutes : 0);
        exam.setStatus("DRAFT");
        exam.setVisibility("PRIVATE");
        exam.setCreatedBy(user);
        exam.setCreatedAt(LocalDateTime.now());
        Exam savedExam = examRepository.save(exam);

        int currentOrder = 1;

        for (ExamMatrixDetail detail : details) {
            int requiredQty = detail.getQuantity();
            if (requiredQty <= 0)
                continue;

            List<Question> randomQuestions = questionRepository.findRandomQuestionsByCriteria(
                    detail.getSkillParam().getId(),
                    detail.getDifficultyParam().getId(),
                    detail.getGroupTypeParam() != null ? detail.getGroupTypeParam().getId() : null,
                    user.getId(),
                    requiredQty);

            if (randomQuestions.size() < requiredQty) {
                throw new RuntimeException(String.format(
                        "Not enough questions in bank for criteria: Skill='%s', Difficulty='%s', GroupType='%s'. Required: %d, Found: %d",
                        detail.getSkillParam().getParamValue(),
                        detail.getDifficultyParam().getParamValue(),
                        detail.getGroupTypeParam() != null ? detail.getGroupTypeParam().getParamValue() : "None",
                        requiredQty,
                        randomQuestions.size()));
            }

            for (Question q : randomQuestions) {
                ExamQuestion eq = new ExamQuestion();
                ExamQuestionId id = new ExamQuestionId();
                id.setExamId(savedExam.getId());
                id.setQuestionId(q.getId());
                eq.setId(id);
                eq.setQuestionOrder(currentOrder++);
                examQuestionRepository.save(eq);
            }
        }

        return savedExam.getId();
    }

    @Override
    @Transactional
    public void toggleMatrixStatus(Long id) {
        ExamMatrix matrix = examMatrixRepository.findById(id)
                .orElseThrow(() -> new RuntimeException("Matrix not found: " + id));
        matrix.setIsPublic(!matrix.getIsPublic());
        examMatrixRepository.save(matrix);
    }

    @Override
    @Transactional
    public void updateExamMatrix(Long id, ExamMatrixCreateRequestDTO request) {
        ExamMatrix matrix = examMatrixRepository.findById(id)
                .orElseThrow(() -> new RuntimeException("Matrix not found: " + id));

        matrix.setTitle(request.getTitle());
        matrix.setDescription(request.getDescription());
        examMatrixRepository.save(matrix);

        // Delete old details
        List<ExamMatrixDetail> oldDetails = examMatrixDetailRepository.findByMatrixId(id);
        examMatrixDetailRepository.deleteAll(oldDetails);

        // Add new details
        if (request.getDetails() != null) {
            for (ExamMatrixCreateRequestDTO.DetailRequest detailReq : request.getDetails()) {
                SystemParameter skill = systemParameterRepository.findById(detailReq.getSkillParamId())
                        .orElseThrow(() -> new RuntimeException("Skill not found: " + detailReq.getSkillParamId()));
                SystemParameter diff = systemParameterRepository.findById(detailReq.getDifficultyParamId())
                        .orElseThrow(() -> new RuntimeException(
                                "Difficulty not found: " + detailReq.getDifficultyParamId()));

                ExamMatrixDetail detail = new ExamMatrixDetail();
                detail.setMatrix(matrix);
                detail.setSkillParam(skill);
                detail.setDifficultyParam(diff);
                if (detailReq.getGroupTypeId() != null) {
                    SystemParameter groupType = systemParameterRepository.findById(detailReq.getGroupTypeId()).orElse(null);
                    detail.setGroupTypeParam(groupType);
                }
                if (detailReq.getCategoryId() != null) {
                    QuestionCategory category = questionCategoryRepository.findById(detailReq.getCategoryId()).orElse(null);
                    detail.setCategory(category);
                }
                detail.setQuantity(detailReq.getQuantity());
                examMatrixDetailRepository.save(detail);
            }
        }
    }
}
