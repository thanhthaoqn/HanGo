package com.hango.hango_backend.entity;

import jakarta.persistence.*;
import lombok.*;
import org.hibernate.annotations.DynamicUpdate;

import java.time.LocalDateTime;

@Entity
@Table(
        name = "certificates",
        uniqueConstraints = {
                @UniqueConstraint(name = "uk_certificates_user_course", columnNames = {"user_id", "course_id"}),
                @UniqueConstraint(name = "uk_certificates_credential_id", columnNames = {"credential_id"})
        }
)
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
@DynamicUpdate
public class Certificate {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "user_id", nullable = false)
    private User user;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "course_id", nullable = false)
    private Course course;

    @Column(name = "credential_id", nullable = false, length = 50)
    private String credentialId;

    @Column(name = "issued_at", nullable = false)
    private LocalDateTime issuedAt;
}
