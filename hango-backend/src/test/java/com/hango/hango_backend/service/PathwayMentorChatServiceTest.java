package com.hango.hango_backend.service;

import com.hango.hango_backend.dto.PathwayChatRequestDTO;
import com.hango.hango_backend.dto.PathwayChatResponseDTO;
import com.hango.hango_backend.entity.Course;
import com.hango.hango_backend.entity.LearningPathway;
import com.hango.hango_backend.entity.PathwayConversation;
import com.hango.hango_backend.entity.PathwayMessage;
import com.hango.hango_backend.entity.PathwayNode;
import com.hango.hango_backend.entity.User;
import com.hango.hango_backend.exception.ApiException;
import com.hango.hango_backend.repository.CourseRepository;
import com.hango.hango_backend.repository.ExamAttemptRepository;
import com.hango.hango_backend.repository.LearningPathwayRepository;
import com.hango.hango_backend.repository.LessonProgressRepository;
import com.hango.hango_backend.repository.LessonRepository;
import com.hango.hango_backend.repository.PathwayConversationRepository;
import com.hango.hango_backend.repository.UserRepository;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.http.HttpStatus;

import java.util.List;
import java.util.Optional;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.times;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class PathwayMentorChatServiceTest {

    @Mock
    private PathwayConversationRepository conversationRepository;

    @Mock
    private LearningPathwayRepository pathwayRepository;

    @Mock
    private UserRepository userRepository;

    @Mock
    private GeminiClientService geminiClientService;

    @Mock
    private ExamResultAnalyzerService examResultAnalyzerService;

    @Mock
    private ExamAttemptRepository examAttemptRepository;

    @Mock
    private LessonRepository lessonRepository;

    @Mock
    private LessonProgressRepository lessonProgressRepository;

    @Mock
    private CourseRepository courseRepository;

    @InjectMocks
    private PathwayMentorChatService chatService;

    // =================================================================
    // chat
    // =================================================================

    @Test
    void chatShouldUsePathwayContextAndPersistMessages() {
        LearningPathway pathway = pathway();
        when(pathwayRepository.findById(10L)).thenReturn(Optional.of(pathway));
        when(userRepository.findById(1L)).thenReturn(Optional.of(pathway.getStudent()));
        when(conversationRepository.findFirstByLearnerIdAndPathwayIdOrderByStartedAtDesc(1L, 10L))
                .thenReturn(Optional.empty());
        when(conversationRepository.save(any(PathwayConversation.class))).thenAnswer(invocation -> {
            PathwayConversation conversation = invocation.getArgument(0);
            if (conversation.getId() == null) {
                conversation.setId(99L);
            }
            return conversation;
        });
        when(examAttemptRepository.findTop10ByStudent_IdOrderBySubmittedAtDesc(1L)).thenReturn(List.of());
        when(lessonRepository.countByCourseId(7L)).thenReturn(4L);
        when(lessonProgressRepository.countCompletedLessonsByUserIdAndCourseId(1L, 7L)).thenReturn(1L);
        when(geminiClientService.generateChatResponse(anyString(), any()))
                .thenReturn("Start with Grammar because it fixes your weakest foundation.")
                .thenReturn("{\"suggestedQuestions\":[\"Why this course first?\",\"What should I do today?\",\"How much time should I study?\"]}");

        PathwayChatRequestDTO request = new PathwayChatRequestDTO();
        request.setMessage("Why should I learn grammar first?");
        request.setSelectedNodeCourseId(7L);

        PathwayChatResponseDTO response = chatService.chat(10L, 1L, request);

        assertEquals(99L, response.getConversationId());
        assertFalse(response.isWasOutOfScope());
        assertEquals("Start with Grammar because it fixes your weakest foundation.", response.getReply());
        assertEquals(3, response.getSuggestedQuestions().size());

        ArgumentCaptor<PathwayConversation> conversationCaptor = ArgumentCaptor.forClass(PathwayConversation.class);
        verify(conversationRepository, times(2)).save(conversationCaptor.capture());
        PathwayConversation savedConversation = conversationCaptor.getAllValues()
                .get(conversationCaptor.getAllValues().size() - 1);
        assertEquals(2, savedConversation.getMessages().size());
        assertEquals(PathwayMessage.MessageRole.USER, savedConversation.getMessages().get(0).getRole());
        assertEquals(PathwayMessage.MessageRole.ASSISTANT, savedConversation.getMessages().get(1).getRole());
    }

    @Test
    void chatShouldBlockClearlyOutOfScopeMessagesBeforeCallingGemini() {
        LearningPathway pathway = pathway();
        when(pathwayRepository.findById(10L)).thenReturn(Optional.of(pathway));
        when(userRepository.findById(1L)).thenReturn(Optional.of(pathway.getStudent()));
        when(conversationRepository.findFirstByLearnerIdAndPathwayIdOrderByStartedAtDesc(1L, 10L))
                .thenReturn(Optional.empty());
        when(conversationRepository.save(any(PathwayConversation.class))).thenAnswer(invocation -> {
            PathwayConversation conversation = invocation.getArgument(0);
            conversation.setId(99L);
            return conversation;
        });
        when(examAttemptRepository.findTop10ByStudent_IdOrderBySubmittedAtDesc(1L)).thenReturn(List.of());
        when(lessonRepository.countByCourseId(7L)).thenReturn(4L);
        when(lessonProgressRepository.countCompletedLessonsByUserIdAndCourseId(1L, 7L)).thenReturn(1L);

        PathwayChatRequestDTO request = new PathwayChatRequestDTO();
        request.setMessage("Should I buy bitcoin today?");

        PathwayChatResponseDTO response = chatService.chat(10L, 1L, request);

        assertTrue(response.isWasOutOfScope());
        assertTrue(response.getSuggestedQuestions().isEmpty());
        assertTrue(response.getReply().contains("HanGo"));
        verify(geminiClientService, never()).generateChatResponse(anyString(), any());
    }

    @Test
    void chatShouldRejectOtherLearnersPathway() {
        LearningPathway pathway = pathway();
        pathway.setStudent(User.builder().id(2L).build());
        when(pathwayRepository.findById(10L)).thenReturn(Optional.of(pathway));

        PathwayChatRequestDTO request = new PathwayChatRequestDTO();
        request.setMessage("What should I study next?");

        ApiException exception = assertThrows(ApiException.class, () -> chatService.chat(10L, 1L, request));

        assertEquals(HttpStatus.FORBIDDEN, exception.getStatus());
        verify(geminiClientService, never()).generateChatResponse(anyString(), any());
    }

    @Test
    void chatShouldThrowWhenLearnerIdIsNull() {
        PathwayChatRequestDTO request = new PathwayChatRequestDTO();
        request.setMessage("What should I study next?");

        ApiException exception = assertThrows(ApiException.class, () -> chatService.chat(10L, null, request));

        assertEquals(HttpStatus.UNAUTHORIZED, exception.getStatus());
        verify(pathwayRepository, never()).findById(any());
    }

    @Test
    void chatShouldThrowWhenPathwayNotFound() {
        when(pathwayRepository.findById(10L)).thenReturn(Optional.empty());

        PathwayChatRequestDTO request = new PathwayChatRequestDTO();
        request.setMessage("What should I study next?");

        ApiException exception = assertThrows(ApiException.class, () -> chatService.chat(10L, 1L, request));

        assertEquals(HttpStatus.NOT_FOUND, exception.getStatus());
    }

    @Test
    void chatShouldThrowWhenUserNotFound() {
        LearningPathway pathway = pathway();
        when(pathwayRepository.findById(10L)).thenReturn(Optional.of(pathway));
        when(userRepository.findById(1L)).thenReturn(Optional.empty());

        PathwayChatRequestDTO request = new PathwayChatRequestDTO();
        request.setMessage("What should I study next?");

        ApiException exception = assertThrows(ApiException.class, () -> chatService.chat(10L, 1L, request));

        assertEquals(HttpStatus.NOT_FOUND, exception.getStatus());
        assertEquals("User not found", exception.getMessage());
    }

    @Test
    void chatShouldFallBackToApologyMessageWhenGeminiThrows() {
        LearningPathway pathway = pathway();
        when(pathwayRepository.findById(10L)).thenReturn(Optional.of(pathway));
        when(userRepository.findById(1L)).thenReturn(Optional.of(pathway.getStudent()));
        when(conversationRepository.findFirstByLearnerIdAndPathwayIdOrderByStartedAtDesc(1L, 10L))
                .thenReturn(Optional.empty());
        when(conversationRepository.save(any(PathwayConversation.class))).thenAnswer(invocation -> {
            PathwayConversation conversation = invocation.getArgument(0);
            if (conversation.getId() == null) {
                conversation.setId(99L);
            }
            return conversation;
        });
        when(examAttemptRepository.findTop10ByStudent_IdOrderBySubmittedAtDesc(1L)).thenReturn(List.of());
        when(lessonRepository.countByCourseId(7L)).thenReturn(4L);
        when(lessonProgressRepository.countCompletedLessonsByUserIdAndCourseId(1L, 7L)).thenReturn(1L);
        when(geminiClientService.generateChatResponse(anyString(), any())).thenThrow(new RuntimeException("Gemini down"));

        PathwayChatRequestDTO request = new PathwayChatRequestDTO();
        request.setMessage("Why should I learn grammar first?");

        PathwayChatResponseDTO response = chatService.chat(10L, 1L, request);

        assertEquals("Xin lỗi, tôi đang gặp sự cố kỹ thuật. Vui lòng thử lại sau giây lát.", response.getReply());
        assertFalse(response.isWasOutOfScope());
    }

    @Test
    void chatShouldReuseConversationWhenConversationIdProvided() {
        LearningPathway pathway = pathway();
        PathwayConversation existingConversation = PathwayConversation.builder()
                .id(55L)
                .learner(pathway.getStudent())
                .pathway(pathway)
                .messages(new java.util.ArrayList<>())
                .build();
        when(pathwayRepository.findById(10L)).thenReturn(Optional.of(pathway));
        when(userRepository.findById(1L)).thenReturn(Optional.of(pathway.getStudent()));
        when(conversationRepository.findByIdAndLearnerIdWithMessages(55L, 1L)).thenReturn(Optional.of(existingConversation));
        when(conversationRepository.save(any(PathwayConversation.class))).thenAnswer(invocation -> invocation.getArgument(0));
        when(examAttemptRepository.findTop10ByStudent_IdOrderBySubmittedAtDesc(1L)).thenReturn(List.of());
        when(lessonRepository.countByCourseId(7L)).thenReturn(4L);
        when(lessonProgressRepository.countCompletedLessonsByUserIdAndCourseId(1L, 7L)).thenReturn(1L);
        when(geminiClientService.generateChatResponse(anyString(), any()))
                .thenReturn("Keep going with Grammar.")
                .thenReturn("{\"suggestedQuestions\":[]}");

        PathwayChatRequestDTO request = new PathwayChatRequestDTO();
        request.setMessage("How am I doing?");
        request.setConversationId(55L);

        PathwayChatResponseDTO response = chatService.chat(10L, 1L, request);

        assertEquals(55L, response.getConversationId());
        verify(conversationRepository, times(1)).save(any(PathwayConversation.class));
        verify(conversationRepository, never()).findFirstByLearnerIdAndPathwayIdOrderByStartedAtDesc(any(), any());
        assertEquals(2, existingConversation.getMessages().size());
    }

    @Test
    void chatShouldMarkOutOfScopeWhenAiReplyMentionsOutOfScopePhrase() {
        LearningPathway pathway = pathway();
        when(pathwayRepository.findById(10L)).thenReturn(Optional.of(pathway));
        when(userRepository.findById(1L)).thenReturn(Optional.of(pathway.getStudent()));
        when(conversationRepository.findFirstByLearnerIdAndPathwayIdOrderByStartedAtDesc(1L, 10L))
                .thenReturn(Optional.empty());
        when(conversationRepository.save(any(PathwayConversation.class))).thenAnswer(invocation -> {
            PathwayConversation conversation = invocation.getArgument(0);
            if (conversation.getId() == null) {
                conversation.setId(99L);
            }
            return conversation;
        });
        when(examAttemptRepository.findTop10ByStudent_IdOrderBySubmittedAtDesc(1L)).thenReturn(List.of());
        when(lessonRepository.countByCourseId(7L)).thenReturn(4L);
        when(lessonProgressRepository.countCompletedLessonsByUserIdAndCourseId(1L, 7L)).thenReturn(1L);
        when(geminiClientService.generateChatResponse(anyString(), any()))
                .thenReturn("That request is out of scope for a pathway mentor.");

        PathwayChatRequestDTO request = new PathwayChatRequestDTO();
        request.setMessage("Can you help me plan my study schedule?");

        PathwayChatResponseDTO response = chatService.chat(10L, 1L, request);

        assertTrue(response.isWasOutOfScope());
        assertTrue(response.getSuggestedQuestions().isEmpty());
    }

    // =================================================================
    // getChatHistory
    // =================================================================

    @Test
    void getChatHistoryShouldThrowWhenPathwayNotFound() {
        when(pathwayRepository.findById(10L)).thenReturn(Optional.empty());

        ApiException exception = assertThrows(ApiException.class, () -> chatService.getChatHistory(10L, 1L));

        assertEquals(HttpStatus.NOT_FOUND, exception.getStatus());
    }

    @Test
    void getChatHistoryShouldRejectOtherLearnersPathway() {
        LearningPathway pathway = pathway();
        pathway.setStudent(User.builder().id(2L).build());
        when(pathwayRepository.findById(10L)).thenReturn(Optional.of(pathway));

        ApiException exception = assertThrows(ApiException.class, () -> chatService.getChatHistory(10L, 1L));

        assertEquals(HttpStatus.FORBIDDEN, exception.getStatus());
    }

    @Test
    void getChatHistoryShouldMapConversationsAndMessages() {
        LearningPathway pathway = pathway();
        PathwayMessage userMessage = PathwayMessage.builder()
                .role(PathwayMessage.MessageRole.USER)
                .content("Why grammar first?")
                .wasOutOfScope(false)
                .build();
        PathwayMessage assistantMessage = PathwayMessage.builder()
                .role(PathwayMessage.MessageRole.ASSISTANT)
                .content("Because your grammar accuracy is low.")
                .wasOutOfScope(false)
                .build();
        PathwayConversation conversation = PathwayConversation.builder()
                .id(55L)
                .messages(List.of(userMessage, assistantMessage))
                .build();
        when(pathwayRepository.findById(10L)).thenReturn(Optional.of(pathway));
        when(conversationRepository.findByLearnerIdAndPathwayIdOrderByStartedAtDesc(1L, 10L))
                .thenReturn(List.of(conversation));

        List<PathwayChatResponseDTO> history = chatService.getChatHistory(10L, 1L);

        assertEquals(2, history.size());
        assertEquals("USER", history.get(0).getRole());
        assertEquals("Why grammar first?", history.get(0).getReply());
        assertEquals("ASSISTANT", history.get(1).getRole());
    }

    // =================================================================
    // clearChatHistory
    // =================================================================

    @Test
    void clearChatHistoryShouldThrowWhenPathwayNotFound() {
        when(pathwayRepository.findById(10L)).thenReturn(Optional.empty());

        ApiException exception = assertThrows(ApiException.class, () -> chatService.clearChatHistory(10L, 1L));

        assertEquals(HttpStatus.NOT_FOUND, exception.getStatus());
    }

    @Test
    void clearChatHistoryShouldRejectOtherLearnersPathway() {
        LearningPathway pathway = pathway();
        pathway.setStudent(User.builder().id(2L).build());
        when(pathwayRepository.findById(10L)).thenReturn(Optional.of(pathway));

        ApiException exception = assertThrows(ApiException.class, () -> chatService.clearChatHistory(10L, 1L));

        assertEquals(HttpStatus.FORBIDDEN, exception.getStatus());
    }

    @Test
    void clearChatHistoryShouldDeleteAllConversations() {
        LearningPathway pathway = pathway();
        PathwayConversation conversation = PathwayConversation.builder().id(55L).build();
        when(pathwayRepository.findById(10L)).thenReturn(Optional.of(pathway));
        when(conversationRepository.findByLearnerIdAndPathwayIdOrderByStartedAtDesc(1L, 10L))
                .thenReturn(List.of(conversation));

        chatService.clearChatHistory(10L, 1L);

        verify(conversationRepository).deleteAll(List.of(conversation));
    }

    private LearningPathway pathway() {
        User learner = User.builder().id(1L).build();
        Course course = Course.builder()
                .id(7L)
                .title("Grammar Basics")
                .description("Foundational grammar course")
                .build();
        LearningPathway pathway = LearningPathway.builder()
                .id(10L)
                .student(learner)
                .goalName("Reach 8 points in the THPT English exam")
                .status("ACTIVE")
                .build();
        pathway.addNode(PathwayNode.builder()
                .stepOrder(1)
                .course(course)
                .status("IN_PROGRESS")
                .reasonWhy("Your grammar accuracy is low.")
                .build());
        return pathway;
    }
}
