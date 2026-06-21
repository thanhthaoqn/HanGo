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

    @GetMapping("/lesson/{lessonId}")
    public ResponseEntity<List<CommentDTO>> getCommentsByLesson(@PathVariable Long lessonId) {
        return ResponseEntity.ok(commentService.getCommentsByLesson(lessonId));
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
}
