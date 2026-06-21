package com.hango.hango_backend.service;

import com.hango.hango_backend.dto.CommentDTO;
import com.hango.hango_backend.dto.CommentRequestDTO;
import com.hango.hango_backend.entity.Comment;
import com.hango.hango_backend.entity.Lesson;
import com.hango.hango_backend.entity.User;
import com.hango.hango_backend.repository.CommentRepository;
import com.hango.hango_backend.repository.LessonRepository;
import com.hango.hango_backend.repository.UserRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;

import java.util.List;
import java.util.stream.Collectors;

@Service
@RequiredArgsConstructor
public class CommentServiceImpl implements CommentService {

    private final CommentRepository commentRepository;
    private final LessonRepository lessonRepository;
    private final UserRepository userRepository;

    @Override
    public List<CommentDTO> getCommentsByLesson(Long lessonId) {
        return commentRepository.findByLessonIdOrderByCreatedAtDesc(lessonId)
                .stream()
                .map(comment -> CommentDTO.builder()
                        .id(comment.getId())
                        .userId(comment.getUser().getId())
                        .userName(comment.getUser().getFullName()) // Assuming User has getFullName()
                        .userAvatar(comment.getUser().getAvatarUrl()) // Assuming User has getAvatarUrl()
                        .content(comment.getContent())
                        .createdAt(comment.getCreatedAt())
                        .build())
                .collect(Collectors.toList());
    }

    @Override
    public CommentDTO addComment(Long lessonId, Long userId, CommentRequestDTO request) {
        Lesson lesson = lessonRepository.findById(lessonId)
                .orElseThrow(() -> new RuntimeException("Lesson not found"));
        User user = userRepository.findById(userId)
                .orElseThrow(() -> new RuntimeException("User not found"));

        Comment comment = Comment.builder()
                .lesson(lesson)
                .user(user)
                .content(request.getContent())
                .status("APPROVED")
                .build();

        Comment savedComment = commentRepository.save(comment);

        return CommentDTO.builder()
                .id(savedComment.getId())
                .userId(savedComment.getUser().getId())
                .userName(savedComment.getUser().getFullName())
                .userAvatar(savedComment.getUser().getAvatarUrl())
                .content(savedComment.getContent())
                .createdAt(savedComment.getCreatedAt() != null ? savedComment.getCreatedAt() : java.time.LocalDateTime.now())
                .build();
    }

    @Override
    public CommentDTO updateComment(Long commentId, Long userId, CommentRequestDTO request) {
        Comment comment = commentRepository.findById(commentId)
                .orElseThrow(() -> new RuntimeException("Comment not found"));

        if (!comment.getUser().getId().equals(userId)) {
            throw new RuntimeException("You are not allowed to edit this comment");
        }

        comment.setContent(request.getContent());
        Comment savedComment = commentRepository.save(comment);

        return CommentDTO.builder()
                .id(savedComment.getId())
                .userId(savedComment.getUser().getId())
                .userName(savedComment.getUser().getFullName())
                .userAvatar(savedComment.getUser().getAvatarUrl())
                .content(savedComment.getContent())
                .createdAt(savedComment.getCreatedAt())
                .build();
    }

    @Override
    public void deleteComment(Long commentId, Long userId) {
        Comment comment = commentRepository.findById(commentId)
                .orElseThrow(() -> new RuntimeException("Comment not found"));

        if (!comment.getUser().getId().equals(userId)) {
            throw new RuntimeException("You are not allowed to delete this comment");
        }

        commentRepository.delete(comment);
    }
}
