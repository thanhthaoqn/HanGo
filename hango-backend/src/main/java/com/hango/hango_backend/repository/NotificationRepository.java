package com.hango.hango_backend.repository;

import com.hango.hango_backend.entity.Notification;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.util.Collection;
import java.util.List;

@Repository
public interface NotificationRepository extends JpaRepository<Notification, Long> {
    List<Notification> findByRecipientRoleOrderByCreatedAtDesc(String recipientRole);

    @Query("SELECT n FROM Notification n WHERE n.user.id = :userId "
            + "OR (n.user IS NULL AND n.recipientRole IN :roles) ORDER BY n.createdAt DESC")
    Page<Notification> findVisibleToUser(@Param("userId") Long userId, @Param("roles") Collection<String> roles, Pageable pageable);

    @Query("SELECT COUNT(n) FROM Notification n WHERE (n.user.id = :userId "
            + "OR (n.user IS NULL AND n.recipientRole IN :roles)) AND n.read = false")
    long countUnreadVisibleToUser(@Param("userId") Long userId, @Param("roles") Collection<String> roles);

    @Modifying
    @Query("UPDATE Notification n SET n.read = true WHERE (n.user.id = :userId "
            + "OR (n.user IS NULL AND n.recipientRole IN :roles)) AND n.read = false")
    int markAllAsReadForUser(@Param("userId") Long userId, @Param("roles") Collection<String> roles);
}
