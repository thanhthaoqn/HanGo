package com.hango.hango_backend.controller;

import com.hango.hango_backend.dto.*;
import com.hango.hango_backend.service.TicketService;
import com.hango.hango_backend.security.UserDetailsImpl;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

import java.util.Map;

@RestController
@RequestMapping("/api/v1/tickets")
@RequiredArgsConstructor
@PreAuthorize("hasAnyRole('TRAINER', 'ADMINISTRATOR')")
public class TicketController {

    private final TicketService ticketService;

    private Long getCurrentUserId() {
        Authentication auth = SecurityContextHolder.getContext().getAuthentication();
        if (auth != null && auth.getPrincipal() instanceof UserDetailsImpl) {
            return ((UserDetailsImpl) auth.getPrincipal()).getId();
        }
        return null;
    }

    @PostMapping
    @PreAuthorize("hasRole('TRAINER')")
    public ResponseEntity<?> createTicket(@RequestBody TicketCreateDTO dto) {
        try {
            Long userId = getCurrentUserId();
            if (userId == null) {
                return ResponseEntity.status(401).body(Map.of("message", "Unauthorized - Please log in"));
            }
            return ResponseEntity.ok(ticketService.createTicket(userId, dto));
        } catch (Exception e) {
            e.printStackTrace();
            return ResponseEntity.status(500).body(Map.of("message", "Ticket Creation Error: " + e.getMessage()));
        }
    }

    @PutMapping("/{id}")
    @PreAuthorize("hasRole('TRAINER')")
    public ResponseEntity<TicketResponseDTO> updateTicket(@PathVariable Long id, @RequestBody TicketCreateDTO dto) {
        Long userId = getCurrentUserId();
        if (userId == null) {
            return ResponseEntity.status(401).build();
        }
        return ResponseEntity.ok(ticketService.updateTicket(userId, id, dto));
    }

    @GetMapping("/{id}")
    public ResponseEntity<TicketResponseDTO> getTicketDetail(@PathVariable Long id) {
        Long userId = getCurrentUserId();
        if (userId == null) {
            return ResponseEntity.status(401).build();
        }
        return ResponseEntity.ok(ticketService.getTicketDetail(userId, id));
    }

    @GetMapping("/my-tickets")
    @PreAuthorize("hasRole('TRAINER')")
    public ResponseEntity<Page<TicketResponseDTO>> getMyTickets(
            @RequestParam(required = false) String status,
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "10") int size
    ) {
        Long userId = getCurrentUserId();
        if (userId == null) {
            return ResponseEntity.status(401).build();
        }
        return ResponseEntity.ok(ticketService.getMyTickets(userId, status, PageRequest.of(page, size)));
    }

    @PostMapping("/{id}/messages")
    public ResponseEntity<TicketMessageDTO> addMessage(
            @PathVariable Long id,
            @RequestBody Map<String, String> body
    ) {
        Long userId = getCurrentUserId();
        if (userId == null) {
            return ResponseEntity.status(401).build();
        }
        String message = body.get("message");
        return ResponseEntity.ok(ticketService.addMessage(userId, id, message));
    }
}
