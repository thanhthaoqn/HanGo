package com.hango.hango_backend.dto;

import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.util.Map;

@Data
@NoArgsConstructor
@AllArgsConstructor
public class MasterySubmitRequestDTO {
    /** Legacy: diem tu khai bao (deprecated - chi con de tuong thich FE cu). */
    private Integer score;

    /** Chuan moi: bang dap an {questionId: selectedOptionIndex} hoac {questionId: [selectedIndices]} - server tu cham. */
    private Map<String, Object> answers;
}
