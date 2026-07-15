package com.hango.hango_backend.dto;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.util.List;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class CourseImportResultDTO {
    private String message;
    private int importedCourses;
    private int importedSections;
    private int importedLessons;
    private int importedQuestions;
    private List<Long> courseIds;
    private List<String> warnings;
}
