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

        String userRole = "ROLE_LEARNER";
        if (user.getRoles() != null && !user.getRoles().isEmpty()) {
            for (com.hango.hango_backend.entity.Role r : user.getRoles()) {
                if (r != null && r.getRoleName() != null && !r.getRoleName().isBlank()) {
                    userRole = r.getRoleName();
                    break;
                }
            }
        }
        if (userRole.length() > 30) {
            userRole = userRole.substring(0, 30);
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
                .userRole(userRole)
                .category(dto.getCategory() != null ? dto.getCategory() : "GENERAL_ENQUIRY")
                .priority(dto.getPriority() != null ? dto.getPriority() : "MEDIUM")
                .status("PENDING")
                .title(title)
                .description(description)
                .build();

        ticket = ticketRepository.save(ticket);

        // Add initial description as first message
        TicketMessage firstMsg = TicketMessage.builder()
                .ticket(ticket)
                .sender(user)
                .senderRole(userRole)
                .message(description)
                .build();

        ticketMessageRepository.save(firstMsg);

        // Notify Course Managers
        try {
            notificationService.notifyRole("TRAINER_LEAD", "TicketCreated", "New Support Ticket: " + ticketCode, title, null);
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
        boolean isStaff = user != null && user.getRoles() != null &&
                user.getRoles().stream().anyMatch(r -> 
                    "ADMINISTRATOR".equalsIgnoreCase(r.getRoleName()) || 
                    "TRAINER_LEAD".equalsIgnoreCase(r.getRoleName()) || 
                    "COURSE_MANAGER".equalsIgnoreCase(r.getRoleName())
                );

        if (!isStaff && !ticket.getUser().getId().equals(userId)) {
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
    public TicketMessageDTO addMessage(Long userId, Long ticketId, String message, String attachmentUrls) {
        Ticket ticket = ticketRepository.findById(ticketId)
                .orElseThrow(() -> new RuntimeException("Ticket not found"));

        User sender = userRepository.findById(userId)
                .orElseThrow(() -> new RuntimeException("User not found"));

        String senderRole = "LEARNER";
        if (sender.getRoles() != null && !sender.getRoles().isEmpty()) {
            senderRole = sender.getRoles().iterator().next().getRoleName();
        }

        TicketMessage msg = TicketMessage.builder()
                .ticket(ticket)
                .sender(sender)
                .senderRole(senderRole)
                .message(message)
                .attachmentUrls(attachmentUrls)
                .build();

        msg = ticketMessageRepository.save(msg);

        ticket.setUpdatedAt(LocalDateTime.now());
        if ("PENDING".equals(ticket.getStatus()) && !"LEARNER".equals(senderRole) && !"TRAINER".equals(senderRole)) {
            ticket.setStatus("PROCESSING");
        }
        ticketRepository.save(ticket);

        return mapToMessageDTO(msg);
    }

    @Override
    @Transactional(readOnly = true)
    public Page<TicketResponseDTO> getManagementTickets(Long currentUserId, String status, String category, String keyword, Pageable pageable) {
        String filterStatus = (status != null && !status.isBlank() && !"ALL".equalsIgnoreCase(status)) ? status.toUpperCase() : null;
        String filterCategory = (category != null && !category.isBlank() && !"ALL".equalsIgnoreCase(category)) ? category.toUpperCase() : null;
        String filterKeyword = (keyword != null && !keyword.isBlank()) ? keyword.trim() : null;

        // Role-based Category Routing
        if (currentUserId != null) {
            User user = userRepository.findById(currentUserId).orElse(null);
            if (user != null && user.getRoles() != null) {
                boolean isAdmin = user.getRoles().stream()
                        .anyMatch(r -> r.getRoleName() != null && (r.getRoleName().contains("ADMIN") || r.getRoleName().contains("ADMINISTRATOR")));
                boolean isCourseManager = user.getRoles().stream()
                        .anyMatch(r -> r.getRoleName() != null && (r.getRoleName().contains("MANAGER") || r.getRoleName().contains("TRAINER_LEAD")));

                // If user is Course Manager (and not Admin), allow all operational and settlement categories
                if (isCourseManager && !isAdmin && filterCategory == null) {
                    // Allowed for CM: CONTENT_ISSUE, GENERAL_ENQUIRY, REVENUE_STATEMENT_DISPUTE
                }
            }
        }

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

        // RBAC Enforcement: Course Manager handles Content, General Enquiries, and Revenue Settlement Disputes.
        // System Admin handles Bank/Tax Updates and Course Refunds.
        boolean isManagerAdmin = manager.getRoles() != null && manager.getRoles().stream()
                .anyMatch(r -> r.getRoleName() != null && (r.getRoleName().contains("ADMIN") || r.getRoleName().contains("ADMINISTRATOR")));

        if (!isManagerAdmin) {
            String cat = ticket.getCategory();
            if ("PAYOUT_INFO_UPDATE".equalsIgnoreCase(cat) || "REFUND_REQUEST".equalsIgnoreCase(cat)) {
                throw new RuntimeException("Course Manager is not authorized to process Bank/Tax Info Updates or Refund Requests. Assigned to System Admin.");
            }
        }

        ticket.setProcessedBy(manager);
        ticket.setProcessedAt(LocalDateTime.now());

        if ("APPROVE".equalsIgnoreCase(dto.getAction())) {
            ticket.setStatus("APPROVED");
            if (dto.getAdminResponse() != null && !dto.getAdminResponse().isBlank()) {
                ticket.setAdminResponse(dto.getAdminResponse());
            } else {
                ticket.setAdminResponse("Ticket approved by manager.");
            }
        } else if ("REJECT".equalsIgnoreCase(dto.getAction())) {
            ticket.setStatus("REJECTED");
            ticket.setRejectionReason(dto.getRejectionReason());
            if (dto.getAdminResponse() != null && !dto.getAdminResponse().isBlank()) {
                ticket.setAdminResponse(dto.getAdminResponse());
            } else {
                ticket.setAdminResponse("Ticket rejected by manager.");
            }
        }

        ticket = ticketRepository.save(ticket);

        String responseText = "APPROVE".equalsIgnoreCase(dto.getAction())
                ? "Ticket approved by " + manager.getFullName() + ": " + ticket.getAdminResponse()
                : "Ticket rejected by " + manager.getFullName() + ". Reason: " + (dto.getRejectionReason() != null ? dto.getRejectionReason() : "N/A");

        TicketMessage msg = TicketMessage.builder()
                .ticket(ticket)
                .sender(manager)
                .senderRole("ADMINISTRATOR")
                .message(responseText)
                .build();
        ticketMessageRepository.save(msg);

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
        List<TicketMessageDTO> messageDTOs = messages.stream().map(this::mapToMessageDTO).toList();

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
                .adminResponse(ticket.getAdminResponse())
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
                .attachmentUrls(msg.getAttachmentUrls())
                .createdAt(msg.getCreatedAt())
                .build();
    }
}
