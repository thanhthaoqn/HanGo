package com.hango.hango_backend.service;

import com.hango.hango_backend.dto.CommentDTO;
import com.hango.hango_backend.dto.CommentRequestDTO;

import java.util.List;

public interface CommentService {
    List<CommentDTO> getCommentsByLesson(Long lessonId);
    CommentDTO addComment(Long lessonId, Long userId, CommentRequestDTO request);
    CommentDTO updateComment(Long commentId, Long userId, CommentRequestDTO request);
    void deleteComment(Long commentId, Long userId);
}
