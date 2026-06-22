package com.hango.hango_backend.service;

import com.hango.hango_backend.dto.CommentDTO;
import com.hango.hango_backend.dto.LessonDetailDTO;
import com.hango.hango_backend.dto.QuizQuestionDTO;
import com.hango.hango_backend.entity.Lesson;
import com.hango.hango_backend.repository.LessonRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;

import java.util.List;
import java.util.Map;

@Service
@RequiredArgsConstructor
public class LessonServiceImpl implements LessonService {

    private final LessonRepository lessonRepository;
    private final CommentService commentService;
    private final JdbcTemplate jdbcTemplate;

    @Override
    public LessonDetailDTO getLessonDetail(Long lessonId) {
        Lesson lesson = lessonRepository.findById(lessonId)
                .orElseThrow(() -> new RuntimeException("Lesson not found"));

        List<CommentDTO> comments = commentService.getCommentsByLesson(lessonId);

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
                    String explanation = rs.getString("explanation");
                    String passage = rs.getString("passage");

                    List<Map<String, Object>> optionsRows = jdbcTemplate.queryForList(
                            "SELECT option_text, is_correct FROM question_options WHERE question_id = ? ORDER BY id ASC",
                            qId
                    );

                    List<String> options = new java.util.ArrayList<>();
                    Integer correctIndex = 0;
                    for (int i = 0; i < optionsRows.size(); i++) {
                        Map<String, Object> row = optionsRows.get(i);
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

                    return QuizQuestionDTO.builder()
                            .id(qId)
                            .passage(passage)
                            .questionText(questionText)
                            .explanation(explanation)
                            .options(options)
                            .correctIndex(correctIndex)
                            .build();
                },
                lessonId
        );

        return LessonDetailDTO.builder()
                .id(lesson.getId())
                .title(lesson.getTitle())
                .content(lesson.getContent())
                .sectionId(lesson.getSection() != null ? lesson.getSection().getId() : null)
                .courseId(lesson.getSection() != null && lesson.getSection().getCourse() != null 
                            ? lesson.getSection().getCourse().getId() : null)
                .comments(comments)
                .questions(questions)
                .build();
    }
}
