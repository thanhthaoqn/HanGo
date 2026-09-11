package com.hango.hango_backend.dto;

import jakarta.validation.constraints.DecimalMax;
import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.Size;
import lombok.Data;

@Data
public class TrainerReviewRequest {
    @Size(max = 50)
    private String status; // VERIFIED | PENDING_VERIFICATION | SUSPENDED
    @DecimalMin("0.50")
    @DecimalMax("0.95")
    private Double revenueShare;
    @Size(max = 5000)
    private String adminNotes;
}
