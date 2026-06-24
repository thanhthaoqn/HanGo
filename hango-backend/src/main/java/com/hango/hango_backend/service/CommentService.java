package com.hango.hango_backend.service;

import com.hango.hango_backend.dto.CommentDTO;
import com.hango.hango_backend.dto.CommentRequestDTO;

import java.util.List;

public interface CommentService {
    List<CommentDTO> getCommentsByLesson(Long lessonId, Long currentUserId);
    CommentDTO addComment(Long lessonId, Long userId, CommentRequestDTO request);
    CommentDTO updateComment(Long commentId, Long userId, CommentRequestDTO request);
    void deleteComment(Long commentId, Long userId);
    CommentDTO likeComment(Long commentId, Long userId);
    CommentDTO unlikeComment(Long commentId, Long userId);
}
