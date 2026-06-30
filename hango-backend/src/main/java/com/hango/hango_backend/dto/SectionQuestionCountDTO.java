package com.hango.hango_backend.dto;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class SectionQuestionCountDTO {
    private Long id;
    private String title;
    private String description;
    private Integer displayOrder;
    private Integer questionCount;
}
