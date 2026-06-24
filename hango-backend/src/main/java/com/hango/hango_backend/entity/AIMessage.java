package com.hango.hango_backend.entity;

import com.fasterxml.jackson.annotation.JsonIgnore;
import jakarta.persistence.*;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

import java.time.LocalDateTime;

@Entity
@Table(name = "ai_messages")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class AIMessage {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @JsonIgnore
    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "conversation_id", nullable = false)
    private AIConversation conversation;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 10)
    private MessageRole role; // USER | ASSISTANT

    @Lob
    @Column(nullable = false, columnDefinition = "TEXT")
    private String content;

    /**
     * true nếu message này (của USER) bị guardrail chặn vì ngoài phạm vi (NAC-01).
     * Hữu ích để thống kê / debug guardrail sau này.
     */
    @Column(nullable = false)
    @Builder.Default
    private Boolean wasOutOfScope = false;

    @Column(nullable = false, updatable = false)
    private LocalDateTime createdAt;

    @PrePersist
    protected void onCreate() {
        this.createdAt = LocalDateTime.now();
    }

    public enum MessageRole {
        USER, ASSISTANT
    }
}