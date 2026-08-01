package com.hango.hango_backend.dto;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class TicketProcessDTO {
    private String action; // APPROVE, REJECT
    private String rejectionReason;
    private String adminResponse;
}
