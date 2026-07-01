package com.hango.hango_backend.dto;

import lombok.Builder;
import lombok.Data;
import java.util.List;

@Data
@Builder
public class PathwayNodeDTO {
    private Integer step;
    private Long courseId;
    private String courseTitle;
    private List<String> tags;
    private String status;
    private String reasonWhy;
    private Integer progressPercent;
}
