package com.hango.hango_backend.service;

import com.hango.hango_backend.entity.Course;
import com.hango.hango_backend.entity.Notification;
import com.hango.hango_backend.repository.NotificationRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;

/**
 * Minimal notification store - no realtime/WebSocket delivery yet (see doc/HanGo_Documentation.md
 * FE-14, still Planned). Course Manager reads these via a simple list/mark-as-read API.
 */
@Service
@RequiredArgsConstructor
public class NotificationService {

    public static final String RECIPIENT_COURSE_MANAGER = "TRAINER_LEAD";

    public static final String TYPE_LOW_RATING = "LOW_RATING";
    public static final String TYPE_LOW_AVERAGE_RATING = "LOW_AVERAGE_RATING";

    private final NotificationRepository notificationRepository;

    public void notifyCourseManagers(String type, String title, String message, Course course) {
        Notification notification = Notification.builder()
                .recipientRole(RECIPIENT_COURSE_MANAGER)
                .type(type)
                .title(title)
                .message(message)
                .course(course)
                .build();
        notificationRepository.save(notification);
    }
}
