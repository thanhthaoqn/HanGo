package com.hango.hango_backend.service;

import java.util.List;
import java.util.Optional;
import java.util.Set;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import static org.mockito.ArgumentMatchers.any;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;
import org.mockito.junit.jupiter.MockitoExtension;

import com.hango.hango_backend.dto.CommentDTO;
import com.hango.hango_backend.dto.CommentRequestDTO;
import com.hango.hango_backend.entity.Comment;
import com.hango.hango_backend.entity.Lesson;
import com.hango.hango_backend.entity.User;
import com.hango.hango_backend.repository.CommentRepository;
import com.hango.hango_backend.repository.LessonRepository;
import com.hango.hango_backend.repository.UserRepository;

@ExtendWith(MockitoExtension.class)
class CommentServiceImplTest {

    @Mock
    private CommentRepository commentRepository;
    @Mock
    private LessonRepository lessonRepository;
    @Mock
    private UserRepository userRepository;
    @Mock
    private CommentRuleEngineService ruleEngineService;

    @InjectMocks
    private CommentServiceImpl commentService;

    private User user(Long id, String fullName) {
        return User.builder().id(id).fullName(fullName).build();
    }

    private Comment comment(Long id, User author, String status) {
        return Comment.builder().id(id).user(author).content("hello").status(status).build();
    }

    private CommentModerationResult approved() {
        return new CommentModerationResult(CommentRuleEngineService.STATUS_APPROVED, "hello", null);
    }

    // =================================================================
    // getCommentsByLesson - visibility rules
    // =================================================================

    @Test
    void getCommentsByLessonShouldIncludeApprovedCommentForAnyViewer() {
        Comment approved = comment(1L, user(10L, "Alice"), "APPROVED");
        when(commentRepository.findByLessonIdOrderByCreatedAtDesc(1L)).thenReturn(List.of(approved));

        List<CommentDTO> result = commentService.getCommentsByLesson(1L, 99L);

        assertEquals(1, result.size());
        assertEquals("APPROVED", result.get(0).getStatus());
    }

    @Test
    void getCommentsByLessonShouldIncludeOwnPendingCommentForItsAuthor() {
        Comment pending = comment(1L, user(10L, "Alice"), "PENDING");
        when(commentRepository.findByLessonIdOrderByCreatedAtDesc(1L)).thenReturn(List.of(pending));

        List<CommentDTO> result = commentService.getCommentsByLesson(1L, 10L);

        assertEquals(1, result.size());
        assertEquals("PENDING", result.get(0).getStatus());
    }

    @Test
    void getCommentsByLessonShouldHidePendingCommentFromOtherUsers() {
        Comment pending = comment(1L, user(10L, "Alice"), "PENDING");
        when(commentRepository.findByLessonIdOrderByCreatedAtDesc(1L)).thenReturn(List.of(pending));

        List<CommentDTO> result = commentService.getCommentsByLesson(1L, 20L);

        assertTrue(result.isEmpty());
    }

    @Test
    void getCommentsByLessonShouldHideRejectedCommentEvenFromItsOwnAuthor() {
        Comment rejected = comment(1L, user(10L, "Alice"), "REJECTED");
        when(commentRepository.findByLessonIdOrderByCreatedAtDesc(1L)).thenReturn(List.of(rejected));

        List<CommentDTO> result = commentService.getCommentsByLesson(1L, 10L);

        assertTrue(result.isEmpty());
    }

    @Test
    void getCommentsByLessonShouldHidePendingAndRejectedFromAnonymousViewer() {
        Comment pending = comment(1L, user(10L, "Alice"), "PENDING");
        Comment rejected = comment(2L, user(10L, "Alice"), "REJECTED");
        when(commentRepository.findByLessonIdOrderByCreatedAtDesc(1L)).thenReturn(List.of(pending, rejected));

        List<CommentDTO> result = commentService.getCommentsByLesson(1L, null);

        assertTrue(result.isEmpty());
    }

    // =================================================================
    // addComment
    // =================================================================

    @Test
    void addCommentShouldThrowWhenLessonNotFound() {
        when(lessonRepository.findById(1L)).thenReturn(Optional.empty());

        assertThrows(RuntimeException.class,
                () -> commentService.addComment(1L, 10L, CommentRequestDTO.builder().content("hi").build()));
    }

    @Test
    void addCommentShouldThrowWhenUserNotFound() {
        when(lessonRepository.findById(1L)).thenReturn(Optional.of(Lesson.builder().id(1L).build()));
        when(userRepository.findById(10L)).thenReturn(Optional.empty());

        assertThrows(RuntimeException.class,
                () -> commentService.addComment(1L, 10L, CommentRequestDTO.builder().content("hi").build()));
    }

    @Test
    void addCommentShouldThrowWhenParentCommentNotFound() {
        when(lessonRepository.findById(1L)).thenReturn(Optional.of(Lesson.builder().id(1L).build()));
        when(userRepository.findById(10L)).thenReturn(Optional.of(user(10L, "Alice")));
        when(commentRepository.findById(99L)).thenReturn(Optional.empty());

        CommentRequestDTO request = CommentRequestDTO.builder().content("hi").parentCommentId(99L).build();

        assertThrows(RuntimeException.class, () -> commentService.addComment(1L, 10L, request));
    }

    @Test
    void addCommentShouldPersistStatusNormalizedContentAndDetectionReasonFromRuleEngine() {
        when(lessonRepository.findById(1L)).thenReturn(Optional.of(Lesson.builder().id(1L).build()));
        when(userRepository.findById(10L)).thenReturn(Optional.of(user(10L, "Alice")));
        when(ruleEngineService.evaluate("dit me may"))
                .thenReturn(new CommentModerationResult("REJECTED", "dit me may", "Blacklist keyword detected: \"dit me\""));
        when(commentRepository.save(any())).thenAnswer(invocation -> invocation.getArgument(0));

        CommentDTO result = commentService.addComment(1L, 10L,
                CommentRequestDTO.builder().content("dit me may").build());

        ArgumentCaptor<Comment> captor = ArgumentCaptor.forClass(Comment.class);
        verify(commentRepository).save(captor.capture());
        assertEquals("REJECTED", captor.getValue().getStatus());
        assertEquals("dit me may", captor.getValue().getNormalizedContent());
        assertEquals("Blacklist keyword detected: \"dit me\"", captor.getValue().getDetectionReason());
        assertEquals("REJECTED", result.getStatus());
    }

    @Test
    void addCommentShouldLinkParentCommentWhenReplying() {
        Comment parent = comment(5L, user(20L, "Bob"), "APPROVED");
        when(lessonRepository.findById(1L)).thenReturn(Optional.of(Lesson.builder().id(1L).build()));
        when(userRepository.findById(10L)).thenReturn(Optional.of(user(10L, "Alice")));
        when(commentRepository.findById(5L)).thenReturn(Optional.of(parent));
        when(ruleEngineService.evaluate(any())).thenReturn(approved());
        when(commentRepository.save(any())).thenAnswer(invocation -> invocation.getArgument(0));

        CommentDTO result = commentService.addComment(1L, 10L,
                CommentRequestDTO.builder().content("reply").parentCommentId(5L).build());

        ArgumentCaptor<Comment> captor = ArgumentCaptor.forClass(Comment.class);
        verify(commentRepository).save(captor.capture());
        assertEquals(5L, captor.getValue().getParentComment().getId());
        assertEquals(5L, result.getParentCommentId());
    }

    // =================================================================
    // updateComment
    // =================================================================

    @Test
    void updateCommentShouldThrowWhenCommentNotFound() {
        when(commentRepository.findById(1L)).thenReturn(Optional.empty());

        assertThrows(RuntimeException.class,
                () -> commentService.updateComment(1L, 10L, CommentRequestDTO.builder().content("edit").build()));
    }

    @Test
    void updateCommentShouldThrowWhenCallerIsNotTheAuthor() {
        Comment existing = comment(1L, user(10L, "Alice"), "APPROVED");
        when(commentRepository.findById(1L)).thenReturn(Optional.of(existing));

        assertThrows(RuntimeException.class,
                () -> commentService.updateComment(1L, 20L, CommentRequestDTO.builder().content("edit").build()));
        verify(commentRepository, never()).save(any());
    }

    @Test
    void updateCommentShouldReEvaluateRuleEngineAndCanFlipStatus() {
        Comment existing = comment(1L, user(10L, "Alice"), "APPROVED");
        when(commentRepository.findById(1L)).thenReturn(Optional.of(existing));
        when(ruleEngineService.evaluate("vcl qua"))
                .thenReturn(new CommentModerationResult("REJECTED", "vcl qua", "Blacklist keyword detected: \"vcl\""));
        when(commentRepository.save(any())).thenAnswer(invocation -> invocation.getArgument(0));

        CommentDTO result = commentService.updateComment(1L, 10L, CommentRequestDTO.builder().content("vcl qua").build());

        assertEquals("REJECTED", result.getStatus());
        assertEquals("vcl qua", existing.getContent());
        assertEquals("Blacklist keyword detected: \"vcl\"", existing.getDetectionReason());
    }

    // =================================================================
    // deleteComment
    // =================================================================

    @Test
    void deleteCommentShouldThrowWhenCommentNotFound() {
        when(commentRepository.findById(1L)).thenReturn(Optional.empty());

        assertThrows(RuntimeException.class, () -> commentService.deleteComment(1L, 10L));
    }

    @Test
    void deleteCommentShouldThrowWhenCallerIsNotTheAuthor() {
        Comment existing = comment(1L, user(10L, "Alice"), "APPROVED");
        when(commentRepository.findById(1L)).thenReturn(Optional.of(existing));

        assertThrows(RuntimeException.class, () -> commentService.deleteComment(1L, 20L));
        verify(commentRepository, never()).delete(any());
    }

    @Test
    void deleteCommentShouldDeleteWhenCallerIsTheAuthor() {
        Comment existing = comment(1L, user(10L, "Alice"), "APPROVED");
        when(commentRepository.findById(1L)).thenReturn(Optional.of(existing));

        commentService.deleteComment(1L, 10L);

        verify(commentRepository).delete(existing);
    }

    // =================================================================
    // likeComment / unlikeComment
    // =================================================================

    @Test
    void likeCommentShouldAddCurrentUserToLikedUsersAndReflectInDTO() {
        Comment existing = comment(1L, user(10L, "Alice"), "APPROVED");
        User liker = user(20L, "Bob");
        when(commentRepository.findById(1L)).thenReturn(Optional.of(existing));
        when(userRepository.findById(20L)).thenReturn(Optional.of(liker));
        when(commentRepository.save(any())).thenAnswer(invocation -> invocation.getArgument(0));

        CommentDTO result = commentService.likeComment(1L, 20L);

        assertEquals(1, result.getLikeCount());
        assertTrue(result.getIsLiked());
        assertTrue(existing.getLikedUsers().contains(liker));
    }

    @Test
    void unlikeCommentShouldRemoveCurrentUserFromLikedUsers() {
        User liker = user(20L, "Bob");
        Comment existing = comment(1L, user(10L, "Alice"), "APPROVED");
        existing.setLikedUsers(new java.util.HashSet<>(Set.of(liker)));
        when(commentRepository.findById(1L)).thenReturn(Optional.of(existing));
        when(userRepository.findById(20L)).thenReturn(Optional.of(liker));
        when(commentRepository.save(any())).thenAnswer(invocation -> invocation.getArgument(0));

        CommentDTO result = commentService.unlikeComment(1L, 20L);

        assertEquals(0, result.getLikeCount());
        assertFalse(result.getIsLiked());
        assertTrue(existing.getLikedUsers().isEmpty());
    }

    // =================================================================
    // convertToDTO mapping (via getCommentsByLesson)
    // =================================================================

    @Test
    void convertToDTOShouldMapParentCommentIdForAReplyAndNullForARootComment() {
        Comment parent = comment(1L, user(10L, "Alice"), "APPROVED");
        Comment reply = Comment.builder().id(2L).user(user(20L, "Bob")).content("reply").status("APPROVED")
                .parentComment(parent).build();
        when(commentRepository.findByLessonIdOrderByCreatedAtDesc(1L)).thenReturn(List.of(parent, reply));

        List<CommentDTO> result = commentService.getCommentsByLesson(1L, null);

        CommentDTO rootDto = result.stream().filter(c -> c.getId().equals(1L)).findFirst().orElseThrow();
        CommentDTO replyDto = result.stream().filter(c -> c.getId().equals(2L)).findFirst().orElseThrow();
        assertNull(rootDto.getParentCommentId());
        assertEquals(1L, replyDto.getParentCommentId());
    }
}
