package com.hango.hango_backend.repository;

import com.hango.hango_backend.entity.Notification;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;

@Repository
public interface NotificationRepository extends JpaRepository<Notification, Long> {
    List<Notification> findByRecipientRoleOrderByCreatedAtDesc(String recipientRole);
}
