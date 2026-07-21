package com.hango.hango_backend.dto;

import com.fasterxml.jackson.annotation.JsonProperty;
import lombok.Builder;
import lombok.Data;

import java.time.LocalDateTime;

@Data
@Builder
public class PaymentStatusDTO {
    @JsonProperty("txn_ref")
    private String txnRef;

    private String status;

    @JsonProperty("course_id")
    private Long courseId;

    @JsonProperty("course_title")
    private String courseTitle;

    @JsonProperty("paid_at")
    private LocalDateTime paidAt;
}
