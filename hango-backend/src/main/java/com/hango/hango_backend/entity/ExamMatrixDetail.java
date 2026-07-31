package com.hango.hango_backend.entity;

import jakarta.persistence.*;
import lombok.Data;
import org.hibernate.annotations.NotFound;
import org.hibernate.annotations.NotFoundAction;

@Entity
@Table(name = "exam_matrix_details")
@Data
public class ExamMatrixDetail {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "matrix_id", referencedColumnName = "id", nullable = false)
    private ExamMatrix matrix;

    @ManyToOne(fetch = FetchType.LAZY)
    @NotFound(action = NotFoundAction.IGNORE)
    @JoinColumn(name = "skill_param_id", referencedColumnName = "id", nullable = false)
    private SystemParameter skillParam;

    @ManyToOne(fetch = FetchType.LAZY)
    @NotFound(action = NotFoundAction.IGNORE)
    @JoinColumn(name = "difficulty_param_id", referencedColumnName = "id", nullable = false)
    private SystemParameter difficultyParam;

    @ManyToOne(fetch = FetchType.LAZY)
    @NotFound(action = NotFoundAction.IGNORE)
    @JoinColumn(name = "group_type_id", nullable = true)
    private SystemParameter groupTypeParam;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "category_id", referencedColumnName = "id", nullable = true)
    private QuestionCategory category;

    @Column(nullable = false)
    private Integer quantity;
}
