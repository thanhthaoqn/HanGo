package com.hango.hango_backend.service;

import com.hango.hango_backend.dto.*;
import com.hango.hango_backend.entity.Ticket;
import com.hango.hango_backend.entity.TicketMessage;
import com.hango.hango_backend.entity.User;
import com.hango.hango_backend.repository.TicketMessageRepository;
import com.hango.hango_backend.repository.TicketRepository;
import com.hango.hango_backend.repository.UserRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDateTime;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

@Service
@RequiredArgsConstructor
public class TicketServiceImpl implements TicketService {

    private final TicketRepository ticketRepository;
    private final TicketMessageRepository ticketMessageRepository;
    private final UserRepository userRepository;
    private final NotificationService notificationService;

    @Override
    @Transactional
    public TicketResponseDTO createTicket(Long userId, TicketCreateDTO dto) {
        User user = userRepository.findById(userId)
                .orElseThrow(() -> new RuntimeException("User not found"));

        if (!hasRole(user, "TRAINER")) {
            throw new RuntimeException("Only trainers can create tickets");
        }

        String ticketCode = "#" + Long.toHexString(System.currentTimeMillis()).toUpperCase();
        if (ticketCode.length() > 36) {
            ticketCode = ticketCode.substring(0, 36);
        }

        String title = (dto.getTitle() != null && !dto.getTitle().isBlank()) ? dto.getTitle() : "Support Request";
        String description = (dto.getDescription() != null && !dto.getDescription().isBlank()) ? dto.getDescription() : "No details provided.";

        Ticket ticket = Ticket.builder()
                .ticketCode(ticketCode)
                .user(user)
                .userRole("TRAINER")
                .category(dto.getCategory() != null ? dto.getCategory() : "GENERAL_ENQUIRY")
                .priority(dto.getPriority() != null ? dto.getPriority() : "MEDIUM")
                .status("PENDING")
                .title(title)
                .description(description)
                .build();

        ticket = ticketRepository.save(ticket);

        // Notify System Administrators
        try {
            notificationService.notifyRole("ADMINISTRATOR", "TicketCreated", "New Support Ticket: " + ticketCode, title, null);
        } catch (Exception e) {
            System.err.println("Failed to send notification for ticket: " + e.getMessage());
        }

        return mapToDTO(ticket);
    }

    @Override
    @Transactional
    public TicketResponseDTO updateTicket(Long userId, Long ticketId, TicketCreateDTO dto) {
        Ticket ticket = ticketRepository.findById(ticketId)
                .orElseThrow(() -> new RuntimeException("Ticket not found"));

        if (!ticket.getUser().getId().equals(userId)) {
            throw new RuntimeException("Unauthorized to update this ticket");
        }

        if (dto.getTitle() != null && !dto.getTitle().isBlank()) {
            ticket.setTitle(dto.getTitle());
        }
        if (dto.getDescription() != null && !dto.getDescription().isBlank()) {
            ticket.setDescription(dto.getDescription());
        }

        ticket = ticketRepository.save(ticket);
        return mapToDTO(ticket);
    }

    @Override
    @Transactional(readOnly = true)
    public TicketResponseDTO getTicketDetail(Long userId, Long ticketId) {
        Ticket ticket = ticketRepository.findById(ticketId)
                .orElseThrow(() -> new RuntimeException("Ticket not found"));

        User user = userRepository.findById(userId).orElse(null);
        boolean isAdmin = hasRole(user, "ADMINISTRATOR");
        boolean isOwnerTrainer = hasRole(user, "TRAINER") && ticket.getUser().getId().equals(userId);

        if (!isAdmin && !isOwnerTrainer) {
            throw new RuntimeException("Access denied");
        }

        return mapToDTO(ticket);
    }

    @Override
    @Transactional(readOnly = true)
    public Page<TicketResponseDTO> getMyTickets(Long userId, String status, Pageable pageable) {
        Page<Ticket> page;
        if (status != null && !status.isBlank() && !"ALL".equalsIgnoreCase(status)) {
            if ("PROCESSED".equalsIgnoreCase(status)) {
                page = ticketRepository.findByUserIdAndStatusInOrderByCreatedAtDesc(userId, java.util.List.of("APPROVED", "REJECTED"), pageable);
            } else {
                page = ticketRepository.findByUserIdAndStatusOrderByCreatedAtDesc(userId, status.toUpperCase(), pageable);
            }
        } else {
            page = ticketRepository.findByUserIdOrderByCreatedAtDesc(userId, pageable);
        }
        return page.map(this::mapToDTO);
    }

    @Override
    @Transactional
    public TicketMessageDTO addMessage(Long userId, Long ticketId, String message) {
        Ticket ticket = ticketRepository.findById(ticketId)
                .orElseThrow(() -> new RuntimeException("Ticket not found"));

        User sender = userRepository.findById(userId)
                .orElseThrow(() -> new RuntimeException("User not found"));

        boolean isAdmin = hasRole(sender, "ADMINISTRATOR");
        boolean isOwnerTrainer = hasRole(sender, "TRAINER") && ticket.getUser().getId().equals(userId);

        if (message == null || message.trim().isEmpty()) {
            throw new RuntimeException("Message content cannot be empty");
        }

        if ("APPROVED".equalsIgnoreCase(ticket.getStatus()) || "REJECTED".equalsIgnoreCase(ticket.getStatus())) {
            throw new RuntimeException("Cannot reply to a closed ticket");
        }

        if (!isAdmin && !isOwnerTrainer) {
            throw new RuntimeException("Access denied: You do not have permission to reply to this ticket");
        }

        String senderRole = isAdmin ? "ADMINISTRATOR" : "TRAINER";

        TicketMessage msg = TicketMessage.builder()
                .ticket(ticket)
                .sender(sender)
                .senderRole(senderRole)
                .message(message)
                .build();

        msg = ticketMessageRepository.save(msg);

        ticket.setUpdatedAt(LocalDateTime.now());
        if ("PENDING".equals(ticket.getStatus()) && isAdmin) {
            ticket.setStatus("PROCESSING");
        }
        ticketRepository.save(ticket);

        try {
            if (isAdmin) {
                notificationService.notifyUser(
                        ticket.getUser(),
                        "TicketResponse",
                        "New Response on Ticket #" + ticket.getTicketCode(),
                        sender.getFullName() + " (Admin): " + message,
                        null
                );
            } else {
                notificationService.notifyRole(
                        "ADMINISTRATOR",
                        "TicketResponse",
                        "New Message on Ticket #" + ticket.getTicketCode(),
                        sender.getFullName() + " (Trainer): " + message,
                        null
                );
            }
        } catch (Exception e) {
            System.err.println("Failed to send notification for ticket message: " + e.getMessage());
        }

        return mapToMessageDTO(msg);
    }

    @Override
    @Transactional(readOnly = true)
    public Page<TicketResponseDTO> getManagementTickets(Long currentUserId, String status, String category, String keyword, Pageable pageable) {
        String filterStatus = (status != null && !status.isBlank() && !"ALL".equalsIgnoreCase(status)) ? status.toUpperCase() : null;
        String filterCategory = (category != null && !category.isBlank() && !"ALL".equalsIgnoreCase(category)) ? category.toUpperCase() : null;
        String filterKeyword = (keyword != null && !keyword.isBlank()) ? keyword.trim() : null;

        Page<Ticket> page = ticketRepository.findAllFiltered(filterStatus, filterCategory, filterKeyword, pageable);
        return page.map(this::mapToDTO);
    }

    @Override
    @Transactional
    public TicketResponseDTO processTicket(Long managerUserId, Long ticketId, TicketProcessDTO dto) {
        Ticket ticket = ticketRepository.findById(ticketId)
                .orElseThrow(() -> new RuntimeException("Ticket not found"));

        User manager = userRepository.findById(managerUserId)
                .orElseThrow(() -> new RuntimeException("Manager not found"));

        if (!hasRole(manager, "ADMINISTRATOR")) {
            throw new RuntimeException("Only administrators can process tickets");
        }

        ticket.setProcessedBy(manager);
        ticket.setProcessedAt(LocalDateTime.now());

        if ("APPROVE".equalsIgnoreCase(dto.getAction())) {
            ticket.setStatus("APPROVED");
            if (dto.getAdminResponse() != null && !dto.getAdminResponse().isBlank()) {
                ticket.setAdminResponse(dto.getAdminResponse());
            } else {
                ticket.setAdminResponse("Ticket approved by administrator.");
            }
        } else if ("REJECT".equalsIgnoreCase(dto.getAction())) {
            ticket.setStatus("REJECTED");
            ticket.setRejectionReason(dto.getRejectionReason());
            if (dto.getAdminResponse() != null && !dto.getAdminResponse().isBlank()) {
                ticket.setAdminResponse(dto.getAdminResponse());
            } else {
                ticket.setAdminResponse(null);
            }
        }

        ticket = ticketRepository.save(ticket);

        String responseText = "APPROVE".equalsIgnoreCase(dto.getAction())
                ? "Ticket approved: " + (ticket.getAdminResponse() != null ? ticket.getAdminResponse() : "Approved")
                : "Ticket rejected. Reason: " + (dto.getRejectionReason() != null ? dto.getRejectionReason() : "N/A");

        try {
            String title = "APPROVE".equalsIgnoreCase(dto.getAction()) ? "Support Ticket Approved" : "Support Ticket Rejected";
            notificationService.notifyUser(ticket.getUser(), "TicketReviewed", title, responseText, null);
        } catch (Exception ignored) {}

        return mapToDTO(ticket);
    }

    @Override
    @Transactional(readOnly = true)
    public Map<String, Object> getTicketStats() {
        Map<String, Object> stats = new HashMap<>();
        stats.put("total", ticketRepository.count());
        stats.put("pending", ticketRepository.countByStatus("PENDING"));
        stats.put("processing", ticketRepository.countByStatus("PROCESSING"));
        stats.put("approved", ticketRepository.countByStatus("APPROVED"));
        stats.put("rejected", ticketRepository.countByStatus("REJECTED"));
        return stats;
    }

    private TicketResponseDTO mapToDTO(Ticket ticket) {
        List<TicketMessage> messages = ticketMessageRepository.findByTicketIdOrderByCreatedAtAsc(ticket.getId());
        String ticketDesc = ticket.getDescription() != null ? ticket.getDescription().trim() : "";
        List<TicketMessageDTO> messageDTOs = messages.stream()
                .filter(msg -> {
                    if (msg.getMessage() == null) return false;
                    String text = msg.getMessage().trim();
                    if (text.equalsIgnoreCase(ticketDesc)) return false;
                    if (text.startsWith("Ticket approved by ") || text.startsWith("Ticket rejected by ")) return false;
                    return true;
                })
                .map(this::mapToMessageDTO)
                .toList();

        String cleanAdminResponse = ticket.getAdminResponse();
        if (cleanAdminResponse != null && (cleanAdminResponse.startsWith("Ticket rejected") || "REJECTED".equalsIgnoreCase(ticket.getStatus()))) {
            cleanAdminResponse = null;
        }

        return TicketResponseDTO.builder()
                .id(ticket.getId())
                .ticketCode(ticket.getTicketCode())
                .userId(ticket.getUser() != null ? ticket.getUser().getId() : null)
                .userName(ticket.getUser() != null ? ticket.getUser().getFullName() : null)
                .userEmail(ticket.getUser() != null ? ticket.getUser().getEmail() : null)
                .userRole(ticket.getUserRole())
                .category(ticket.getCategory())
                .priority(ticket.getPriority())
                .status(ticket.getStatus())
                .title(ticket.getTitle())
                .description(ticket.getDescription())
                .adminResponse(cleanAdminResponse)
                .rejectionReason(ticket.getRejectionReason())
                .processedByName(ticket.getProcessedBy() != null ? ticket.getProcessedBy().getFullName() : null)
                .processedAt(ticket.getProcessedAt())
                .createdAt(ticket.getCreatedAt())
                .updatedAt(ticket.getUpdatedAt())
                .messages(messageDTOs)
                .build();
    }

    private TicketMessageDTO mapToMessageDTO(TicketMessage msg) {
        return TicketMessageDTO.builder()
                .id(msg.getId())
                .ticketId(msg.getTicket().getId())
                .senderId(msg.getSender().getId())
                .senderName(msg.getSender().getFullName())
                .senderEmail(msg.getSender().getEmail())
                .senderRole(msg.getSenderRole())
                .message(msg.getMessage())
                .createdAt(msg.getCreatedAt())
                .build();
    }

    private boolean hasRole(User user, String roleName) {
        if (user == null || user.getRoles() == null) {
            return false;
        }
        return user.getRoles().stream()
                .filter(role -> role != null && role.getRoleName() != null)
                .map(role -> role.getRoleName().trim())
                .anyMatch(value -> roleName.equalsIgnoreCase(value)
                        || ("ROLE_" + roleName).equalsIgnoreCase(value));
    }
}
