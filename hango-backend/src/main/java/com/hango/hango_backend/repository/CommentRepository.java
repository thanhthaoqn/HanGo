package com.hango.hango_backend.repository;

import com.hango.hango_backend.entity.Comment;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;

@Repository
public interface CommentRepository extends JpaRepository<Comment, Long> {
    List<Comment> findByLessonIdOrderByCreatedAtDesc(Long lessonId);
    List<Comment> findAllByOrderByCreatedAtDesc();
}
