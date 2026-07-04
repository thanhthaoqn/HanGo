package com.hango.hango_backend.entity;

import jakarta.persistence.*;
import lombok.Data;
import java.time.LocalDateTime;

@Entity
@Table(name = "hango_user_flashcard_progress")
@Data
public class UserFlashcardProgress {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "user_id", referencedColumnName = "id")
    private User user;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "collection_id", referencedColumnName = "id")
    private FlashcardCollection collection;

    @Column(name = "is_recent")
    private Boolean isRecent = false;

    @Column(name = "is_learned")
    private Boolean isLearned = false;

    @Column(name = "last_studied_at")
    private LocalDateTime lastStudiedAt;
}
