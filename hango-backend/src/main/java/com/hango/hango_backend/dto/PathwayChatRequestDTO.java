package com.hango.hango_backend.dto;

import com.fasterxml.jackson.annotation.JsonProperty;
import jakarta.validation.constraints.NotBlank;
import lombok.Data;

@Data
public class PathwayChatRequestDTO {
    
    @NotBlank(message = "Message cannot be empty")
    private String message;

    /** Optional: continue an existing conversation instead of starting a new one. */
    @JsonProperty("conversation_id")
    private Long conversationId;

    /** Optional: the course ID of the node the learner has currently selected in the UI. */
    @JsonProperty("selected_node_course_id")
    private Long selectedNodeCourseId;
}
