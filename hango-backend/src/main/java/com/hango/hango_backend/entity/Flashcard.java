package com.hango.hango_backend.entity;

import com.fasterxml.jackson.annotation.JsonIgnore;
import jakarta.persistence.*;
import lombok.Data;
import lombok.ToString;
import lombok.EqualsAndHashCode;

@Entity
@Table(name = "hango_flashcards")
@Data
@ToString(exclude = {"collection"})
@EqualsAndHashCode(exclude = {"collection"})
public class Flashcard {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "front_text", columnDefinition = "TEXT")
    private String frontText;

    @Column(name = "back_text", columnDefinition = "TEXT")
    private String backText;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "collection_id", referencedColumnName = "id")
    @JsonIgnore
    private FlashcardCollection collection;
}
