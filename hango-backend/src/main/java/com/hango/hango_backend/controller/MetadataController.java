package com.hango.hango_backend.controller;

import com.hango.hango_backend.entity.QuestionCategory;
import com.hango.hango_backend.entity.SystemParameter;
import com.hango.hango_backend.repository.QuestionCategoryRepository;
import com.hango.hango_backend.repository.SystemParameterRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@CrossOrigin(origins = "*", maxAge = 3600)
@RestController
@RequestMapping("/api/v1/metadata")
@RequiredArgsConstructor
public class MetadataController {

    private final SystemParameterRepository systemParameterRepository;
    private final QuestionCategoryRepository questionCategoryRepository;

    @GetMapping("/parameters")
    public ResponseEntity<List<SystemParameter>> getParameters(@RequestParam String type) {
        return ResponseEntity.ok(systemParameterRepository.findByParamTypeAndIsActiveTrue(type));
    }

    @GetMapping("/categories")
    public ResponseEntity<List<QuestionCategory>> getCategories() {
        return ResponseEntity.ok(questionCategoryRepository.findAll());
    }
}
