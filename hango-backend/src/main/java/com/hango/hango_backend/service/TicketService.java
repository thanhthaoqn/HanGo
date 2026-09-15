package com.hango.hango_backend.service;

import com.hango.hango_backend.dto.*;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;

import java.util.Map;

public interface TicketService {

    TicketResponseDTO createTicket(Long userId, TicketCreateDTO dto);

    TicketResponseDTO updateTicket(Long userId, Long ticketId, TicketCreateDTO dto);

    TicketResponseDTO getTicketDetail(Long userId, Long ticketId);

    Page<TicketResponseDTO> getMyTickets(Long userId, String status, Pageable pageable);

    TicketMessageDTO addMessage(Long userId, Long ticketId, String message);

    // Administrator management endpoints
    Page<TicketResponseDTO> getManagementTickets(Long currentUserId, String status, String category, String keyword, Pageable pageable);

    TicketResponseDTO processTicket(Long managerUserId, Long ticketId, TicketProcessDTO dto);

    Map<String, Object> getTicketStats();
}
