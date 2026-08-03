package com.hango.hango_backend.repository;

import com.hango.hango_backend.entity.Question;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

@Repository
public interface QuestionRepository extends JpaRepository<Question, Long> {
    @org.springframework.data.jpa.repository.EntityGraph(attributePaths = {"options", "questionGroup", "skillParam"})
    @org.springframework.data.jpa.repository.Query("SELECT q FROM Question q JOIN ExamQuestion eq ON q.id = eq.id.questionId WHERE eq.id.examId = :examId ORDER BY eq.questionOrder ASC")
    java.util.List<Question> findByExamIdOrderByQuestionOrder(@org.springframework.data.repository.query.Param("examId") Long examId);
    java.util.List<Question> findByQuestionGroup(com.hango.hango_backend.entity.QuestionGroup questionGroup);

    @org.springframework.data.jpa.repository.Query(value = "SELECT q.* FROM questions q LEFT JOIN question_groups qg ON q.group_id = qg.id WHERE q.skill_param_id = :skillId AND q.difficulty_param_id = :diffId AND q.created_by = :userId AND ((:groupTypeId IS NULL AND q.group_id IS NULL) OR (qg.group_type_param_id = :groupTypeId)) ORDER BY RAND() LIMIT :limit", nativeQuery = true)
    java.util.List<Question> findRandomQuestionsByCriteria(@org.springframework.data.repository.query.Param("skillId") Long skillId, @org.springframework.data.repository.query.Param("diffId") Long diffId, @org.springframework.data.repository.query.Param("groupTypeId") Long groupTypeId, @org.springframework.data.repository.query.Param("userId") Long userId, @org.springframework.data.repository.query.Param("limit") int limit);

    @org.springframework.data.jpa.repository.Query(value = "SELECT COUNT(q.id) FROM questions q LEFT JOIN question_groups qg ON q.group_id = qg.id WHERE q.skill_param_id = :skillId AND q.difficulty_param_id = :diffId AND q.created_by = :userId AND ((:groupTypeId IS NULL AND q.group_id IS NULL) OR (qg.group_type_param_id = :groupTypeId))", nativeQuery = true)
    long countQuestionsByCriteria(@org.springframework.data.repository.query.Param("skillId") Long skillId, @org.springframework.data.repository.query.Param("diffId") Long diffId, @org.springframework.data.repository.query.Param("groupTypeId") Long groupTypeId, @org.springframework.data.repository.query.Param("userId") Long userId);
}
