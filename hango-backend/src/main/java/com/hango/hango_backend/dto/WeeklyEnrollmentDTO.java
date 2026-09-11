package com.hango.hango_backend.dto;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class WeeklyEnrollmentDTO {
    private String weekLabel;  // e.g. "12/08" (dd/MM of Monday)
    private long count;
}
