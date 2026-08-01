package com.hango.hango_backend.controller;

import com.hango.hango_backend.dto.CourseSummaryDTO;
import com.hango.hango_backend.security.UserDetailsImpl;
import com.hango.hango_backend.service.CartService;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.Map;

@Slf4j
@RestController
@RequestMapping("/api/v1/cart")
@RequiredArgsConstructor
public class CartController {

    private final CartService cartService;

    @GetMapping
    public ResponseEntity<?> getCart(@AuthenticationPrincipal UserDetailsImpl currentUser) {
        if (currentUser == null) {
            return ResponseEntity.status(401).body(Map.of("error", "Unauthorized"));
        }
        try {
            List<CourseSummaryDTO> items = cartService.getCartItems(currentUser.getId());
            return ResponseEntity.ok(items);
        } catch (Exception e) {
            log.error("Error fetching cart for userId={}", currentUser.getId(), e);
            return ResponseEntity.status(500).body(Map.of("error", e.getMessage()));
        }
    }

    @PostMapping("/items")
    public ResponseEntity<?> addItem(
            @RequestBody Map<String, Long> payload,
            @AuthenticationPrincipal UserDetailsImpl currentUser) {
        if (currentUser == null) {
            return ResponseEntity.status(401).body(Map.of("error", "Unauthorized"));
        }
        Long courseId = payload.get("courseId");
        if (courseId == null) {
            return ResponseEntity.badRequest().body(Map.of("error", "courseId is required"));
        }
        try {
            cartService.addItemToCart(currentUser.getId(), courseId);
            return ResponseEntity.ok(Map.of("success", true, "message", "Course added to cart"));
        } catch (Exception e) {
            log.error("Error adding courseId={} to cart for userId={}", courseId, currentUser.getId(), e);
            return ResponseEntity.badRequest().body(Map.of("error", e.getMessage()));
        }
    }

    @DeleteMapping("/items/{courseId}")
    public ResponseEntity<?> removeItem(
            @PathVariable Long courseId,
            @AuthenticationPrincipal UserDetailsImpl currentUser) {
        if (currentUser == null) {
            return ResponseEntity.status(401).body(Map.of("error", "Unauthorized"));
        }
        try {
            cartService.removeItemFromCart(currentUser.getId(), courseId);
            return ResponseEntity.ok(Map.of("success", true));
        } catch (Exception e) {
            log.error("Error removing courseId={} from cart for userId={}", courseId, currentUser.getId(), e);
            return ResponseEntity.status(500).body(Map.of("error", e.getMessage()));
        }
    }

    @DeleteMapping
    public ResponseEntity<?> clearCart(@AuthenticationPrincipal UserDetailsImpl currentUser) {
        if (currentUser == null) {
            return ResponseEntity.status(401).body(Map.of("error", "Unauthorized"));
        }
        try {
            cartService.clearCart(currentUser.getId());
            return ResponseEntity.ok(Map.of("success", true));
        } catch (Exception e) {
            log.error("Error clearing cart for userId={}", currentUser.getId(), e);
            return ResponseEntity.status(500).body(Map.of("error", e.getMessage()));
        }
    }

    @PostMapping("/sync")
    public ResponseEntity<?> syncCart(
            @RequestBody Map<String, List<Long>> payload,
            @AuthenticationPrincipal UserDetailsImpl currentUser) {
        if (currentUser == null) {
            return ResponseEntity.status(401).body(Map.of("error", "Unauthorized"));
        }
        List<Long> courseIds = payload.get("courseIds");
        try {
            cartService.syncCart(currentUser.getId(), courseIds);
            return ResponseEntity.ok(Map.of("success", true));
        } catch (Exception e) {
            log.error("Error syncing cart for userId={}", currentUser.getId(), e);
            return ResponseEntity.status(500).body(Map.of("error", e.getMessage()));
        }
    }
}
