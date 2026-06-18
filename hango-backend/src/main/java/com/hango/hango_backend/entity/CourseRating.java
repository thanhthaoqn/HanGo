package com.hango.hango_backend.entity;

import jakarta.persistence.*;
import lombok.*;

@Entity
@Table(name = "course_ratings")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class CourseRating {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "course_id", nullable = false)
    private Course course;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "student_id", nullable = false)
    private User student;

    @Column(nullable = false)
    private Short rating;

    @Column(name = "review_content", columnDefinition = "TEXT")
    private String reviewContent;
}
