package com.hango.hango_backend.controller;

import com.hango.hango_backend.dto.TrainerCreateCourseRequestDTO;
import jakarta.validation.ConstraintViolation;
import jakarta.validation.Validation;
import jakarta.validation.Validator;
import jakarta.validation.ValidatorFactory;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

import java.math.BigDecimal;
import java.util.ArrayList;
import java.util.Set;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.junit.jupiter.api.Assertions.assertFalse;

class TrainerDashboardControllerValidationTest {

    private Validator validator;

    @BeforeEach
    void setUp() {
        ValidatorFactory factory = Validation.buildDefaultValidatorFactory();
        validator = factory.getValidator();
    }

    @Test
    void createCourse_WithValidData_HasNoViolations() {
        TrainerCreateCourseRequestDTO request = TrainerCreateCourseRequestDTO.builder()
                .title("Valid Title")
                .code("VALID-CODE")
                .description("Valid Description")
                .price(BigDecimal.valueOf(100.0))
                .objectives("Valid Objectives")
                .sessions(new ArrayList<>())
                .build();

        Set<ConstraintViolation<TrainerCreateCourseRequestDTO>> violations = validator.validate(request);
        assertTrue(violations.isEmpty(), "Valid DTO should not have validation errors");
    }

    @Test
    void createCourse_WithMissingTitle_HasViolations() {
        TrainerCreateCourseRequestDTO request = TrainerCreateCourseRequestDTO.builder()
                .title("") // Blank title
                .code("VALID-CODE")
                .price(BigDecimal.valueOf(100.0))
                .sessions(new ArrayList<>())
                .build();

        Set<ConstraintViolation<TrainerCreateCourseRequestDTO>> violations = validator.validate(request);
        assertFalse(violations.isEmpty(), "Blank title should cause a validation error");
        
        boolean hasTitleViolation = violations.stream()
                .anyMatch(v -> v.getPropertyPath().toString().equals("title"));
        assertTrue(hasTitleViolation, "Should have a validation error on 'title' field");
    }

    @Test
    void createCourse_WithNegativePrice_HasViolations() {
        TrainerCreateCourseRequestDTO request = TrainerCreateCourseRequestDTO.builder()
                .title("Valid Title")
                .code("VALID-CODE")
                .price(BigDecimal.valueOf(-10.0)) // Negative price
                .sessions(new ArrayList<>())
                .build();

        Set<ConstraintViolation<TrainerCreateCourseRequestDTO>> violations = validator.validate(request);
        assertFalse(violations.isEmpty(), "Negative price should cause a validation error");
        
        boolean hasPriceViolation = violations.stream()
                .anyMatch(v -> v.getPropertyPath().toString().equals("price"));
        assertTrue(hasPriceViolation, "Should have a validation error on 'price' field");
    }

    @Test
    void createCourse_WithRealCreatePagePayloadShape_HasNoViolations() {
        // Regression test: create_course_page.dart's real POST body never
        // includes "code" (the server auto-generates it in
        // TrainerDashboardServiceImpl.createTrainerCourse via
        // generateUniqueCourseCode()) but DOES always include "price" (the
        // Trainer's own chosen price). Previously `code` was @NotBlank,
        // which made the real create-course request always fail Spring's
        // @Valid with 400 "Code cannot be blank" before ever reaching the
        // controller method body.
        TrainerCreateCourseRequestDTO request = TrainerCreateCourseRequestDTO.builder()
                .title("Some title")
                .description("desc")
                .categoryKey("GRAMMAR")
                .difficultyKey("BASIC")
                .price(BigDecimal.valueOf(500000))
                .build();

        Set<ConstraintViolation<TrainerCreateCourseRequestDTO>> violations = validator.validate(request);

        assertTrue(violations.isEmpty(),
                "Create-course payload without 'code' should be valid: " + violations);
    }

    @Test
    void createCourse_WithMissingPrice_HasViolations() {
        TrainerCreateCourseRequestDTO request = TrainerCreateCourseRequestDTO.builder()
                .title("Valid Title")
                .code("VALID-CODE")
                .sessions(new ArrayList<>())
                .build();

        Set<ConstraintViolation<TrainerCreateCourseRequestDTO>> violations = validator.validate(request);

        boolean hasPriceViolation = violations.stream()
                .anyMatch(v -> v.getPropertyPath().toString().equals("price"));
        assertTrue(hasPriceViolation, "Missing price should cause a validation error");
    }
}
