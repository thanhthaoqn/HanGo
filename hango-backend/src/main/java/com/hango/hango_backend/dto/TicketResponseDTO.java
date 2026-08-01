package com.hango.hango_backend.dto;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.LocalDateTime;
import java.util.List;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class TicketResponseDTO {
    private Long id;
    private String ticketCode;
    private Long userId;
    private String userName;
    private String userEmail;
    private String userRole;
    private String category;
    private String priority;
    private String status; // PENDING, PROCESSING, APPROVED, REJECTED
    private String title;
    private String description;
    private String adminResponse;
    private String rejectionReason;
    private String processedByName;
    private LocalDateTime processedAt;
    private LocalDateTime createdAt;
    private LocalDateTime updatedAt;
    private List<TicketMessageDTO> messages;
}
