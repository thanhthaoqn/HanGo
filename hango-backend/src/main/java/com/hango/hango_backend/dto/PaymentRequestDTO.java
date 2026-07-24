package com.hango.hango_backend.dto;

import lombok.Data;
import java.util.List;

@Data
public class PaymentRequestDTO {
    private Long courseId;
    private List<Long> courseIds;
}
