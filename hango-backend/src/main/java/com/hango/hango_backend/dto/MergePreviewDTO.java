package com.hango.hango_backend.dto;

import com.fasterxml.jackson.annotation.JsonProperty;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.util.List;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class MergePreviewDTO {
    
    @JsonProperty("removed_duplicates")
    private Integer removedDuplicates;

    @JsonProperty("shared_steps")
    private Integer sharedSteps;

    @JsonProperty("estimated_time_saved_hours")
    private Integer estimatedTimeSavedHours;

    @JsonProperty("merged_nodes")
    private List<PathwayNodeDTO> mergedNodes;
}
