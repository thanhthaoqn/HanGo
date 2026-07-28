package com.hango.hango_backend.controller;

import com.hango.hango_backend.dto.CommentDTO;
import com.hango.hango_backend.dto.CommentRequestDTO;
import com.hango.hango_backend.service.CommentService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import org.springframework.security.core.annotation.AuthenticationPrincipal;
import com.hango.hango_backend.security.UserDetailsImpl;
import java.util.List;

@RestController
@RequestMapping("/api/v1/comments")
@RequiredArgsConstructor
public class CommentController {

    private final CommentService commentService;

    private Long getCurrentUserId() {
        org.springframework.security.core.Authentication auth = org.springframework.security.core.context.SecurityContextHolder.getContext().getAuthentication();
        if (auth != null && auth.getPrincipal() instanceof com.hango.hango_backend.security.UserDetailsImpl) {
            return ((com.hango.hango_backend.security.UserDetailsImpl) auth.getPrincipal()).getId();
        }
        return null;
    }

    @GetMapping("/lesson/{lessonId}")
    public ResponseEntity<List<CommentDTO>> getCommentsByLesson(@PathVariable Long lessonId) {
        Long currentUserId = getCurrentUserId();
        return ResponseEntity.ok(commentService.getCommentsByLesson(lessonId, currentUserId));
    }

    @PostMapping("/lesson/{lessonId}")
    public ResponseEntity<CommentDTO> addComment(@PathVariable Long lessonId, 
                                                 @AuthenticationPrincipal UserDetailsImpl currentUser,
                                                 @RequestBody CommentRequestDTO request) {
        return ResponseEntity.ok(commentService.addComment(lessonId, currentUser.getId(), request));
    }

    @PutMapping("/{commentId}")
    public ResponseEntity<CommentDTO> updateComment(@PathVariable Long commentId,
                                                    @AuthenticationPrincipal UserDetailsImpl currentUser,
                                                    @RequestBody CommentRequestDTO request) {
        return ResponseEntity.ok(commentService.updateComment(commentId, currentUser.getId(), request));
    }

    @DeleteMapping("/{commentId}")
    public ResponseEntity<Void> deleteComment(@PathVariable Long commentId,
                                              @AuthenticationPrincipal UserDetailsImpl currentUser) {
        commentService.deleteComment(commentId, currentUser.getId());
        return ResponseEntity.noContent().build();
    }

    @PostMapping("/{commentId}/like")
    public ResponseEntity<CommentDTO> likeComment(@PathVariable Long commentId,
                                                  @AuthenticationPrincipal UserDetailsImpl currentUser) {
        return ResponseEntity.ok(commentService.likeComment(commentId, currentUser.getId()));
    }

    @PostMapping("/{commentId}/unlike")
    public ResponseEntity<CommentDTO> unlikeComment(@PathVariable Long commentId,
                                                    @AuthenticationPrincipal UserDetailsImpl currentUser) {
        return ResponseEntity.ok(commentService.unlikeComment(commentId, currentUser.getId()));
    }
}
