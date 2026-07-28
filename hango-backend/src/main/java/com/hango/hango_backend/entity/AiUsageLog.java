package com.hango.hango_backend.entity;

import jakarta.persistence.*;
import lombok.*;

import org.hibernate.annotations.CreationTimestamp;
import java.time.LocalDateTime;

@Entity
@Table(name = "ai_usage_logs")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class AiUsageLog {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    /** "CHAT" (generateChatResponse) or "EMBEDDING" (generateEmbedding) - the two real Gemini call sites. */
    @Column(name = "call_type", nullable = false, length = 20)
    private String callType;

    @Column(nullable = false)
    private boolean success;

    @Column(name = "duration_ms")
    private Long durationMs;

    @Column(name = "error_message", length = 255)
    private String errorMessage;

    @CreationTimestamp
    @Column(name = "created_at", updatable = false)
    private LocalDateTime createdAt;
}
