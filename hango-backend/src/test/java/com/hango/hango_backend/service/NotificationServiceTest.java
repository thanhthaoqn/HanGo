package com.hango.hango_backend.service;

import static org.junit.jupiter.api.Assertions.assertEquals;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import static org.mockito.Mockito.verify;
import org.mockito.junit.jupiter.MockitoExtension;

import com.hango.hango_backend.entity.Course;
import com.hango.hango_backend.entity.Notification;
import com.hango.hango_backend.repository.NotificationRepository;

@ExtendWith(MockitoExtension.class)
class NotificationServiceTest {

    @Mock
    private NotificationRepository notificationRepository;

    @InjectMocks
    private NotificationService notificationService;

    @Test
    void notifyCourseManagersShouldSaveNotificationAddressedToTheCourseManagerRole() {
        Course course = Course.builder().id(1L).title("English Grammar Mastery").build();

        notificationService.notifyCourseManagers(NotificationService.TYPE_LOW_RATING,
                "Low Course Rating Detected", "Course: English Grammar Mastery\nLearner Rating: 2 Stars", course);

        ArgumentCaptor<Notification> captor = ArgumentCaptor.forClass(Notification.class);
        verify(notificationRepository).save(captor.capture());
        assertEquals(NotificationService.RECIPIENT_COURSE_MANAGER, captor.getValue().getRecipientRole());
        assertEquals(NotificationService.TYPE_LOW_RATING, captor.getValue().getType());
        assertEquals("Low Course Rating Detected", captor.getValue().getTitle());
        assertEquals(course, captor.getValue().getCourse());
        assertEquals(false, captor.getValue().isRead());
    }
}
