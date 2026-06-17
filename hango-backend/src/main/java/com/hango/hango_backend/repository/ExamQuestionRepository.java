package com.hango.hango_backend.repository;

import com.hango.hango_backend.entity.ExamQuestion;
import com.hango.hango_backend.entity.ExamQuestionId;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

@Repository
public interface ExamQuestionRepository extends JpaRepository<ExamQuestion, ExamQuestionId> {
    int countByIdExamId(Long examId);
}
