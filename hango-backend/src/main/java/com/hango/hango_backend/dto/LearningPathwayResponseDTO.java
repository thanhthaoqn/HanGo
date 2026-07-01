package com.hango.hango_backend.dto;

import lombok.Builder;
import lombok.Data;
import java.util.List;

@Data
@Builder
public class LearningPathwayResponseDTO {
    private Long pathwayId;
    private String roadmapId;
    private String mentorSummary;
    private List<PathwayNodeDTO> nodes;
}
