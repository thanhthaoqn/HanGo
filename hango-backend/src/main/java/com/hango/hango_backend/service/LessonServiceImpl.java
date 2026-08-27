package com.hango.hango_backend.service;

import com.hango.hango_backend.dto.CommentDTO;
import com.hango.hango_backend.dto.LessonDetailDTO;
import com.hango.hango_backend.dto.QuizQuestionDTO;
import com.hango.hango_backend.dto.LessonQuizAttemptDTO;
import com.hango.hango_backend.dto.LessonQuizAttemptRequestDTO;
import com.hango.hango_backend.entity.Lesson;
import com.hango.hango_backend.entity.LessonQuizAttempt;
import com.hango.hango_backend.entity.LessonProgress;
import com.hango.hango_backend.entity.Enrollment;
import com.hango.hango_backend.entity.User;
import com.hango.hango_backend.exception.ApiException;
import com.hango.hango_backend.repository.LessonRepository;
import com.hango.hango_backend.repository.LessonQuizAttemptRepository;
import com.hango.hango_backend.repository.UserRepository;
import com.hango.hango_backend.repository.LessonProgressRepository;
import com.hango.hango_backend.repository.EnrollmentRepository;
import com.fasterxml.jackson.databind.ObjectMapper;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDateTime;
import java.math.BigDecimal;
import java.math.RoundingMode;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.stream.Collectors;

@Service
@RequiredArgsConstructor
public class LessonServiceImpl implements LessonService {

    private final LessonRepository lessonRepository;
    private final CommentService commentService;
    private final JdbcTemplate jdbcTemplate;
    private final LessonQuizAttemptRepository quizAttemptRepository;
    private final UserRepository userRepository;
    private final LessonProgressRepository lessonProgressRepository;
    private final EnrollmentRepository enrollmentRepository;
    private final CertificateService certificateService;
    private final ObjectMapper objectMapper = new ObjectMapper();

    @Override
    public LessonDetailDTO getLessonDetail(Long lessonId, Long userId) {
        Lesson lesson = lessonRepository.findById(lessonId)
                .orElseThrow(() -> new ApiException("Lesson not found", HttpStatus.NOT_FOUND));

        List<CommentDTO> comments = commentService.getCommentsByLesson(lessonId, userId);

        // Chi tiet lo bao mat da fix: TRUOC KHI hoc vien tung nop bai quiz nay
        // it nhat 1 lan, TUYET DOI KHONG duoc tra ve dap an dung (correctIndex)
        // hay giai thich (explanation) trong response cua API nay - neu khong,
        // ai do chi can mo tab Network cua trinh duyet la thay het dap an dung
        // ma khong can lam bai. Sau khi da nop >=1 lan (hasPriorAttempt), moi
        // cho phep lo dap an dung, phuc vu man hinh "xem lai bai da lam".
        boolean hasPriorAttempt = userId != null
                && quizAttemptRepository.countByLessonIdAndStudentId(lessonId, userId) > 0;

        List<QuizQuestionDTO> questions = jdbcTemplate.query(
                "SELECT q.id AS question_id, q.question_text, q.explanation, qg.context_text AS passage " +
                        "FROM lesson_quizzes lq " +
                        "JOIN questions q ON lq.question_id = q.id " +
                        "LEFT JOIN question_groups qg ON q.group_id = qg.id " +
                        "WHERE lq.lesson_id = ? " +
                        "ORDER BY lq.display_order ASC",
                (rs, rowNum) -> {
                    Long qId = rs.getLong("question_id");
                    String questionText = rs.getString("question_text");
                    String explanation = hasPriorAttempt ? rs.getString("explanation") : null;
                    String passage = rs.getString("passage");

                    return QuizQuestionDTO.builder()
                            .id(qId)
                            .passage(passage)
                            .questionText(questionText)
                            .explanation(explanation)
                            .options(new ArrayList<>())
                            .correctIndex(null)
                            .build();
                },
                lessonId);
        if (questions == null) {
            questions = new ArrayList<>();
        }

        List<Long> questionIds = questions.stream()
                .map(QuizQuestionDTO::getId)
                .filter(java.util.Objects::nonNull)
                .collect(Collectors.toList());
        if (!questionIds.isEmpty()) {
            String placeholders = questionIds.stream().map(id -> "?").collect(Collectors.joining(", "));
            List<Map<String, Object>> optionsRows = jdbcTemplate.queryForList(
                    "SELECT question_id, option_text, is_correct FROM question_options " +
                            "WHERE question_id IN (" + placeholders + ") ORDER BY question_id ASC, id ASC",
                    questionIds.toArray());

            if (optionsRows != null) {
                Map<Long, List<String>> optionsByQuestionId = new HashMap<>();
                Map<Long, Integer> correctIndexByQuestionId = new HashMap<>();
                for (Map<String, Object> row : optionsRows) {
                    Long questionId = ((Number) row.get("question_id")).longValue();
                    List<String> options = optionsByQuestionId.computeIfAbsent(questionId, k -> new ArrayList<>());
                    options.add((String) row.get("option_text"));

                    Object isCorrectObj = row.get("is_correct");
                    boolean isCorrect = false;
                    if (isCorrectObj instanceof Boolean) {
                        isCorrect = (Boolean) isCorrectObj;
                    } else if (isCorrectObj instanceof Number) {
                        isCorrect = ((Number) isCorrectObj).intValue() == 1;
                    }
                    if (isCorrect) {
                        correctIndexByQuestionId.put(questionId, options.size() - 1);
                    }
                }

                for (QuizQuestionDTO question : questions) {
                    List<String> options = optionsByQuestionId.get(question.getId());
                    if (options != null) {
                        question.setOptions(options);
                        if (hasPriorAttempt) {
                            question.setCorrectIndex(correctIndexByQuestionId.getOrDefault(question.getId(), 0));
                        }
                    }
                }
            }
        }

        boolean isCompleted = false;
        if (userId != null) {
            isCompleted = lessonProgressRepository.existsByUserIdAndLessonIdAndIsCompletedTrue(userId, lessonId);
        }

        int qCount = questions != null ? questions.size() : 0;
        // FINAL_QUIZ tinh thoi gian nhu quiz (10 phut + 2 phut moi cau)
        boolean isQuizType = "quiz".equalsIgnoreCase(lesson.getLessonType())
                || Lesson.DISPLAY_TYPE_FINAL_QUIZ.equalsIgnoreCase(lesson.getLessonType());
        int estTime = lesson.getEstimatedTime() != null ? lesson.getEstimatedTime()
                : (isQuizType ? (10 + qCount * 2) : 15);

        return LessonDetailDTO.builder()
                .id(lesson.getId())
                .title(lesson.getTitle())
                .content(lesson.getContent())
                .sectionId(lesson.getSection() != null ? lesson.getSection().getId() : null)
                .courseId(lesson.getSection() != null && lesson.getSection().getCourse() != null
                        ? lesson.getSection().getCourse().getId()
                        : null)
                .comments(comments)
                .questions(questions)
                .isCompleted(isCompleted)
                .estimatedTime(estTime)
                .lessonCode(lesson.getCode())
                .mediaDurationSeconds(lesson.getMediaDurationSeconds())
                .mediaSizeBytes(lesson.getMediaSizeBytes())
                .estimatedTimeMinutes(lesson.getEstimatedTimeMinutes())
                .learningObjectives(lesson.getLearningObjectives())
                .mediaFileUrl(lesson.getPdfName())
                .mediaType(lesson.getPdfName() != null && !lesson.getPdfName().isEmpty() ? "pdf" : null)
                .itemType(Lesson.displayItemType(lesson.getLessonType()))
                .videoTranscript(lesson.getVideoTranscript())
                .build();
    }

    @Override
    public List<LessonQuizAttemptDTO> getQuizAttempts(Long lessonId, Long userId) {
        List<LessonQuizAttempt> attempts = quizAttemptRepository
                .findByLessonIdAndStudentIdOrderByAttemptNumberAsc(lessonId, userId);
        return attempts.stream().map(a -> {
            Map<String, Integer> answers = null;
            try {
                if (a.getAnswersJson() != null) {
                    answers = objectMapper.readValue(a.getAnswersJson(), Map.class);
                }
            } catch (Exception e) {
                answers = new java.util.HashMap<>();
            }
            return LessonQuizAttemptDTO.builder()
                    .attemptNumber(a.getAttemptNumber())
                    .state(a.getState())
                    .grade(String.format("%.1f / 10.0", a.getScore()))
                    .submittedTime(a.getSubmittedAt().toString().replace("T", " ").substring(0, 16))
                    .answers(answers)
                    .build();
        }).collect(Collectors.toList());
    }

    // Luu 1 lan lam quiz cua hoc vien. Diem duoc CHAM LAI o Backend (xem
    // computeServerSideScore) dua tren dap an dung luu trong DB, KHONG con tin
    // tuong truc tiep request.getScore() gui tu Frontend nua - tranh hoc vien
    // sua request de tu cho minh diem tuyet doi. Neu vi ly do nao do khong xac
    // dinh duoc dap an dung (vd bai hoc khong co cau hoi quiz nao trong DB),
    // se fallback ve diem Frontend gui len de khong lam gian doan tinh nang.
    @Override
    @Transactional
    public LessonQuizAttemptDTO saveQuizAttempt(Long lessonId, Long userId, LessonQuizAttemptRequestDTO request) {
        Lesson lesson = lessonRepository.findById(lessonId)
                .orElseThrow(() -> new ApiException("Lesson not found", HttpStatus.NOT_FOUND));
        User student = userRepository.findById(userId)
                .orElseThrow(() -> new ApiException("User not found", HttpStatus.NOT_FOUND));

        int nextAttemptNumber = quizAttemptRepository.countByLessonIdAndStudentId(lessonId, userId) + 1;

        String answersJson = null;
        try {
            if (request.getAnswers() != null) {
                answersJson = objectMapper.writeValueAsString(request.getAnswers());
            }
        } catch (Exception e) {
            answersJson = "{}";
        }

        double finalScore = computeServerSideScore(lessonId, request);

        LessonQuizAttempt attempt = LessonQuizAttempt.builder()
                .lesson(lesson)
                .student(student)
                .score(finalScore)
                .attemptNumber(nextAttemptNumber)
                .state(request.getState() != null ? request.getState() : "Finished")
                .answersJson(answersJson)
                .submittedAt(LocalDateTime.now())
                .build();

        LessonQuizAttempt saved = quizAttemptRepository.save(attempt);

        // Auto mark the lesson as completed upon quiz attempt submission
        // Du diem cao hay thap van danh dau bai hoc la "da hoan thanh" (khong bat
        // buoc phai dat/pass) - viec dieu huong lai lo trinh hoc (pathway reroute)
        // khi diem thap la logic RIENG o Frontend, khong lien quan completeLesson nay.
        try {
            completeLesson(lessonId, userId, true);
        } catch (Exception e) {
            e.printStackTrace(); // Log warning but let transaction commit quiz attempt
        }

        return LessonQuizAttemptDTO.builder()
                .attemptNumber(saved.getAttemptNumber())
                .state(saved.getState())
                .grade(String.format("%.1f / 10.0", saved.getScore()))
                .submittedTime(saved.getSubmittedAt().toString().replace("T", " ").substring(0, 16))
                .answers(request.getAnswers())
                .build();
    }

    // Cham lai diem quiz TU DAP AN DUNG luu trong DB, khong dua tren diem
    // Frontend tu gui len. Dung lai chinh dinh dang du lieu cau hoi/cau tra loi
    // hien co: "answers" la Map<String, Integer> voi KEY la VI TRI (index, dang
    // chuoi) cua cau hoi trong danh sach tra ve boi GET /lessons/{id} (xem
    // lesson_detail_page.dart _submitQuiz va getLessonDetail() o tren) - khong
    // phai question_id that trong DB, nen phai lay dap an dung THEO DUNG THU TU
    // hien thi (ORDER BY lq.display_order ASC) de khop dung vi tri.
    private double computeServerSideScore(Long lessonId, LessonQuizAttemptRequestDTO request) {
        List<Long> questionIds = jdbcTemplate.query(
                "SELECT q.id AS question_id " +
                "FROM lesson_quizzes lq " +
                "JOIN questions q ON lq.question_id = q.id " +
                "WHERE lq.lesson_id = ? " +
                "ORDER BY lq.display_order ASC",
                (rs, rowNum) -> rs.getLong("question_id"),
                lessonId
        );

        // Khong tim thay cau hoi quiz nao cho bai hoc nay trong DB (vd du lieu
        // chua dong bo, hoac day khong phai lesson loai quiz) -> khong the cham
        // lai duoc, danh fallback ve diem Frontend gui len de tinh nang khong bi
        // gian doan, thay vi luon tra ve 0 diem sai lech thuc te.
        if (questionIds == null || questionIds.isEmpty()) {
            return request.getScore() != null ? request.getScore() : 0.0;
        }

        String placeholders = questionIds.stream().map(id -> "?").collect(Collectors.joining(", "));
        List<Map<String, Object>> optionsRows = jdbcTemplate.queryForList(
                "SELECT question_id, is_correct FROM question_options " +
                "WHERE question_id IN (" + placeholders + ") ORDER BY question_id ASC, id ASC",
                questionIds.toArray()
        );

        Map<Long, Integer> correctIndexByQuestionId = new HashMap<>();
        Map<Long, Integer> optionCounterByQuestionId = new HashMap<>();
        if (optionsRows != null) {
            for (Map<String, Object> row : optionsRows) {
                Long questionId = ((Number) row.get("question_id")).longValue();
                int optionIndex = optionCounterByQuestionId.merge(questionId, 1, Integer::sum) - 1;

                Object isCorrectObj = row.get("is_correct");
                boolean isCorrect = false;
                if (isCorrectObj instanceof Boolean) {
                    isCorrect = (Boolean) isCorrectObj;
                } else if (isCorrectObj instanceof Number) {
                    isCorrect = ((Number) isCorrectObj).intValue() == 1;
                }
                if (isCorrect) {
                    correctIndexByQuestionId.put(questionId, optionIndex);
                }
            }
        }

        Map<String, Integer> submittedAnswers = request.getAnswers();
        int correctCount = 0;
        for (int position = 0; position < questionIds.size(); position++) {
            Integer correctIndex = correctIndexByQuestionId.get(questionIds.get(position));
            Integer selectedIndex = submittedAnswers != null ? submittedAnswers.get(String.valueOf(position)) : null;
            if (correctIndex != null && correctIndex.equals(selectedIndex)) {
                correctCount++;
            }
        }

        return ((double) correctCount / questionIds.size()) * 10.0;
    }

    // Trai tim cua tinh nang "Progress Tracking": cap nhat trang thai hoan
    // thanh cua 1 bai hoc, roi TINH LAI % tien do cua ca khoa hoc (Enrollment
    // .progressPercentage), va tu dong cap CHUNG CHI (Certificate) neu day la
    // bai hoc cuoi cung con thieu.
    @Override
    @Transactional
    public void completeLesson(Long lessonId, Long userId, boolean isCompleted) {
        User user = userRepository.findById(userId)
                .orElseThrow(() -> new ApiException("User not found", HttpStatus.NOT_FOUND));
        Lesson lesson = lessonRepository.findById(lessonId)
                .orElseThrow(() -> new ApiException("Lesson not found", HttpStatus.NOT_FOUND));

        // Bang lesson_progresses co UNIQUE(user_id, lesson_id) -> moi cap
        // user+lesson chi co DUY NHAT 1 dong. Neu chua tung hoc bai nay,
        // tao moi voi trang thai NGUOC voi isCompleted de dam bao dieu kien
        // "if (progress.isCompleted() == isCompleted) return;" ben duoi luon sai
        // o lan dau, cho phep insert dong dau tien.
        LessonProgress progress = lessonProgressRepository.findByUserIdAndLessonId(userId, lessonId)
                .orElseGet(() -> LessonProgress.builder()
                        .user(user)
                        .lesson(lesson)
                        .isCompleted(!isCompleted)
                        .build());

        // Da o dung trang thai roi thi khong lam gi them (tranh tinh lai % thua)
        if (progress.isCompleted() == isCompleted) {
            return;
        }

        progress.setCompleted(isCompleted);
        progress.setCompletedAt(isCompleted ? LocalDateTime.now() : null);
        lessonProgressRepository.save(progress);

        if (lesson.getSection() != null && lesson.getSection().getCourse() != null) {
            Long courseId = lesson.getSection().getCourse().getId();

            // Acquire pessimistic write lock to calculate progress and prevent concurrency races
            // (khoa ghi tren dong Enrollment de tranh 2 request hoan thanh bai
            // cung luc tinh sai % - vi du hoc tren 2 tab/thiet bi cung mot luc)
            Enrollment enrollment = enrollmentRepository.findByUserIdAndCourseIdWithLock(userId, courseId)
                    .orElse(null);

            if (enrollment != null) {
                long totalLessons = lessonRepository.countByCourseId(courseId);
                if (totalLessons > 0) {
                    // % tien do = so bai da hoan thanh / tong so bai cua khoa hoc
                    long completedLessons = lessonProgressRepository.countCompletedLessonsByUserIdAndCourseId(userId, courseId);
                    BigDecimal percentage = BigDecimal.valueOf((double) completedLessons / totalLessons * 100)
                            .setScale(2, RoundingMode.HALF_UP);

                    enrollment.setProgressPercentage(percentage);

                    if (completedLessons == totalLessons) {
                        // Hoc xong TAT CA bai -> khoa hoc COMPLETED va cap chung chi
                        // (generateCertificateIfNotExists tu kiem tra trung, an toan
                        // khi ham nay bi goi lai nhieu lan).
                        enrollment.setStatus("COMPLETED");
                        enrollment.setCompletedAt(LocalDateTime.now());
                        certificateService.generateCertificateIfNotExists(userId, courseId);
                    } else {
                        enrollment.setStatus("ENROLLED");
                        enrollment.setCompletedAt(null);
                    }
                    enrollmentRepository.save(enrollment);
                }
            }
        }
    }
}
