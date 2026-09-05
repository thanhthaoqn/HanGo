package com.hango.hango_backend.repository;

import com.hango.hango_backend.entity.Question;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

@Repository
public interface QuestionRepository extends JpaRepository<Question, Long> {
    @org.springframework.data.jpa.repository.EntityGraph(attributePaths = {"options", "questionGroup", "questionGroup.groupTypeParam", "skillParam", "difficulty", "section"})
    @org.springframework.data.jpa.repository.Query("SELECT q FROM Question q JOIN ExamQuestion eq ON q.id = eq.id.questionId WHERE eq.id.examId = :examId ORDER BY eq.questionOrder ASC")
    java.util.List<Question> findByExamIdOrderByQuestionOrder(@org.springframework.data.repository.query.Param("examId") Long examId);
    @org.springframework.data.jpa.repository.EntityGraph(attributePaths = {"options", "skillParam", "difficulty", "section"})
    java.util.List<Question> findByQuestionGroup(com.hango.hango_backend.entity.QuestionGroup questionGroup);

    // questionSourceType: 1 = Quiz bank only, 2 = Exam bank only, 3 (or null) = both banks (no restriction)
    @org.springframework.data.jpa.repository.Query(value = "SELECT q.* FROM questions q LEFT JOIN question_groups qg ON q.group_id = qg.id WHERE q.skill_param_id = :skillId AND q.difficulty_param_id = :diffId AND q.created_by = :userId AND ((:groupTypeId IS NULL AND q.group_id IS NULL) OR (qg.group_type_param_id = :groupTypeId)) AND (:questionSourceType IS NULL OR :questionSourceType = 3 OR (:questionSourceType = 1 AND (q.usage_type = '1' OR q.usage_type = 'QUIZ_ONLY' OR q.usage_type = '3' OR q.usage_type = 'BOTH')) OR (:questionSourceType = 2 AND (q.usage_type = '2' OR q.usage_type = 'EXAM_ONLY' OR q.usage_type = '3' OR q.usage_type = 'BOTH'))) ORDER BY RAND() LIMIT :limit", nativeQuery = true)
    java.util.List<Question> findRandomQuestionsByCriteria(@org.springframework.data.repository.query.Param("skillId") Long skillId, @org.springframework.data.repository.query.Param("diffId") Long diffId, @org.springframework.data.repository.query.Param("groupTypeId") Long groupTypeId, @org.springframework.data.repository.query.Param("userId") Long userId, @org.springframework.data.repository.query.Param("questionSourceType") Integer questionSourceType, @org.springframework.data.repository.query.Param("limit") int limit);

    @org.springframework.data.jpa.repository.Query(value = "SELECT COUNT(q.id) FROM questions q LEFT JOIN question_groups qg ON q.group_id = qg.id WHERE q.skill_param_id = :skillId AND q.difficulty_param_id = :diffId AND q.created_by = :userId AND ((:groupTypeId IS NULL AND q.group_id IS NULL) OR (qg.group_type_param_id = :groupTypeId)) AND (:questionSourceType IS NULL OR :questionSourceType = 3 OR (:questionSourceType = 1 AND (q.usage_type = '1' OR q.usage_type = 'QUIZ_ONLY' OR q.usage_type = '3' OR q.usage_type = 'BOTH')) OR (:questionSourceType = 2 AND (q.usage_type = '2' OR q.usage_type = 'EXAM_ONLY' OR q.usage_type = '3' OR q.usage_type = 'BOTH')))", nativeQuery = true)
    long countQuestionsByCriteria(@org.springframework.data.repository.query.Param("skillId") Long skillId, @org.springframework.data.repository.query.Param("diffId") Long diffId, @org.springframework.data.repository.query.Param("groupTypeId") Long groupTypeId, @org.springframework.data.repository.query.Param("userId") Long userId, @org.springframework.data.repository.query.Param("questionSourceType") Integer questionSourceType);
}
