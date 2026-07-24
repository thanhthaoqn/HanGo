package com.hango.hango_backend.dto;

import lombok.*;
import java.math.BigDecimal;
import java.util.List;

@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class TrainerRevenueSummaryDTO {
    private BigDecimal availableBalance; // Available for next settlement (>= 7 days hold)
    private BigDecimal pendingHoldBalance; // Pending in 7-day warranty hold
    private BigDecimal totalPaid; // Total net amount settled to date
    private String trainerType; // PROFESSIONAL | PEER_TUTOR
    private List<MonthlyStatementDTO> statements;
}
