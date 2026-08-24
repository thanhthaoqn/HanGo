package com.hango.hango_backend.service;

import com.hango.hango_backend.dto.TicketCreateDTO;
import com.hango.hango_backend.dto.TicketProcessDTO;
import com.hango.hango_backend.dto.TicketResponseDTO;
import com.hango.hango_backend.entity.Role;
import com.hango.hango_backend.entity.Ticket;
import com.hango.hango_backend.entity.TicketMessage;
import com.hango.hango_backend.entity.User;
import com.hango.hango_backend.repository.TicketMessageRepository;
import com.hango.hango_backend.repository.TicketRepository;
import com.hango.hango_backend.repository.UserRepository;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageImpl;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Pageable;

import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.Set;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.ArgumentMatchers.isNull;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class TicketServiceImplTest {

    @Mock
    private TicketRepository ticketRepository;
    @Mock
    private TicketMessageRepository ticketMessageRepository;
    @Mock
    private UserRepository userRepository;
    @Mock
    private NotificationService notificationService;

    @InjectMocks
    private TicketServiceImpl service;

    private User user(Long id, String email, String roleName) {
        return User.builder().id(id).email(email).fullName("User " + id)
                .roles(Set.of(Role.builder().roleName(roleName).build()))
                .build();
    }

    private Ticket ticket(Long id, User owner, String status, String category) {
        return Ticket.builder().id(id).ticketCode("#ABC123").user(owner).userRole("TRAINER")
                .category(category).priority("MEDIUM").status(status)
                .title("Help needed").description("Details").build();
    }

    // =================================================================
    // createTicket
    // =================================================================

    @Test
    void createTicketShouldThrowWhenUserNotFound() {
        when(userRepository.findById(1L)).thenReturn(Optional.empty());

        assertThrows(RuntimeException.class,
                () -> service.createTicket(1L, TicketCreateDTO.builder().title("Help").build()));
    }

    @Test
    void createTicketShouldSaveTrainerTicketAndNotifyAdministrator() {
        User trainer = user(1L, "trainer@example.com", "TRAINER");
        when(userRepository.findById(1L)).thenReturn(Optional.of(trainer));
        when(ticketRepository.save(any(Ticket.class))).thenAnswer(inv -> {
            Ticket t = inv.getArgument(0);
            t.setId(10L);
            return t;
        });
        when(ticketMessageRepository.findByTicketIdOrderByCreatedAtAsc(10L)).thenReturn(List.of());

        TicketCreateDTO dto = TicketCreateDTO.builder().category("CONTENT_ISSUE").priority("HIGH")
                .title("Video won't load").description("The lesson video is broken").build();
        service.createTicket(1L, dto);

        ArgumentCaptor<Ticket> ticketCaptor = ArgumentCaptor.forClass(Ticket.class);
        verify(ticketRepository).save(ticketCaptor.capture());
        assertEquals("TRAINER", ticketCaptor.getValue().getUserRole());
        assertEquals("CONTENT_ISSUE", ticketCaptor.getValue().getCategory());
        assertEquals("HIGH", ticketCaptor.getValue().getPriority());
        assertEquals("PENDING", ticketCaptor.getValue().getStatus());

        verify(ticketMessageRepository, never()).save(any());
        verify(notificationService).notifyRole(eq("ADMINISTRATOR"), eq("TicketCreated"), any(), any(), isNull());
    }

    @Test
    void createTicketShouldDefaultCategoryPriorityAndTextWhenNotProvided() {
        when(userRepository.findById(1L)).thenReturn(Optional.of(user(1L, "trainer@example.com", "TRAINER")));
        when(ticketRepository.save(any(Ticket.class))).thenAnswer(inv -> inv.getArgument(0));
        when(ticketMessageRepository.findByTicketIdOrderByCreatedAtAsc(null)).thenReturn(List.of());

        service.createTicket(1L, TicketCreateDTO.builder().build());

        ArgumentCaptor<Ticket> captor = ArgumentCaptor.forClass(Ticket.class);
        verify(ticketRepository).save(captor.capture());
        assertEquals("GENERAL_ENQUIRY", captor.getValue().getCategory());
        assertEquals("MEDIUM", captor.getValue().getPriority());
        assertEquals("Support Request", captor.getValue().getTitle());
        assertEquals("No details provided.", captor.getValue().getDescription());
    }

    @Test
    void createTicketShouldRejectNonTrainer() {
        when(userRepository.findById(1L)).thenReturn(Optional.of(user(1L, "admin@example.com", "ADMINISTRATOR")));

        assertThrows(RuntimeException.class,
                () -> service.createTicket(1L, TicketCreateDTO.builder().title("Help").description("Desc").build()));
        verify(ticketRepository, never()).save(any());
    }

    // =================================================================
    // updateTicket
    // =================================================================

    @Test
    void updateTicketShouldThrowWhenTicketNotFound() {
        when(ticketRepository.findById(1L)).thenReturn(Optional.empty());

        assertThrows(RuntimeException.class,
                () -> service.updateTicket(1L, 1L, TicketCreateDTO.builder().build()));
    }

    @Test
    void updateTicketShouldThrowWhenCallerIsNotOwner() {
        Ticket t = ticket(1L, user(1L, "owner@example.com", "TRAINER"), "PENDING", "GENERAL_ENQUIRY");
        when(ticketRepository.findById(1L)).thenReturn(Optional.of(t));

        assertThrows(RuntimeException.class,
                () -> service.updateTicket(2L, 1L, TicketCreateDTO.builder().title("x").build()));
        verify(ticketRepository, never()).save(any());
    }

    @Test
    void updateTicketShouldUpdateTitleAndDescriptionWhenOwnerMatches() {
        Ticket t = ticket(1L, user(1L, "owner@example.com", "TRAINER"), "PENDING", "GENERAL_ENQUIRY");
        when(ticketRepository.findById(1L)).thenReturn(Optional.of(t));
        when(ticketRepository.save(any(Ticket.class))).thenAnswer(inv -> inv.getArgument(0));
        when(ticketMessageRepository.findByTicketIdOrderByCreatedAtAsc(1L)).thenReturn(List.of());

        service.updateTicket(1L, 1L, TicketCreateDTO.builder().title("New title").description("New desc").build());

        assertEquals("New title", t.getTitle());
        assertEquals("New desc", t.getDescription());
    }

    @Test
    void updateTicketShouldIgnoreBlankFields() {
        Ticket t = ticket(1L, user(1L, "owner@example.com", "TRAINER"), "PENDING", "GENERAL_ENQUIRY");
        when(ticketRepository.findById(1L)).thenReturn(Optional.of(t));
        when(ticketRepository.save(any(Ticket.class))).thenAnswer(inv -> inv.getArgument(0));
        when(ticketMessageRepository.findByTicketIdOrderByCreatedAtAsc(1L)).thenReturn(List.of());

        service.updateTicket(1L, 1L, TicketCreateDTO.builder().title("  ").description(null).build());

        assertEquals("Help needed", t.getTitle());
        assertEquals("Details", t.getDescription());
    }

    // =================================================================
    // getTicketDetail
    // =================================================================

    @Test
    void getTicketDetailShouldThrowWhenTicketNotFound() {
        when(ticketRepository.findById(1L)).thenReturn(Optional.empty());

        assertThrows(RuntimeException.class, () -> service.getTicketDetail(1L, 1L));
    }

    @Test
    void getTicketDetailShouldThrowWhenNonStaffCallerIsNotOwner() {
        Ticket t = ticket(1L, user(1L, "owner@example.com", "TRAINER"), "PENDING", "GENERAL_ENQUIRY");
        when(ticketRepository.findById(1L)).thenReturn(Optional.of(t));
        when(userRepository.findById(2L)).thenReturn(Optional.of(user(2L, "intruder@example.com", "TRAINER")));

        assertThrows(RuntimeException.class, () -> service.getTicketDetail(2L, 1L));
    }

    @Test
    void getTicketDetailShouldAllowOwner() {
        User owner = user(1L, "owner@example.com", "TRAINER");
        Ticket t = ticket(1L, owner, "PENDING", "GENERAL_ENQUIRY");
        when(ticketRepository.findById(1L)).thenReturn(Optional.of(t));
        when(userRepository.findById(1L)).thenReturn(Optional.of(owner));
        when(ticketMessageRepository.findByTicketIdOrderByCreatedAtAsc(1L)).thenReturn(List.of());

        TicketResponseDTO result = service.getTicketDetail(1L, 1L);

        assertEquals(1L, result.getId());
    }

    @Test
    void getTicketDetailShouldAllowStaffToViewAnotherUsersTicket() {
        Ticket t = ticket(1L, user(1L, "owner@example.com", "TRAINER"), "PENDING", "GENERAL_ENQUIRY");
        when(ticketRepository.findById(1L)).thenReturn(Optional.of(t));
        when(userRepository.findById(99L)).thenReturn(Optional.of(user(99L, "admin@example.com", "ADMINISTRATOR")));
        when(ticketMessageRepository.findByTicketIdOrderByCreatedAtAsc(1L)).thenReturn(List.of());

        TicketResponseDTO result = service.getTicketDetail(99L, 1L);

        assertEquals(1L, result.getId());
    }

    // =================================================================
    // getMyTickets
    // =================================================================

    @Test
    void getMyTicketsShouldQueryByUserIdOnlyWhenStatusNullOrAll() {
        Page<Ticket> page = new PageImpl<>(List.of(), PageRequest.of(0, 10), 0);
        when(ticketRepository.findByUserIdOrderByCreatedAtDesc(eq(1L), any(Pageable.class))).thenReturn(page);

        service.getMyTickets(1L, "all", PageRequest.of(0, 10));

        verify(ticketRepository).findByUserIdOrderByCreatedAtDesc(eq(1L), any(Pageable.class));
    }

    @Test
    void getMyTicketsShouldMapProcessedAliasToApprovedAndRejectedStatuses() {
        Page<Ticket> page = new PageImpl<>(List.of(), PageRequest.of(0, 10), 0);
        when(ticketRepository.findByUserIdAndStatusInOrderByCreatedAtDesc(eq(1L), eq(List.of("APPROVED", "REJECTED")), any(Pageable.class)))
                .thenReturn(page);

        service.getMyTickets(1L, "PROCESSED", PageRequest.of(0, 10));

        verify(ticketRepository).findByUserIdAndStatusInOrderByCreatedAtDesc(eq(1L), eq(List.of("APPROVED", "REJECTED")), any(Pageable.class));
    }

    @Test
    void getMyTicketsShouldQueryBySpecificStatusWhenProvided() {
        Page<Ticket> page = new PageImpl<>(List.of(), PageRequest.of(0, 10), 0);
        when(ticketRepository.findByUserIdAndStatusOrderByCreatedAtDesc(eq(1L), eq("PENDING"), any(Pageable.class)))
                .thenReturn(page);

        service.getMyTickets(1L, "pending", PageRequest.of(0, 10));

        verify(ticketRepository).findByUserIdAndStatusOrderByCreatedAtDesc(eq(1L), eq("PENDING"), any(Pageable.class));
    }

    // =================================================================
    // addMessage (Reply to Ticket)
    // =================================================================

    @Test
    void addMessageShouldThrowWhenTicketNotFound() {
        when(ticketRepository.findById(1L)).thenReturn(Optional.empty());

        assertThrows(RuntimeException.class, () -> service.addMessage(1L, 1L, "hi"));
    }

    @Test
    void addMessageShouldThrowWhenSenderNotFound() {
        Ticket t = ticket(1L, user(1L, "owner@example.com", "TRAINER"), "PENDING", "GENERAL_ENQUIRY");
        when(ticketRepository.findById(1L)).thenReturn(Optional.of(t));
        when(userRepository.findById(2L)).thenReturn(Optional.empty());

        assertThrows(RuntimeException.class, () -> service.addMessage(2L, 1L, "hi"));
    }

    @Test
    void addMessageShouldSaveMessageAndTouchTicketUpdatedAt() {
        Ticket t = ticket(1L, user(1L, "owner@example.com", "TRAINER"), "PENDING", "GENERAL_ENQUIRY");
        when(ticketRepository.findById(1L)).thenReturn(Optional.of(t));
        when(userRepository.findById(1L)).thenReturn(Optional.of(user(1L, "owner@example.com", "TRAINER")));
        when(ticketMessageRepository.save(any(TicketMessage.class))).thenAnswer(inv -> inv.getArgument(0));

        service.addMessage(1L, 1L, "Any update?");

        ArgumentCaptor<TicketMessage> captor = ArgumentCaptor.forClass(TicketMessage.class);
        verify(ticketMessageRepository).save(captor.capture());
        assertEquals("Any update?", captor.getValue().getMessage());
        assertEquals("TRAINER", captor.getValue().getSenderRole());
        verify(ticketRepository).save(t);
    }

    @Test
    void addMessageShouldFlipPendingTicketToProcessingWhenStaffReplies() {
        Ticket t = ticket(1L, user(1L, "owner@example.com", "TRAINER"), "PENDING", "GENERAL_ENQUIRY");
        when(ticketRepository.findById(1L)).thenReturn(Optional.of(t));
        when(userRepository.findById(99L)).thenReturn(Optional.of(user(99L, "admin@example.com", "ADMINISTRATOR")));
        when(ticketMessageRepository.save(any(TicketMessage.class))).thenAnswer(inv -> inv.getArgument(0));

        service.addMessage(99L, 1L, "Looking into it");

        assertEquals("PROCESSING", t.getStatus());
    }

    @Test
    void addMessageShouldKeepPendingStatusWhenTrainerRepliesToOwnTicket() {
        User owner = user(1L, "owner@example.com", "TRAINER");
        Ticket t = ticket(1L, owner, "PENDING", "GENERAL_ENQUIRY");
        when(ticketRepository.findById(1L)).thenReturn(Optional.of(t));
        when(userRepository.findById(1L)).thenReturn(Optional.of(owner));
        when(ticketMessageRepository.save(any(TicketMessage.class))).thenAnswer(inv -> inv.getArgument(0));

        service.addMessage(1L, 1L, "Any update on my issue?");

        assertEquals("PENDING", t.getStatus());
    }

    @Test
    void addMessageShouldNotChangeStatusWhenTicketAlreadyProcessing() {
        Ticket t = ticket(1L, user(1L, "owner@example.com", "TRAINER"), "PROCESSING", "GENERAL_ENQUIRY");
        when(ticketRepository.findById(1L)).thenReturn(Optional.of(t));
        when(userRepository.findById(99L)).thenReturn(Optional.of(user(99L, "admin@example.com", "ADMINISTRATOR")));
        when(ticketMessageRepository.save(any(TicketMessage.class))).thenAnswer(inv -> inv.getArgument(0));

        service.addMessage(99L, 1L, "Still looking");

        assertEquals("PROCESSING", t.getStatus());
    }

    @Test
    void addMessageShouldRejectAnotherTrainer() {
        Ticket t = ticket(1L, user(1L, "owner@example.com", "TRAINER"), "PENDING", "GENERAL_ENQUIRY");
        when(ticketRepository.findById(1L)).thenReturn(Optional.of(t));
        when(userRepository.findById(2L)).thenReturn(Optional.of(user(2L, "stranger@example.com", "TRAINER")));

        assertThrows(RuntimeException.class,
                () -> service.addMessage(2L, 1L, "I'm not the owner"));
        verify(ticketMessageRepository, never()).save(any());
    }

    // =================================================================
    // getManagementTickets
    // =================================================================

    @Test
    void getManagementTicketsShouldPassNullFiltersWhenStatusCategoryKeywordAllBlank() {
        Page<Ticket> page = new PageImpl<>(List.of(), PageRequest.of(0, 10), 0);
        when(ticketRepository.findAllFiltered(isNull(), isNull(), isNull(), any(Pageable.class))).thenReturn(page);

        service.getManagementTickets(null, null, null, null, PageRequest.of(0, 10));

        verify(ticketRepository).findAllFiltered(isNull(), isNull(), isNull(), any(Pageable.class));
    }

    @Test
    void getManagementTicketsShouldUppercaseStatusAndCategoryAndTrimKeyword() {
        Page<Ticket> page = new PageImpl<>(List.of(), PageRequest.of(0, 10), 0);
        when(ticketRepository.findAllFiltered(eq("PENDING"), eq("CONTENT_ISSUE"), eq("refund"), any(Pageable.class)))
                .thenReturn(page);

        service.getManagementTickets(null, "pending", "content_issue", "  refund  ", PageRequest.of(0, 10));

        verify(ticketRepository).findAllFiltered(eq("PENDING"), eq("CONTENT_ISSUE"), eq("refund"), any(Pageable.class));
    }

    @Test
    void getManagementTicketsShouldTreatAllStatusAsNoFilter() {
        Page<Ticket> page = new PageImpl<>(List.of(), PageRequest.of(0, 10), 0);
        when(ticketRepository.findAllFiltered(isNull(), isNull(), isNull(), any(Pageable.class))).thenReturn(page);

        service.getManagementTickets(1L, "ALL", "ALL", "", PageRequest.of(0, 10));

        verify(ticketRepository).findAllFiltered(isNull(), isNull(), isNull(), any(Pageable.class));
    }

    // =================================================================
    // processTicket
    // =================================================================

    @Test
    void processTicketShouldThrowWhenTicketNotFound() {
        when(ticketRepository.findById(1L)).thenReturn(Optional.empty());

        assertThrows(RuntimeException.class,
                () -> service.processTicket(99L, 1L, TicketProcessDTO.builder().action("APPROVE").build()));
    }

    @Test
    void processTicketShouldThrowWhenManagerNotFound() {
        Ticket t = ticket(1L, user(1L, "owner@example.com", "TRAINER"), "PENDING", "GENERAL_ENQUIRY");
        when(ticketRepository.findById(1L)).thenReturn(Optional.of(t));
        when(userRepository.findById(99L)).thenReturn(Optional.empty());

        assertThrows(RuntimeException.class,
                () -> service.processTicket(99L, 1L, TicketProcessDTO.builder().action("APPROVE").build()));
    }

    @Test
    void processTicketShouldRejectTrainerForPayoutInfoUpdateCategory() {
        Ticket t = ticket(1L, user(1L, "owner@example.com", "TRAINER"), "PENDING", "PAYOUT_INFO_UPDATE");
        when(ticketRepository.findById(1L)).thenReturn(Optional.of(t));
        when(userRepository.findById(99L)).thenReturn(Optional.of(user(99L, "trainer@example.com", "TRAINER")));

        assertThrows(RuntimeException.class,
                () -> service.processTicket(99L, 1L, TicketProcessDTO.builder().action("APPROVE").build()));
        verify(ticketRepository, never()).save(any());
    }

    @Test
    void processTicketShouldRejectTrainerForRefundRequestCategory() {
        Ticket t = ticket(1L, user(1L, "owner@example.com", "TRAINER"), "PENDING", "REFUND_REQUEST");
        when(ticketRepository.findById(1L)).thenReturn(Optional.of(t));
        when(userRepository.findById(99L)).thenReturn(Optional.of(user(99L, "trainer@example.com", "TRAINER")));

        assertThrows(RuntimeException.class,
                () -> service.processTicket(99L, 1L, TicketProcessDTO.builder().action("REJECT").build()));
    }

    @Test
    void processTicketShouldAllowAdminToProcessPayoutInfoUpdateCategory() {
        Ticket t = ticket(1L, user(1L, "owner@example.com", "TRAINER"), "PENDING", "PAYOUT_INFO_UPDATE");
        when(ticketRepository.findById(1L)).thenReturn(Optional.of(t));
        when(userRepository.findById(99L)).thenReturn(Optional.of(user(99L, "admin@example.com", "ADMINISTRATOR")));
        when(ticketRepository.save(any(Ticket.class))).thenAnswer(inv -> inv.getArgument(0));

        service.processTicket(99L, 1L, TicketProcessDTO.builder().action("APPROVE").build());

        assertEquals("APPROVED", t.getStatus());
    }

    @Test
    void processTicketShouldApproveWithDefaultResponseWhenNoneProvided() {
        Ticket t = ticket(1L, user(1L, "owner@example.com", "TRAINER"), "PENDING", "GENERAL_ENQUIRY");
        when(ticketRepository.findById(1L)).thenReturn(Optional.of(t));
        when(userRepository.findById(99L)).thenReturn(Optional.of(user(99L, "admin@example.com", "ADMINISTRATOR")));
        when(ticketRepository.save(any(Ticket.class))).thenAnswer(inv -> inv.getArgument(0));

        service.processTicket(99L, 1L, TicketProcessDTO.builder().action("APPROVE").build());

        assertEquals("APPROVED", t.getStatus());
        assertEquals("Ticket approved by administrator.", t.getAdminResponse());
        verify(notificationService).notifyUser(eq(t.getUser()), eq("TicketReviewed"), any(), any(), isNull());
    }

    @Test
    void processTicketShouldApproveWithCustomAdminResponseWhenProvided() {
        Ticket t = ticket(1L, user(1L, "owner@example.com", "TRAINER"), "PENDING", "GENERAL_ENQUIRY");
        when(ticketRepository.findById(1L)).thenReturn(Optional.of(t));
        when(userRepository.findById(99L)).thenReturn(Optional.of(user(99L, "admin@example.com", "ADMINISTRATOR")));
        when(ticketRepository.save(any(Ticket.class))).thenAnswer(inv -> inv.getArgument(0));

        service.processTicket(99L, 1L,
                TicketProcessDTO.builder().action("APPROVE").adminResponse("Fixed the bug").build());

        assertEquals("Fixed the bug", t.getAdminResponse());
    }

    @Test
    void processTicketShouldRejectAndSetRejectionReason() {
        Ticket t = ticket(1L, user(1L, "owner@example.com", "TRAINER"), "PENDING", "GENERAL_ENQUIRY");
        when(ticketRepository.findById(1L)).thenReturn(Optional.of(t));
        when(userRepository.findById(99L)).thenReturn(Optional.of(user(99L, "admin@example.com", "ADMINISTRATOR")));
        when(ticketRepository.save(any(Ticket.class))).thenAnswer(inv -> inv.getArgument(0));

        service.processTicket(99L, 1L,
                TicketProcessDTO.builder().action("REJECT").rejectionReason("Not a valid ticket").build());

        assertEquals("REJECTED", t.getStatus());
        assertEquals("Not a valid ticket", t.getRejectionReason());
        assertEquals(null, t.getAdminResponse());
    }

    @Test
    void processTicketShouldRecordAdministrator() {
        Ticket t = ticket(1L, user(1L, "owner@example.com", "TRAINER"), "PENDING", "GENERAL_ENQUIRY");
        User administrator = user(99L, "admin@example.com", "ADMINISTRATOR");
        when(ticketRepository.findById(1L)).thenReturn(Optional.of(t));
        when(userRepository.findById(99L)).thenReturn(Optional.of(administrator));
        when(ticketRepository.save(any(Ticket.class))).thenAnswer(inv -> inv.getArgument(0));

        service.processTicket(99L, 1L, TicketProcessDTO.builder().action("APPROVE").build());

        assertEquals(administrator, t.getProcessedBy());
        verify(ticketMessageRepository, never()).save(any());
    }

    // =================================================================
    // getTicketStats
    // =================================================================

    @Test
    void getTicketStatsShouldMapCountsPerStatus() {
        when(ticketRepository.count()).thenReturn(10L);
        when(ticketRepository.countByStatus("PENDING")).thenReturn(3L);
        when(ticketRepository.countByStatus("PROCESSING")).thenReturn(2L);
        when(ticketRepository.countByStatus("APPROVED")).thenReturn(4L);
        when(ticketRepository.countByStatus("REJECTED")).thenReturn(1L);

        Map<String, Object> result = service.getTicketStats();

        assertEquals(10L, result.get("total"));
        assertEquals(3L, result.get("pending"));
        assertEquals(2L, result.get("processing"));
        assertEquals(4L, result.get("approved"));
        assertEquals(1L, result.get("rejected"));
    }
}
