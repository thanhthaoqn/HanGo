package com.hango.hango_backend.dto;

import com.fasterxml.jackson.annotation.JsonIgnoreProperties;
import com.fasterxml.jackson.annotation.JsonInclude;
import jakarta.validation.constraints.Size;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
@JsonIgnoreProperties(ignoreUnknown = true)
@JsonInclude(JsonInclude.Include.NON_NULL)
public class TrainerDocumentDTO {
    @Size(max = 50)
    private String type;
    @Size(max = 200)
    private String name;
    @Size(max = 2048)
    private String url;
    @Size(max = 200)
    private String issuingInstitution;
    @Size(max = 200)
    private String holderName;
    @Size(max = 100)
    private String source;
}
