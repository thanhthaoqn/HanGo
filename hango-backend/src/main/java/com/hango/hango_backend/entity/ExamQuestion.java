package com.hango.hango_backend.entity;

import jakarta.persistence.*;
import lombok.Data;

@Entity
@Table(name = "exam_questions")
@Data
public class ExamQuestion {
    @EmbeddedId
    private ExamQuestionId id;

    @Column(name = "question_order")
    private Integer questionOrder;
}
