package com.hango.hango_backend.entity;

import jakarta.persistence.*;
import lombok.Data;

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
    @JoinColumn(name = "skill_param_id", referencedColumnName = "id", nullable = false)
    private SystemParameter skillParam;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "difficulty_param_id", referencedColumnName = "id", nullable = false)
    private SystemParameter difficultyParam;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "group_type_id", nullable = true)
    private SystemParameter groupTypeParam;

    @Column(nullable = false)
    private Integer quantity;
}
