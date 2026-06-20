package com.hango.hango_backend.controller;

import com.hango.hango_backend.repository.CommentRepository;
import com.hango.hango_backend.entity.Comment;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

import java.time.format.DateTimeFormatter;
import java.util.*;

@CrossOrigin(origins = "*", maxAge = 3600)
@RestController
@RequestMapping("/api/admin")
public class AdminCommentController {

    @Autowired
    private CommentRepository commentRepository;

    @GetMapping("/comments")
    @PreAuthorize("hasRole('ADMINISTRATOR')")
    public ResponseEntity<?> getAllComments() {
        try {
            List<Comment> comments = commentRepository.findAllByOrderByCreatedAtDesc();
            List<Map<String, Object>> responseList = new ArrayList<>();
            DateTimeFormatter formatter = DateTimeFormatter.ofPattern("dd/MM/yyyy HH:mm");

            for (Comment c : comments) {
                Map<String, Object> map = new HashMap<>();
                map.put("id", c.getId());
                map.put("type", "lesson"); // default type to lesson
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
                
                String dateStr = c.getCreatedAt() != null ? c.getCreatedAt().format(formatter) : "";
                map.put("createdAt", dateStr);

                responseList.add(map);
            }

            return ResponseEntity.ok(responseList);
        } catch (Exception e) {
            return ResponseEntity.badRequest().body("Error: " + e.getMessage());
        }
    }

    @PutMapping("/comments/{id}/status")
    @PreAuthorize("hasRole('ADMINISTRATOR')")
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
}
