package com.hango.hango_backend.controller;

import com.hango.hango_backend.dto.*;
import com.hango.hango_backend.service.TicketService;
import com.hango.hango_backend.security.UserDetailsImpl;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.web.bind.annotation.*;

import java.util.Map;

@RestController
@RequestMapping("/api/v1/management/tickets")
@RequiredArgsConstructor
@PreAuthorize("hasAnyRole('ADMINISTRATOR', 'TRAINER_LEAD', 'COURSE_MANAGER')")
public class ManagementTicketController {

    private final TicketService ticketService;

    private Long getCurrentUserId() {
        Authentication auth = SecurityContextHolder.getContext().getAuthentication();
        if (auth != null && auth.getPrincipal() instanceof UserDetailsImpl) {
            return ((UserDetailsImpl) auth.getPrincipal()).getId();
        }
        return null;
    }

    @GetMapping
    public ResponseEntity<Page<TicketResponseDTO>> getManagementTickets(
            @RequestParam(required = false) String status,
            @RequestParam(required = false) String category,
            @RequestParam(required = false) String keyword,
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "10") int size
    ) {
        Long userId = getCurrentUserId();
        return ResponseEntity.ok(ticketService.getManagementTickets(userId, status, category, keyword, PageRequest.of(page, size)));
    }

    @PostMapping("/{id}/process")
    public ResponseEntity<TicketResponseDTO> processTicket(
            @PathVariable Long id,
            @RequestBody TicketProcessDTO dto
    ) {
        Long managerUserId = getCurrentUserId();
        if (managerUserId == null) {
            return ResponseEntity.status(401).build();
        }
        return ResponseEntity.ok(ticketService.processTicket(managerUserId, id, dto));
    }

    @GetMapping("/stats")
    public ResponseEntity<Map<String, Object>> getTicketStats() {
        return ResponseEntity.ok(ticketService.getTicketStats());
    }
}
