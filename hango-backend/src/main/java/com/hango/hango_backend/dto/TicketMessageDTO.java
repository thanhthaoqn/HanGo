package com.hango.hango_backend.dto;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.LocalDateTime;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class TicketMessageDTO {
    private Long id;
    private Long ticketId;
    private Long senderId;
    private String senderName;
    private String senderEmail;
    private String senderRole;
    private String message;
    private String attachmentUrls;
    private LocalDateTime createdAt;
}
