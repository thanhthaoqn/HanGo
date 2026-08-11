package com.hango.hango_backend.service;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageImpl;
import org.springframework.data.domain.PageRequest;

import com.hango.hango_backend.dto.NotificationDTO;
import com.hango.hango_backend.entity.Course;
import com.hango.hango_backend.entity.Notification;
import com.hango.hango_backend.entity.User;
import com.hango.hango_backend.repository.NotificationRepository;
import com.hango.hango_backend.repository.UserRepository;

import java.util.List;
import java.util.Optional;

@ExtendWith(MockitoExtension.class)
class NotificationServiceTest {

    @Mock
    private NotificationRepository notificationRepository;
    @Mock
    private UserRepository userRepository;

    @InjectMocks
    private NotificationService notificationService;

    private User user(Long id) {
        return User.builder().id(id).fullName("User " + id).build();
    }

    // =================================================================
    // notifyCourseManagers
    // =================================================================

    @Test
    void notifyCourseManagersShouldSaveNotificationAddressedToTheCourseManagerRole() {
        Course course = Course.builder().id(1L).title("English Grammar Mastery").build();
        User manager = user(2L);
        when(userRepository.findByRoleNames(List.of("COURSE_MANAGER", "COURSE_MANAGER", "ADMINISTRATOR")))
                .thenReturn(List.of(manager));

        notificationService.notifyCourseManagers(NotificationService.TYPE_LOW_RATING,
                "Low Course Rating Detected", "Course: English Grammar Mastery\nLearner Rating: 2 Stars", course);

        ArgumentCaptor<Notification> captor = ArgumentCaptor.forClass(Notification.class);
        verify(notificationRepository).save(captor.capture());
        assertEquals(manager, captor.getValue().getUser());
        assertEquals(NotificationService.RECIPIENT_COURSE_MANAGER, captor.getValue().getRecipientRole());
        assertEquals(NotificationService.TYPE_LOW_RATING, captor.getValue().getType());
        assertEquals("Low Course Rating Detected", captor.getValue().getTitle());
        assertEquals(course, captor.getValue().getCourse());
        assertEquals(false, captor.getValue().isRead());
    }

    // =================================================================
    // notifyUser
    // =================================================================

    @Test
    void notifyUserShouldSaveNotificationTargetedAtTheGivenUser() {
        User recipient = user(5L);
        Course course = Course.builder().id(1L).title("Course A").build();

        notificationService.notifyUser(recipient, NotificationService.TYPE_PURCHASE_SUCCESS,
                "Payment successful", "Your payment was successful", course);

        ArgumentCaptor<Notification> captor = ArgumentCaptor.forClass(Notification.class);
        verify(notificationRepository).saveAndFlush(captor.capture());
        assertEquals(recipient, captor.getValue().getUser());
        assertEquals(NotificationService.TYPE_PURCHASE_SUCCESS, captor.getValue().getType());
        assertEquals(course, captor.getValue().getCourse());
    }

    @Test
    void notifyUserShouldDoNothingWhenUserIsNull() {
        notificationService.notifyUser(null, NotificationService.TYPE_NEW_ENROLLMENT, "title", "message", null);

        verify(notificationRepository, never()).saveAndFlush(any());
    }

    // =================================================================
    // getNotificationsForUser
    // =================================================================

    @Test
    void getNotificationsForUserShouldMapEntitiesToDTOs() {
        Course course = Course.builder().id(1L).title("Course A").build();
        Notification n = Notification.builder().id(10L).user(user(5L)).type(NotificationService.TYPE_PURCHASE_SUCCESS)
                .title("Payment successful").message("msg").course(course).read(false).build();
        Page<Notification> page = new PageImpl<>(List.of(n), PageRequest.of(0, 20), 1);
        when(notificationRepository.findVisibleToUser(eq(5L), eq(List.of("LEARNER")), any())).thenReturn(page);

        Page<NotificationDTO> result = notificationService.getNotificationsForUser(5L, List.of("LEARNER"), 0, 20);

        assertEquals(1, result.getTotalElements());
        NotificationDTO dto = result.getContent().get(0);
        assertEquals(10L, dto.getId());
        assertEquals("Payment successful", dto.getTitle());
        assertEquals(1L, dto.getCourseId());
        assertEquals("Course A", dto.getCourseTitle());
        assertFalse(dto.isRead());
    }

    @Test
    void getNotificationsForUserShouldMapCourseFieldsToNullWhenNotificationHasNoCourse() {
        Notification n = Notification.builder().id(11L).user(user(5L)).type(NotificationService.TYPE_STATEMENT_READY)
                .title("Monthly statement ready").message("msg").read(true).build();
        Page<Notification> page = new PageImpl<>(List.of(n), PageRequest.of(0, 20), 1);
        when(notificationRepository.findVisibleToUser(eq(5L), eq(List.of("LEARNER")), any())).thenReturn(page);

        Page<NotificationDTO> result = notificationService.getNotificationsForUser(5L, List.of("LEARNER"), 0, 20);

        NotificationDTO dto = result.getContent().get(0);
        assertNull(dto.getCourseId());
        assertNull(dto.getCourseTitle());
        assertTrue(dto.isRead());
    }

    // =================================================================
    // getUnreadCount
    // =================================================================

    @Test
    void getUnreadCountShouldDelegateToRepository() {
        when(notificationRepository.countUnreadVisibleToUser(5L, List.of("LEARNER"))).thenReturn(3L);

        long count = notificationService.getUnreadCount(5L, List.of("LEARNER"));

        assertEquals(3L, count);
    }

    // =================================================================
    // markAsRead
    // =================================================================

    @Test
    void markAsReadShouldThrowWhenNotificationNotFound() {
        when(notificationRepository.findById(99L)).thenReturn(Optional.empty());

        assertThrows(RuntimeException.class, () -> notificationService.markAsRead(99L, 5L, List.of("LEARNER")));
    }

    @Test
    void markAsReadShouldSetReadTrueWhenOwnedByTargetUser() {
        Notification n = Notification.builder().id(1L).user(user(5L)).read(false).build();
        when(notificationRepository.findById(1L)).thenReturn(Optional.of(n));

        notificationService.markAsRead(1L, 5L, List.of("LEARNER"));

        assertTrue(n.isRead());
        verify(notificationRepository).save(n);
    }

    @Test
    void markAsReadShouldSetReadTrueWhenBroadcastToOneOfCallersRoles() {
        Notification n = Notification.builder().id(1L).recipientRole("TRAINER_LEAD").read(false).build();
        when(notificationRepository.findById(1L)).thenReturn(Optional.of(n));

        notificationService.markAsRead(1L, 7L, List.of("TRAINER_LEAD"));

        assertTrue(n.isRead());
        verify(notificationRepository).save(n);
    }

    @Test
    void markAsReadShouldThrowWhenCallerDoesNotOwnTheNotification() {
        Notification n = Notification.builder().id(1L).user(user(5L)).read(false).build();
        when(notificationRepository.findById(1L)).thenReturn(Optional.of(n));

        assertThrows(RuntimeException.class, () -> notificationService.markAsRead(1L, 999L, List.of("LEARNER")));
        verify(notificationRepository, never()).save(any());
    }

    @Test
    void markAsReadShouldThrowWhenBroadcastRoleDoesNotMatchCallersRoles() {
        Notification n = Notification.builder().id(1L).recipientRole("TRAINER_LEAD").read(false).build();
        when(notificationRepository.findById(1L)).thenReturn(Optional.of(n));

        assertThrows(RuntimeException.class, () -> notificationService.markAsRead(1L, 7L, List.of("LEARNER")));
        verify(notificationRepository, never()).save(any());
    }

    // =================================================================
    // markAllAsRead
    // =================================================================

    @Test
    void markAllAsReadShouldDelegateToRepositoryAndReturnUpdatedCount() {
        when(notificationRepository.markAllAsReadForUser(5L, List.of("LEARNER"))).thenReturn(4);

        int updated = notificationService.markAllAsRead(5L, List.of("LEARNER"));

        assertEquals(4, updated);
    }
}
