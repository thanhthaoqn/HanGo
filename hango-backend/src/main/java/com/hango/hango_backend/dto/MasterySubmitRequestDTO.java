package com.hango.hango_backend.dto;

import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@NoArgsConstructor
@AllArgsConstructor
public class MasterySubmitRequestDTO {
    private Integer score; // e.g. 0 to 100
}
