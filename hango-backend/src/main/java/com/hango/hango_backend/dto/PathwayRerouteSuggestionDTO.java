package com.hango.hango_backend.dto;

import com.fasterxml.jackson.annotation.JsonProperty;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class PathwayRerouteSuggestionDTO {

    /**
     * One of: FAST_TRACK_SKIPPED, DETOUR_REMEDIAL, MERGED
     */
    @JsonProperty("node_type")
    private String nodeType;

    @JsonProperty("reroute_reason")
    private String rerouteReason;

    @JsonProperty("can_skip")
    private Boolean canSkip;

    @JsonProperty("blocked_reason")
    private String blockedReason;
}

