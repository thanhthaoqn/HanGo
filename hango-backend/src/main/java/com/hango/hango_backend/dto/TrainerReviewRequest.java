package com.hango.hango_backend.dto;

import lombok.Data;

@Data
public class TrainerReviewRequest {
    private String status; // VERIFIED | PENDING_VERIFICATION | SUSPENDED
    private Double revenueShare;
    private String adminNotes;
}
