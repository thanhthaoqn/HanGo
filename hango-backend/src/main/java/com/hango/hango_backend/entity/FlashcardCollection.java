package com.hango.hango_backend.entity;

import jakarta.persistence.*;
import lombok.Data;
import lombok.ToString;
import lombok.EqualsAndHashCode;
import java.util.ArrayList;
import java.util.List;

@Entity
@Table(name = "hango_flashcard_collections")
@Data
@ToString(exclude = {"flashcards", "createdBy"})
@EqualsAndHashCode(exclude = {"flashcards", "createdBy"})
public class FlashcardCollection {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    private String title;

    @Column(columnDefinition = "TEXT")
    private String description;

    private String creator;

    @Column(name = "sentence_count")
    private Integer sentenceCount = 0;

    @Column(name = "duration_minutes")
    private Integer durationMinutes = 0;

    private Double rating = 5.0;

    @Column(name = "learner_count")
    private String learnerCount = "0 Learner";

    @Column(name = "image_url", columnDefinition = "TEXT")
    private String imageUrl;

    @OneToMany(mappedBy = "collection", cascade = CascadeType.ALL, orphanRemoval = true)
    private List<Flashcard> flashcards = new ArrayList<>();

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "created_by", referencedColumnName = "id")
    private User createdBy;
}
