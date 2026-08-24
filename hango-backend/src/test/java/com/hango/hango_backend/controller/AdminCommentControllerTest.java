package com.hango.hango_backend.controller;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.mockito.Mockito.when;

import com.hango.hango_backend.entity.Comment;
import com.hango.hango_backend.repository.CommentRepository;
import java.time.LocalDateTime;
import java.util.List;
import java.util.Map;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;

@ExtendWith(MockitoExtension.class)
class AdminCommentControllerTest {

    @Mock
    private CommentRepository commentRepository;

    @InjectMocks
    private AdminCommentController controller;

    @Test
    void getAllCommentsShouldTreatBlankStatusAsPending() {
        Comment comment = Comment.builder()
                .id(1L)
                .content("Helpful lesson")
                .status(" ")
                .createdAt(LocalDateTime.of(2026, 8, 23, 12, 0))
                .build();
        when(commentRepository.findAllByOrderByCreatedAtDesc())
                .thenReturn(List.of(comment));

        ResponseEntity<?> response = controller.getAllComments();

        assertEquals(HttpStatus.OK, response.getStatusCode());
        @SuppressWarnings("unchecked")
        List<Map<String, Object>> body = (List<Map<String, Object>>) response.getBody();
        assertEquals("Pending", body.get(0).get("status"));
    }
}
