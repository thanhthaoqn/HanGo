package com.hango.hango_backend.entity;

import jakarta.persistence.*;
import lombok.Data;
import org.hibernate.annotations.NotFound;
import org.hibernate.annotations.NotFoundAction;
import java.util.List;

@Entity
@Table(name = "question_groups")
@Data
public class QuestionGroup {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "context_text", columnDefinition = "TEXT")
    private String contextText;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "group_type_param_id", referencedColumnName = "id", nullable = true)
    @NotFound(action = NotFoundAction.IGNORE)
    private SystemParameter groupTypeParam;

    @OneToMany(mappedBy = "questionGroup", cascade = CascadeType.ALL, orphanRemoval = true)
    private List<Question> questions;
}
