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

    private CommentDTO convertToDTO(Comment comment, Long currentUserId) {
        return CommentDTO.builder()
                .id(comment.getId())
                .userId(comment.getUser().getId())
                .userName(comment.getUser().getFullName())
                .userAvatar(comment.getUser().getAvatarUrl())
                .content(comment.getContent())
                .createdAt(comment.getCreatedAt() != null ? comment.getCreatedAt() : java.time.LocalDateTime.now())
                .parentCommentId(comment.getParentComment() != null ? comment.getParentComment().getId() : null)
                .likeCount(comment.getLikedUsers() != null ? comment.getLikedUsers().size() : 0)
                .isLiked(currentUserId != null && comment.getLikedUsers() != null &&
                        comment.getLikedUsers().stream().anyMatch(u -> u.getId().equals(currentUserId)))
                .build();
    }

    @Override
    public List<CommentDTO> getCommentsByLesson(Long lessonId, Long currentUserId) {
        return commentRepository.findByLessonIdOrderByCreatedAtDesc(lessonId)
                .stream()
                .map(comment -> convertToDTO(comment, currentUserId))
                .collect(Collectors.toList());
    }

    @Override
    public CommentDTO addComment(Long lessonId, Long userId, CommentRequestDTO request) {
        Lesson lesson = lessonRepository.findById(lessonId)
                .orElseThrow(() -> new RuntimeException("Lesson not found"));
        User user = userRepository.findById(userId)
                .orElseThrow(() -> new RuntimeException("User not found"));

        Comment parent = null;
        if (request.getParentCommentId() != null) {
            parent = commentRepository.findById(request.getParentCommentId())
                    .orElseThrow(() -> new RuntimeException("Parent comment not found"));
        }

        Comment comment = Comment.builder()
                .lesson(lesson)
                .user(user)
                .content(request.getContent())
                .parentComment(parent)
                .status("APPROVED")
                .build();

        Comment savedComment = commentRepository.save(comment);
        return convertToDTO(savedComment, userId);
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
        return convertToDTO(savedComment, userId);
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

    @Override
    @org.springframework.transaction.annotation.Transactional
    public CommentDTO likeComment(Long commentId, Long userId) {
        Comment comment = commentRepository.findById(commentId)
                .orElseThrow(() -> new RuntimeException("Comment not found"));
        User user = userRepository.findById(userId)
                .orElseThrow(() -> new RuntimeException("User not found"));

        comment.getLikedUsers().add(user);
        Comment savedComment = commentRepository.save(comment);
        return convertToDTO(savedComment, userId);
    }

    @Override
    @org.springframework.transaction.annotation.Transactional
    public CommentDTO unlikeComment(Long commentId, Long userId) {
        Comment comment = commentRepository.findById(commentId)
                .orElseThrow(() -> new RuntimeException("Comment not found"));
        User user = userRepository.findById(userId)
                .orElseThrow(() -> new RuntimeException("User not found"));

        comment.getLikedUsers().remove(user);
        Comment savedComment = commentRepository.save(comment);
        return convertToDTO(savedComment, userId);
    }
}
