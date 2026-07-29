package com.hango.hango_backend.service;

import com.hango.hango_backend.dto.NotificationDTO;
import com.hango.hango_backend.entity.Course;
import com.hango.hango_backend.entity.Notification;
import com.hango.hango_backend.entity.User;
import com.hango.hango_backend.repository.NotificationRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.Collection;

/**
 * Notification store - no realtime/WebSocket delivery yet (see doc/specs/14-notification.md).
 * A notification is either targeted at one user ({@link Notification#getUser()} set) or broadcast
 * to every user holding a given role ({@link Notification#getRecipientRole()} set, user null).
 */
@Service
@RequiredArgsConstructor
public class NotificationService {

    public static final String RECIPIENT_COURSE_MANAGER = "TRAINER_LEAD";
    public static final String RECIPIENT_ADMIN = "ADMINISTRATOR";

    public static final String TYPE_LOW_RATING = "LOW_RATING";
    public static final String TYPE_LOW_AVERAGE_RATING = "LOW_AVERAGE_RATING";
    public static final String TYPE_PURCHASE_SUCCESS = "PurchaseSuccess";
    public static final String TYPE_NEW_ENROLLMENT = "NewEnrollment";
    public static final String TYPE_COMMENT_REPLY = "CommentReply";
    public static final String TYPE_CONTENT_APPROVED = "ContentApproved";
    public static final String TYPE_CONTENT_REJECTED = "ContentRejected";
    public static final String TYPE_STATEMENT_READY = "StatementReady";
    public static final String TYPE_COURSE_UPDATED = "CourseUpdated";
    public static final String TYPE_COURSE_SUBMITTED = "CourseSubmitted";
    public static final String TYPE_TRAINER_APPLICATION_SUBMITTED = "TrainerApplicationSubmitted";
    public static final String TYPE_TRAINER_APPLICATION_REVIEWED = "TrainerApplicationReviewed";

    private final NotificationRepository notificationRepository;

    public void notifyCourseManagers(String type, String title, String message, Course course) {
        notifyRole(RECIPIENT_COURSE_MANAGER, type, title, message, course);
    }

    public void notifyRole(String role, String type, String title, String message, Course course) {
        Notification notification = Notification.builder()
                .recipientRole(role)
                .type(type)
                .title(title)
                .message(message)
                .course(course)
                .build();
        notificationRepository.save(notification);
    }

    public void notifyUser(User user, String type, String title, String message, Course course) {
        if (user == null) {
            return;
        }
        Notification notification = Notification.builder()
                .user(user)
                .type(type)
                .title(title)
                .message(message)
                .course(course)
                .build();
        notificationRepository.save(notification);
    }

    @Transactional(readOnly = true)
    public Page<NotificationDTO> getNotificationsForUser(Long userId, Collection<String> roles, int page, int size) {
        Page<Notification> notifications = notificationRepository.findVisibleToUser(
                userId, roles, PageRequest.of(page, size));
        return notifications.map(this::toDTO);
    }

    @Transactional(readOnly = true)
    public long getUnreadCount(Long userId, Collection<String> roles) {
        return notificationRepository.countUnreadVisibleToUser(userId, roles);
    }

    @Transactional
    public void markAsRead(Long notificationId, Long userId, Collection<String> roles) {
        Notification notification = notificationRepository.findById(notificationId)
                .orElseThrow(() -> new RuntimeException("Notification not found"));

        boolean owned = (notification.getUser() != null && notification.getUser().getId().equals(userId))
                || (notification.getUser() == null && notification.getRecipientRole() != null
                        && roles.contains(notification.getRecipientRole()));
        if (!owned) {
            throw new RuntimeException("You are not allowed to modify this notification");
        }

        notification.setRead(true);
        notificationRepository.save(notification);
    }

    @Transactional
    public int markAllAsRead(Long userId, Collection<String> roles) {
        return notificationRepository.markAllAsReadForUser(userId, roles);
    }

    private NotificationDTO toDTO(Notification n) {
        return NotificationDTO.builder()
                .id(n.getId())
                .type(n.getType())
                .title(n.getTitle())
                .message(n.getMessage())
                .courseId(n.getCourse() != null ? n.getCourse().getId() : null)
                .courseTitle(n.getCourse() != null ? n.getCourse().getTitle() : null)
                .read(n.isRead())
                .createdAt(n.getCreatedAt())
                .build();
    }
}
