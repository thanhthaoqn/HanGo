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
