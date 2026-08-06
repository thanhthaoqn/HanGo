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
public class PathwayChatResponseDTO {

    @JsonProperty("conversation_id")
    private Long conversationId;

    private String reply;

    @JsonProperty("was_out_of_scope")
    private boolean wasOutOfScope;

    @JsonProperty("suggested_questions")
    private List<String> suggestedQuestions;
}
