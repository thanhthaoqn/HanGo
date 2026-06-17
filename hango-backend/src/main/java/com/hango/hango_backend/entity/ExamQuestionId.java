package com.hango.hango_backend.entity;

import jakarta.persistence.Column;
import jakarta.persistence.Embeddable;
import lombok.Data;
import lombok.NoArgsConstructor;
import lombok.AllArgsConstructor;
import java.io.Serializable;

@Embeddable
@Data
@NoArgsConstructor
@AllArgsConstructor
public class ExamQuestionId implements Serializable {
    @Column(name = "exam_id")
    private Long examId;

    @Column(name = "question_id")
    private Long questionId;
}
