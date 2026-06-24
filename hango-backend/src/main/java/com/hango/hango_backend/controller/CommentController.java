package com.hango.hango_backend.controller;

import com.hango.hango_backend.dto.CommentDTO;
import com.hango.hango_backend.dto.CommentRequestDTO;
import com.hango.hango_backend.service.CommentService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api/v1/comments")
@RequiredArgsConstructor
public class CommentController {

    private final CommentService commentService;

    private Long getCurrentUserId() {
        org.springframework.security.core.Authentication auth = org.springframework.security.core.context.SecurityContextHolder.getContext().getAuthentication();
        if (auth != null && auth.getPrincipal() instanceof com.hango.hango_backend.sercurity.UserDetailsImpl) {
            return ((com.hango.hango_backend.sercurity.UserDetailsImpl) auth.getPrincipal()).getId();
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
                                                 @RequestParam Long userId, // Replace with UserPrincipal from SecurityContext later
                                                 @RequestBody CommentRequestDTO request) {
        return ResponseEntity.ok(commentService.addComment(lessonId, userId, request));
    }

    @PutMapping("/{commentId}")
    public ResponseEntity<CommentDTO> updateComment(@PathVariable Long commentId,
                                                    @RequestParam Long userId,
                                                    @RequestBody CommentRequestDTO request) {
        return ResponseEntity.ok(commentService.updateComment(commentId, userId, request));
    }

    @DeleteMapping("/{commentId}")
    public ResponseEntity<Void> deleteComment(@PathVariable Long commentId,
                                              @RequestParam Long userId) {
        commentService.deleteComment(commentId, userId);
        return ResponseEntity.noContent().build();
    }

    @PostMapping("/{commentId}/like")
    public ResponseEntity<CommentDTO> likeComment(@PathVariable Long commentId,
                                                  @RequestParam Long userId) {
        return ResponseEntity.ok(commentService.likeComment(commentId, userId));
    }

    @PostMapping("/{commentId}/unlike")
    public ResponseEntity<CommentDTO> unlikeComment(@PathVariable Long commentId,
                                                    @RequestParam Long userId) {
        return ResponseEntity.ok(commentService.unlikeComment(commentId, userId));
    }
}
