package com.hango.hango_backend.exception;

import java.util.List;
import java.util.Map;

/**
 * Thrown by CourseImportService.importWorkbook when validation finds one or
 * more row/field-level errors across the COURSE/SYLLABUS/QUESTIONS sheets.
 * Carries the full list of errors (mirroring ExamImportController's inline
 * "errors" list) so the controller can return them all at once instead of
 * forcing the trainer to fix-and-reupload once per error.
 */
public class CourseImportValidationException extends RuntimeException {

    private final List<Map<String, Object>> errors;

    public CourseImportValidationException(String message, List<Map<String, Object>> errors) {
        super(message);
        this.errors = errors;
    }

    public List<Map<String, Object>> getErrors() {
        return errors;
    }
}
