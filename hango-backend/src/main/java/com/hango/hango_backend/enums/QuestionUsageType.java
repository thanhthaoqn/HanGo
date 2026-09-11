package com.hango.hango_backend.enums;

import lombok.Getter;

@Getter
public enum QuestionUsageType {
    QUIZ_ONLY(1, "PRACTICE"),
    EXAM_ONLY(2, "EXAM"),
    BOTH(3, "BOTH (Need restrictions)");

    private final int value;
    private final String description;

    QuestionUsageType(int value, String description) {
        this.value = value;
        this.description = description;
    }

    public static QuestionUsageType fromValue(Integer value) {
        if (value == null)
            return QUIZ_ONLY;
        for (QuestionUsageType type : QuestionUsageType.values()) {
            if (type.getValue() == value) {
                return type;
            }
        }
        return QUIZ_ONLY; // Default fallback to ensure backward compatibility
    }
}
