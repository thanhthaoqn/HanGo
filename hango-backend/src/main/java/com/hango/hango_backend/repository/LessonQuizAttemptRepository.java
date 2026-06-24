package com.hango.hango_backend.repository;

import com.hango.hango_backend.entity.LessonQuizAttempt;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;

@Repository
public interface LessonQuizAttemptRepository extends JpaRepository<LessonQuizAttempt, Long> {
    List<LessonQuizAttempt> findByLessonIdAndStudentIdOrderByAttemptNumberAsc(Long lessonId, Long studentId);
    int countByLessonIdAndStudentId(Long lessonId, Long studentId);
}
