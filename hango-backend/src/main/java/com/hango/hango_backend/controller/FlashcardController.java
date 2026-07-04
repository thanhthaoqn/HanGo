package com.hango.hango_backend.controller;

import com.hango.hango_backend.dto.FlashcardCollectionCreateDTO;
import com.hango.hango_backend.dto.FlashcardCollectionResponseDTO;
import com.hango.hango_backend.service.FlashcardService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api/v1/flashcards")
@RequiredArgsConstructor
public class FlashcardController {

    private final FlashcardService flashcardService;

    private Long getCurrentUserId() {
        org.springframework.security.core.Authentication auth = SecurityContextHolder.getContext().getAuthentication();
        if (auth == null || !auth.isAuthenticated()) {
            return null;
        }
        Object principal = auth.getPrincipal();
        if (principal instanceof com.hango.hango_backend.sercurity.UserDetailsImpl) {
            return ((com.hango.hango_backend.sercurity.UserDetailsImpl) principal).getId();
        } else if (principal instanceof com.hango.hango_backend.entity.User) {
            return ((com.hango.hango_backend.entity.User) principal).getId();
        }
        return null;
    }

    @GetMapping("/collections")
    public ResponseEntity<List<FlashcardCollectionResponseDTO>> getCollections(
            @RequestParam(required = false, defaultValue = "All") String status) {
        Long userId = getCurrentUserId();
        if (userId == null) {
            return ResponseEntity.status(401).build();
        }
        List<FlashcardCollectionResponseDTO> collections = flashcardService.getCollections(userId, status);
        return ResponseEntity.ok(collections);
    }

    @PostMapping("/collections")
    public ResponseEntity<FlashcardCollectionResponseDTO> createCollection(
            @RequestBody FlashcardCollectionCreateDTO createDTO) {
        Long userId = getCurrentUserId();
        if (userId == null) {
            return ResponseEntity.status(401).build();
        }
        FlashcardCollectionResponseDTO response = flashcardService.createCollection(userId, createDTO);
        return ResponseEntity.ok(response);
    }

    @PutMapping("/collections/{id}")
    public ResponseEntity<FlashcardCollectionResponseDTO> updateCollection(
            @PathVariable Long id,
            @RequestBody FlashcardCollectionCreateDTO updateDTO) {
        Long userId = getCurrentUserId();
        if (userId == null) {
            return ResponseEntity.status(401).build();
        }
        FlashcardCollectionResponseDTO response = flashcardService.updateCollection(userId, id, updateDTO);
        return ResponseEntity.ok(response);
    }

    @DeleteMapping("/collections/{id}")
    public ResponseEntity<Void> deleteCollection(@PathVariable Long id) {
        Long userId = getCurrentUserId();
        if (userId == null) {
            return ResponseEntity.status(401).build();
        }
        flashcardService.deleteCollection(id);
        return ResponseEntity.ok().build();
    }

    @PostMapping("/collections/{collectionId}/cards/{cardId}/learn")
    public ResponseEntity<Void> markCardAsLearned(
            @PathVariable Long collectionId,
            @PathVariable Long cardId,
            @RequestParam boolean isLearned) {
        Long userId = getCurrentUserId();
        if (userId == null) {
            return ResponseEntity.status(401).build();
        }
        flashcardService.markCardAsLearned(userId, collectionId, cardId, isLearned);
        return ResponseEntity.ok().build();
    }

    @PostMapping("/collections/{collectionId}/touch")
    public ResponseEntity<Void> touchCollection(@PathVariable Long collectionId) {
        Long userId = getCurrentUserId();
        if (userId == null) {
            return ResponseEntity.status(401).build();
        }
        flashcardService.touchCollection(userId, collectionId);
        return ResponseEntity.ok().build();
    }
}
