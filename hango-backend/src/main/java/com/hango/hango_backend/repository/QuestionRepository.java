package com.hango.hango_backend.repository;

import com.hango.hango_backend.entity.Question;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

@Repository
public interface QuestionRepository extends JpaRepository<Question, Long> {
    @org.springframework.data.jpa.repository.Query("SELECT q FROM Question q JOIN ExamQuestion eq ON q.id = eq.id.questionId WHERE eq.id.examId = :examId ORDER BY eq.questionOrder ASC")
    java.util.List<Question> findByExamIdOrderByQuestionOrder(@org.springframework.data.repository.query.Param("examId") Long examId);
    java.util.List<Question> findByQuestionGroup(com.hango.hango_backend.entity.QuestionGroup questionGroup);
}
