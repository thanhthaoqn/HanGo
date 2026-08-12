package com.hango.hango_backend.controller;

import java.time.format.DateTimeFormatter;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Optional;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.CrossOrigin;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import com.hango.hango_backend.entity.Comment;
import com.hango.hango_backend.repository.CommentRepository;

@CrossOrigin(origins = "*", maxAge = 3600)
@RestController
@RequestMapping("/api/admin")
public class AdminCommentController {

    @Autowired
    private CommentRepository commentRepository;

    @GetMapping("/comments")
    @PreAuthorize("hasAuthority('MODERATE_COMMENTS') or hasAuthority('MANAGE_ACCOUNTS_ROLES') or hasRole('ADMINISTRATOR')")
    public ResponseEntity<?> getAllComments() {
        try {
            List<Comment> comments = commentRepository.findAllByOrderByCreatedAtDesc();
            List<Map<String, Object>> responseList = new ArrayList<>();
            DateTimeFormatter formatter = DateTimeFormatter.ofPattern("dd/MM/yyyy HH:mm");

            for (Comment c : comments) {
                responseList.add(toSummaryMap(c, formatter));
            }

            return ResponseEntity.ok(responseList);
        } catch (Exception e) {
            return ResponseEntity.badRequest().body("Error: " + e.getMessage());
        }
    }

    @GetMapping("/comments/{id}")
    @PreAuthorize("hasAuthority('MODERATE_COMMENTS') or hasAuthority('MANAGE_ACCOUNTS_ROLES') or hasRole('ADMINISTRATOR')")
    public ResponseEntity<?> getCommentDetail(@PathVariable Long id) {
        Optional<Comment> commentOpt = commentRepository.findById(id);
        if (commentOpt.isEmpty()) {
            return ResponseEntity.status(404).body("Comment not found");
        }

        Comment c = commentOpt.get();
        DateTimeFormatter formatter = DateTimeFormatter.ofPattern("dd/MM/yyyy HH:mm");

        Map<String, Object> map = toSummaryMap(c, formatter);
        map.put("originalContent", c.getContent());
        map.put("normalizedContent", c.getNormalizedContent());
        map.put("detectionReason", c.getDetectionReason());
        return ResponseEntity.ok(map);
    }

    @PutMapping("/comments/{id}/status")
    @PreAuthorize("hasAuthority('MODERATE_COMMENTS') or hasAuthority('MANAGE_ACCOUNTS_ROLES') or hasRole('ADMINISTRATOR')")
    public ResponseEntity<?> updateCommentStatus(@PathVariable Long id, @RequestParam String status) {
        try {
            Optional<Comment> commentOpt = commentRepository.findById(id);
            if (commentOpt.isPresent()) {
                Comment comment = commentOpt.get();
                // Store in uppercase in DB (e.g. APPROVED, REJECTED, PENDING)
                comment.setStatus(status.toUpperCase());
                commentRepository.save(comment);
                return ResponseEntity.ok(Map.of("success", true, "message", "Comment status updated successfully"));
            } else {
                return ResponseEntity.status(404).body("Comment not found");
            }
        } catch (Exception e) {
            return ResponseEntity.badRequest().body("Error: " + e.getMessage());
        }
    }

    @DeleteMapping("/comments/{id}")
    @PreAuthorize("hasAuthority('MODERATE_COMMENTS') or hasAuthority('MANAGE_ACCOUNTS_ROLES') or hasRole('ADMINISTRATOR')")
    public ResponseEntity<?> deleteComment(@PathVariable Long id) {
        if (!commentRepository.existsById(id)) {
            return ResponseEntity.status(404).body("Comment not found");
        }
        commentRepository.deleteById(id);
        return ResponseEntity.ok(Map.of("success", true, "message", "Comment deleted successfully"));
    }

    private Map<String, Object> toSummaryMap(Comment c, DateTimeFormatter formatter) {
        Map<String, Object> map = new HashMap<>();
        map.put("id", c.getId());
        String commentType = "lesson";
        if (c.getLesson() != null && "PRACTICE".equalsIgnoreCase(c.getLesson().getLessonType())) {
            commentType = "quiz";
        }
        map.put("type", commentType);
        map.put("userId", c.getUser() != null ? c.getUser().getId() : 0);
        map.put("commenter", c.getUser() != null ? c.getUser().getFullName() : "Anonymous");
        map.put("email", c.getUser() != null ? c.getUser().getEmail() : "");
        map.put("comment", c.getContent());

        // Format status nicely (Approved, Rejected, Pending)
        String rawStatus = c.getStatus() != null ? c.getStatus() : "PENDING";
        String formattedStatus = rawStatus.substring(0, 1).toUpperCase() + rawStatus.substring(1).toLowerCase();
        map.put("status", formattedStatus);

        String contextTitle = "General";
        if (c.getLesson() != null) {
            contextTitle = c.getLesson().getTitle();
        } else if (c.getCourse() != null) {
            contextTitle = c.getCourse().getTitle();
        }
        map.put("quizOrLesson", contextTitle);
        map.put("course", resolveCourseTitle(c));

        String dateStr = c.getCreatedAt() != null ? c.getCreatedAt().format(formatter) : "";
        map.put("createdAt", dateStr);

        return map;
    }

    private String resolveCourseTitle(Comment c) {
        if (c.getCourse() != null) {
            return c.getCourse().getTitle();
        }
        if (c.getLesson() != null && c.getLesson().getSection() != null
                && c.getLesson().getSection().getCourse() != null) {
            return c.getLesson().getSection().getCourse().getTitle();
        }
        return "N/A";
    }
}
