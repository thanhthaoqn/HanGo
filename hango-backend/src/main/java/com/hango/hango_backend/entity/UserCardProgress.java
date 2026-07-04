package com.hango.hango_backend.entity;

import jakarta.persistence.*;
import lombok.Data;

@Entity
@Table(name = "hango_user_card_progress")
@Data
public class UserCardProgress {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "user_id", referencedColumnName = "id")
    private User user;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "card_id", referencedColumnName = "id")
    private Flashcard card;

    @Column(name = "is_learned")
    private Boolean isLearned = false;
}
