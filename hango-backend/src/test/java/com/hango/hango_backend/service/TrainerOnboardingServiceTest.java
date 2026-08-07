package com.hango.hango_backend.service;

import java.time.LocalDateTime;
import java.util.HashSet;
import java.util.List;
import java.util.Optional;
import java.util.Set;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyString;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.security.core.userdetails.UsernameNotFoundException;

import com.hango.hango_backend.dto.LoginResponse;
import com.hango.hango_backend.dto.TrainerProfileDTO;
import com.hango.hango_backend.dto.TrainerReviewRequest;
import com.hango.hango_backend.entity.Role;
import com.hango.hango_backend.entity.TrainerProfile;
import com.hango.hango_backend.entity.User;
import com.hango.hango_backend.repository.RoleRepository;
import com.hango.hango_backend.repository.TrainerProfileRepository;
import com.hango.hango_backend.repository.UserRepository;
import com.hango.hango_backend.util.JwtUtils;

@ExtendWith(MockitoExtension.class)
class TrainerOnboardingServiceTest {

    @Mock
    private UserRepository userRepository;
    @Mock
    private RoleRepository roleRepository;
    @Mock
    private TrainerProfileRepository trainerProfileRepository;
    @Mock
    private JwtUtils jwtUtils;
    @Mock
    private EmailService emailService;

    @InjectMocks
    private TrainerOnboardingServiceImpl service;

    private User learnerUser(Long id, String email) {
        return User.builder()
                .id(id)
                .email(email)
                .fullName("Learner User")
                .roles(new HashSet<>(Set.of(Role.builder().id(1L).roleName("LEARNER").build())))
                .build();
    }

    private TrainerProfile profile(Long userId, String status, String trainerType) {
        return TrainerProfile.builder()
                .userId(userId)
                .trainerType(trainerType)
                .revenueShare(0.70)
                .status(status)
                .build();
    }

    // =================================================================
    // becomeTrainer
    // =================================================================

    @Test
    void becomeTrainerShouldThrowWhenUserNotFound() {
        when(userRepository.findByEmail("unknown@example.com")).thenReturn(Optional.empty());
        assertThrows(UsernameNotFoundException.class,
                () -> service.becomeTrainer("unknown@example.com", "PROFESSIONAL"));
    }

    @Test
    void becomeTrainerShouldGrantTrainerRoleAndCreateProfileForProfessional() {
        User user = learnerUser(1L, "known@example.com");
        when(userRepository.findByEmail("known@example.com")).thenReturn(Optional.of(user));
        when(roleRepository.findByRoleName("TRAINER"))
                .thenReturn(Optional.of(Role.builder().id(2L).roleName("TRAINER").build()));
        when(userRepository.save(any(User.class))).thenAnswer(inv -> inv.getArgument(0));
        when(trainerProfileRepository.findById(1L)).thenReturn(Optional.empty());
        when(trainerProfileRepository.save(any(TrainerProfile.class))).thenAnswer(inv -> inv.getArgument(0));
        when(jwtUtils.generateJwtTokenFromUsername("known@example.com")).thenReturn("trainer-jwt-token");

        LoginResponse response = service.becomeTrainer("known@example.com", "PROFESSIONAL");

        assertEquals("trainer-jwt-token", response.getToken());
        assertTrue(response.getRoles().contains("TRAINER"));
        assertTrue(user.getRoles().stream().anyMatch(r -> r.getRoleName().equals("TRAINER")));

        var captor = org.mockito.ArgumentCaptor.forClass(TrainerProfile.class);
        verify(trainerProfileRepository).save(captor.capture());
        assertEquals("PROFESSIONAL", captor.getValue().getTrainerType());
        assertEquals(0.70, captor.getValue().getRevenueShare());
        assertEquals("PENDING_VERIFICATION", captor.getValue().getStatus());
    }

    @Test
    void becomeTrainerShouldUseSixtyPercentShareForPeerTutor() {
        User user = learnerUser(1L, "known@example.com");
        when(userRepository.findByEmail("known@example.com")).thenReturn(Optional.of(user));
        when(roleRepository.findByRoleName("TRAINER"))
                .thenReturn(Optional.of(Role.builder().id(2L).roleName("TRAINER").build()));
        when(userRepository.save(any(User.class))).thenAnswer(inv -> inv.getArgument(0));
        when(trainerProfileRepository.findById(1L)).thenReturn(Optional.empty());
        when(trainerProfileRepository.save(any(TrainerProfile.class))).thenAnswer(inv -> inv.getArgument(0));
        when(jwtUtils.generateJwtTokenFromUsername(anyString())).thenReturn("trainer-jwt-token");

        service.becomeTrainer("known@example.com", "PEER_TUTOR");

        var captor = org.mockito.ArgumentCaptor.forClass(TrainerProfile.class);
        verify(trainerProfileRepository).save(captor.capture());
        assertEquals(0.60, captor.getValue().getRevenueShare());
    }

    @Test
    void becomeTrainerShouldCreateTrainerRoleWhenItDoesNotExistYet() {
        User user = learnerUser(1L, "known@example.com");
        when(userRepository.findByEmail("known@example.com")).thenReturn(Optional.of(user));
        when(roleRepository.findByRoleName("TRAINER")).thenReturn(Optional.empty());
        when(roleRepository.save(any(Role.class))).thenAnswer(inv -> inv.getArgument(0));
        when(userRepository.save(any(User.class))).thenAnswer(inv -> inv.getArgument(0));
        when(trainerProfileRepository.findById(1L)).thenReturn(Optional.empty());
        when(trainerProfileRepository.save(any(TrainerProfile.class))).thenAnswer(inv -> inv.getArgument(0));
        when(jwtUtils.generateJwtTokenFromUsername(anyString())).thenReturn("trainer-jwt-token");

        service.becomeTrainer("known@example.com", "PROFESSIONAL");

        var captor = org.mockito.ArgumentCaptor.forClass(Role.class);
        verify(roleRepository).save(captor.capture());
        assertEquals("TRAINER", captor.getValue().getRoleName());
    }

    @Test
    void becomeTrainerShouldUpdateTrainerTypeWhenProfileStillPendingVerification() {
        User user = learnerUser(1L, "known@example.com");
        user.getRoles().add(Role.builder().id(2L).roleName("TRAINER").build());
        when(userRepository.findByEmail("known@example.com")).thenReturn(Optional.of(user));
        when(roleRepository.findByRoleName("TRAINER"))
                .thenReturn(Optional.of(Role.builder().id(2L).roleName("TRAINER").build()));
        TrainerProfile existing = profile(1L, "PENDING_VERIFICATION", "PROFESSIONAL");
        when(trainerProfileRepository.findById(1L)).thenReturn(Optional.of(existing));
        when(trainerProfileRepository.save(any(TrainerProfile.class))).thenAnswer(inv -> inv.getArgument(0));
        when(jwtUtils.generateJwtTokenFromUsername(anyString())).thenReturn("trainer-jwt-token");

        service.becomeTrainer("known@example.com", "PEER_TUTOR");

        assertEquals("PEER_TUTOR", existing.getTrainerType());
        assertEquals(0.60, existing.getRevenueShare());
        verify(userRepository, never()).save(any());
    }

    @Test
    void becomeTrainerShouldNotChangeTrainerTypeWhenProfileAlreadyVerified() {
        User user = learnerUser(1L, "known@example.com");
        user.getRoles().add(Role.builder().id(2L).roleName("TRAINER").build());
        when(userRepository.findByEmail("known@example.com")).thenReturn(Optional.of(user));
        TrainerProfile existing = profile(1L, "VERIFIED", "PROFESSIONAL");
        when(trainerProfileRepository.findById(1L)).thenReturn(Optional.of(existing));
        when(jwtUtils.generateJwtTokenFromUsername(anyString())).thenReturn("trainer-jwt-token");

        service.becomeTrainer("known@example.com", "PEER_TUTOR");

        assertEquals("PROFESSIONAL", existing.getTrainerType());
        verify(trainerProfileRepository, never()).save(any());
    }

    @Test
    void becomeTrainerShouldLeaveProfileUnchangedWhenTrainerTypeIsNullAndProfileExists() {
        User user = learnerUser(1L, "known@example.com");
        user.getRoles().add(Role.builder().id(2L).roleName("TRAINER").build());
        when(userRepository.findByEmail("known@example.com")).thenReturn(Optional.of(user));
        TrainerProfile existing = profile(1L, "PENDING_VERIFICATION", "PROFESSIONAL");
        when(trainerProfileRepository.findById(1L)).thenReturn(Optional.of(existing));
        when(jwtUtils.generateJwtTokenFromUsername(anyString())).thenReturn("trainer-jwt-token");

        service.becomeTrainer("known@example.com", null);

        assertEquals("PROFESSIONAL", existing.getTrainerType());
        verify(trainerProfileRepository, never()).save(any());
    }

    @Test
    void becomeTrainerShouldThrowNullPointerExceptionWhenTrainerTypeIsNullAndNoProfileExists() {
        User user = learnerUser(1L, "known@example.com");
        user.getRoles().add(Role.builder().id(2L).roleName("TRAINER").build());
        when(userRepository.findByEmail("known@example.com")).thenReturn(Optional.of(user));
        when(trainerProfileRepository.findById(1L)).thenReturn(Optional.empty());

        assertThrows(NullPointerException.class, () -> service.becomeTrainer("known@example.com", null));
    }

    // =================================================================
    // getTrainerProfile
    // =================================================================

    @Test
    void getTrainerProfileShouldThrowWhenUserNotFound() {
        when(userRepository.findByEmail("unknown@example.com")).thenReturn(Optional.empty());
        assertThrows(UsernameNotFoundException.class, () -> service.getTrainerProfile("unknown@example.com"));
    }

    @Test
    void getTrainerProfileShouldReturnExistingProfile() {
        User user = learnerUser(1L, "known@example.com");
        when(userRepository.findByEmail("known@example.com")).thenReturn(Optional.of(user));
        when(trainerProfileRepository.findById(1L)).thenReturn(Optional.of(profile(1L, "VERIFIED", "PROFESSIONAL")));

        TrainerProfileDTO dto = service.getTrainerProfile("known@example.com");

        assertEquals("VERIFIED", dto.getStatus());
        assertEquals("N/A", dto.getFullName());
        assertEquals("N/A", dto.getEmail());
        assertNull(dto.getGender());
        verify(trainerProfileRepository, never()).save(any());
    }

    @Test
    void getTrainerProfileShouldJitCreateDefaultProfileWhenMissing() {
        User user = learnerUser(1L, "known@example.com");
        when(userRepository.findByEmail("known@example.com")).thenReturn(Optional.of(user));
        when(trainerProfileRepository.findById(1L)).thenReturn(Optional.empty());
        when(trainerProfileRepository.save(any(TrainerProfile.class))).thenAnswer(inv -> inv.getArgument(0));

        TrainerProfileDTO dto = service.getTrainerProfile("known@example.com");

        assertEquals("PENDING_VERIFICATION", dto.getStatus());
        assertEquals(0.70, dto.getRevenueShare());
        assertNull(dto.getTrainerType());
        verify(trainerProfileRepository).save(any(TrainerProfile.class));
    }

    // =================================================================
    // saveProfileDraft
    // =================================================================

    @Test
    void saveProfileDraftShouldThrowWhenUserNotFound() {
        when(userRepository.findByEmail("unknown@example.com")).thenReturn(Optional.empty());
        assertThrows(UsernameNotFoundException.class,
                () -> service.saveProfileDraft("unknown@example.com", new TrainerProfileDTO()));
    }

    @Test
    void saveProfileDraftShouldThrowWhenProfileNotFound() {
        User user = learnerUser(1L, "known@example.com");
        when(userRepository.findByEmail("known@example.com")).thenReturn(Optional.of(user));
        when(trainerProfileRepository.findById(1L)).thenReturn(Optional.empty());

        assertThrows(IllegalArgumentException.class,
                () -> service.saveProfileDraft("known@example.com", new TrainerProfileDTO()));
    }

    @Test
    void saveProfileDraftShouldRejectEditWhenAwaitingApproval() {
        User user = learnerUser(1L, "known@example.com");
        when(userRepository.findByEmail("known@example.com")).thenReturn(Optional.of(user));
        when(trainerProfileRepository.findById(1L)).thenReturn(Optional.of(profile(1L, "AWAITING_APPROVAL", "PROFESSIONAL")));

        IllegalStateException ex = assertThrows(IllegalStateException.class,
                () -> service.saveProfileDraft("known@example.com", new TrainerProfileDTO()));
        assertTrue(ex.getMessage().contains("chờ duyệt"));
    }

    @Test
    void saveProfileDraftShouldRejectEditWhenSuspended() {
        User user = learnerUser(1L, "known@example.com");
        when(userRepository.findByEmail("known@example.com")).thenReturn(Optional.of(user));
        when(trainerProfileRepository.findById(1L)).thenReturn(Optional.of(profile(1L, "SUSPENDED", "PROFESSIONAL")));

        IllegalStateException ex = assertThrows(IllegalStateException.class,
                () -> service.saveProfileDraft("known@example.com", new TrainerProfileDTO()));
        assertTrue(ex.getMessage().contains("đình chỉ"));
    }

    @Test
    void saveProfileDraftShouldOnlyUpdateFieldsPresentOnDto() {
        User user = learnerUser(1L, "known@example.com");
        when(userRepository.findByEmail("known@example.com")).thenReturn(Optional.of(user));
        TrainerProfile existing = profile(1L, "PENDING_VERIFICATION", "PROFESSIONAL");
        existing.setWorkplace("Old Workplace");
        when(trainerProfileRepository.findById(1L)).thenReturn(Optional.of(existing));
        when(userRepository.save(any(User.class))).thenAnswer(inv -> inv.getArgument(0));
        when(trainerProfileRepository.save(any(TrainerProfile.class))).thenAnswer(inv -> inv.getArgument(0));

        TrainerProfileDTO dto = new TrainerProfileDTO();
        dto.setBio("New bio");

        TrainerProfileDTO result = service.saveProfileDraft("known@example.com", dto);

        assertEquals("New bio", result.getBio());
        assertEquals("Old Workplace", result.getWorkplace());
    }

    @Test
    void saveProfileDraftShouldAlsoUpdateUserLevelFields() {
        User user = learnerUser(1L, "known@example.com");
        when(userRepository.findByEmail("known@example.com")).thenReturn(Optional.of(user));
        TrainerProfile existing = profile(1L, "PENDING_VERIFICATION", "PROFESSIONAL");
        existing.setUser(user);
        when(trainerProfileRepository.findById(1L)).thenReturn(Optional.of(existing));
        when(userRepository.save(any(User.class))).thenAnswer(inv -> inv.getArgument(0));
        when(trainerProfileRepository.save(any(TrainerProfile.class))).thenAnswer(inv -> inv.getArgument(0));

        TrainerProfileDTO dto = new TrainerProfileDTO();
        dto.setPhoneNumber("0909123456");
        dto.setAvatarUrl("https://cloudinary.example/avatar.png");

        service.saveProfileDraft("known@example.com", dto);

        assertEquals("0909123456", user.getPhoneNumber());
        assertEquals("https://cloudinary.example/avatar.png", user.getAvatarUrl());
        verify(userRepository).save(user);
    }

    // =================================================================
    // submitProfileForReview
    // =================================================================

    private TrainerProfile completeProfile(Long userId) {
        TrainerProfile p = profile(userId, "PENDING_VERIFICATION", "PROFESSIONAL");
        p.setBio("Experienced teacher");
        p.setScoreReportUrl("https://cloudinary.example/degree.pdf");
        return p;
    }

    @Test
    void submitProfileForReviewShouldThrowWhenUserNotFound() {
        when(userRepository.findByEmail("unknown@example.com")).thenReturn(Optional.empty());
        assertThrows(UsernameNotFoundException.class,
                () -> service.submitProfileForReview("unknown@example.com", new TrainerProfileDTO()));
    }

    @Test
    void submitProfileForReviewShouldThrowWhenProfileNotFound() {
        User user = learnerUser(1L, "known@example.com");
        when(userRepository.findByEmail("known@example.com")).thenReturn(Optional.of(user));
        when(trainerProfileRepository.findById(1L)).thenReturn(Optional.empty());

        assertThrows(IllegalArgumentException.class,
                () -> service.submitProfileForReview("known@example.com", new TrainerProfileDTO()));
    }

    @Test
    void submitProfileForReviewShouldRejectWhenAlreadyAwaitingApproval() {
        User user = learnerUser(1L, "known@example.com");
        when(userRepository.findByEmail("known@example.com")).thenReturn(Optional.of(user));
        when(trainerProfileRepository.findById(1L)).thenReturn(Optional.of(profile(1L, "AWAITING_APPROVAL", "PROFESSIONAL")));

        assertThrows(IllegalStateException.class,
                () -> service.submitProfileForReview("known@example.com", new TrainerProfileDTO()));
    }

    @Test
    void submitProfileForReviewShouldRejectMissingBio() {
        User user = learnerUser(1L, "known@example.com");
        when(userRepository.findByEmail("known@example.com")).thenReturn(Optional.of(user));
        TrainerProfile incomplete = profile(1L, "PENDING_VERIFICATION", "PROFESSIONAL");
        when(trainerProfileRepository.findById(1L)).thenReturn(Optional.of(incomplete));
        when(trainerProfileRepository.save(any(TrainerProfile.class))).thenAnswer(inv -> inv.getArgument(0));
        when(userRepository.save(any(User.class))).thenAnswer(inv -> inv.getArgument(0));

        IllegalArgumentException ex = assertThrows(IllegalArgumentException.class,
                () -> service.submitProfileForReview("known@example.com", new TrainerProfileDTO()));
        assertTrue(ex.getMessage().toLowerCase().contains("bio"));
    }

    @Test
    void submitProfileForReviewShouldRejectMissingPhoneNumber() {
        User user = learnerUser(1L, "known@example.com");
        when(userRepository.findByEmail("known@example.com")).thenReturn(Optional.of(user));
        TrainerProfile incomplete = profile(1L, "PENDING_VERIFICATION", "PROFESSIONAL");
        incomplete.setBio("Experienced teacher with over 5 years of IELTS academic teaching history");
        when(trainerProfileRepository.findById(1L)).thenReturn(Optional.of(incomplete));
        when(trainerProfileRepository.save(any(TrainerProfile.class))).thenAnswer(inv -> inv.getArgument(0));
        when(userRepository.save(any(User.class))).thenAnswer(inv -> inv.getArgument(0));

        IllegalArgumentException ex = assertThrows(IllegalArgumentException.class,
                () -> service.submitProfileForReview("known@example.com", new TrainerProfileDTO()));
        assertTrue(ex.getMessage().toLowerCase().contains("phone"));
    }

    @Test
    void submitProfileForReviewShouldRejectMissingAllCertificationDocuments() {
        User user = learnerUser(1L, "known@example.com");
        user.setPhoneNumber("0909123456");
        user.setGender("MALE");
        user.setAvatarUrl("https://cloudinary.example/avatar.png");
        when(userRepository.findByEmail("known@example.com")).thenReturn(Optional.of(user));
        TrainerProfile incomplete = profile(1L, "PENDING_VERIFICATION", "PROFESSIONAL");
        incomplete.setBio("Experienced teacher with over 5 years of IELTS academic teaching history");
        when(trainerProfileRepository.findById(1L)).thenReturn(Optional.of(incomplete));
        when(trainerProfileRepository.save(any(TrainerProfile.class))).thenAnswer(inv -> inv.getArgument(0));
        when(userRepository.save(any(User.class))).thenAnswer(inv -> inv.getArgument(0));

        IllegalArgumentException ex = assertThrows(IllegalArgumentException.class,
                () -> service.submitProfileForReview("known@example.com", new TrainerProfileDTO()));
        assertTrue(ex.getMessage().toLowerCase().contains("proof"));
    }

    @Test
    void submitProfileForReviewShouldMarkAwaitingApprovalWhenAllRequiredFieldsPresent() {
        User user = learnerUser(1L, "known@example.com");
        user.setPhoneNumber("0909123456");
        user.setGender("MALE");
        user.setAvatarUrl("https://cloudinary.example/avatar.png");
        when(userRepository.findByEmail("known@example.com")).thenReturn(Optional.of(user));
        TrainerProfile complete = completeProfile(1L);
        complete.setBio("Experienced teacher with over 5 years of IELTS academic teaching history");
        complete.setAdminNotes("previous rejection reason");
        when(trainerProfileRepository.findById(1L)).thenReturn(Optional.of(complete));
        when(trainerProfileRepository.save(any(TrainerProfile.class))).thenAnswer(inv -> inv.getArgument(0));
        when(userRepository.save(any(User.class))).thenAnswer(inv -> inv.getArgument(0));

        TrainerProfileDTO result = service.submitProfileForReview("known@example.com", new TrainerProfileDTO());

        assertEquals("AWAITING_APPROVAL", result.getStatus());
        assertNotNull(complete.getSubmittedAt());
        assertNull(complete.getAdminNotes());
    }

    // =================================================================
    // getTrainerProfilesForAdmin
    // =================================================================

    @Test
    void getTrainerProfilesForAdminShouldReturnAllWhenStatusIsAll() {
        TrainerProfile p1 = profile(1L, "VERIFIED", "PROFESSIONAL");
        TrainerProfile p2 = profile(2L, "PENDING_VERIFICATION", "PEER_TUTOR");
        when(trainerProfileRepository.findAll()).thenReturn(List.of(p1, p2));

        List<TrainerProfileDTO> result = service.getTrainerProfilesForAdmin(null, "ALL");

        assertEquals(2, result.size());
    }

    @Test
    void getTrainerProfilesForAdminShouldFilterByStatus() {
        TrainerProfile p1 = profile(1L, "VERIFIED", "PROFESSIONAL");
        TrainerProfile p2 = profile(2L, "PENDING_VERIFICATION", "PEER_TUTOR");
        when(trainerProfileRepository.findAll()).thenReturn(List.of(p1, p2));

        List<TrainerProfileDTO> result = service.getTrainerProfilesForAdmin(null, "VERIFIED");

        assertEquals(1, result.size());
        assertEquals("VERIFIED", result.get(0).getStatus());
    }

    @Test
    void getTrainerProfilesForAdminShouldFilterBySearchTextOnNameOrEmail() {
        User u1 = learnerUser(1L, "alice@example.com");
        u1.setFullName("Alice Trainer");
        TrainerProfile p1 = profile(1L, "VERIFIED", "PROFESSIONAL");
        p1.setUser(u1);
        User u2 = learnerUser(2L, "bob@example.com");
        u2.setFullName("Bob Trainer");
        TrainerProfile p2 = profile(2L, "VERIFIED", "PROFESSIONAL");
        p2.setUser(u2);
        when(trainerProfileRepository.findAll()).thenReturn(List.of(p1, p2));

        List<TrainerProfileDTO> result = service.getTrainerProfilesForAdmin("alice", "ALL");

        assertEquals(1, result.size());
        assertEquals("alice@example.com", result.get(0).getEmail());
    }

    @Test
    void getTrainerProfilesForAdminShouldReturnEmptyWhenNoMatch() {
        when(trainerProfileRepository.findAll()).thenReturn(List.of(profile(1L, "VERIFIED", "PROFESSIONAL")));

        List<TrainerProfileDTO> result = service.getTrainerProfilesForAdmin("nomatch", "ALL");

        assertTrue(result.isEmpty());
    }

    @Test
    void getTrainerProfilesForAdminShouldSortNewestSubmittedFirstAndPushNullsLast() {
        TrainerProfile older = profile(1L, "AWAITING_APPROVAL", "PROFESSIONAL");
        older.setSubmittedAt(LocalDateTime.now().minusDays(2));
        TrainerProfile newer = profile(2L, "AWAITING_APPROVAL", "PROFESSIONAL");
        newer.setSubmittedAt(LocalDateTime.now());
        TrainerProfile neverSubmitted = profile(3L, "PENDING_VERIFICATION", "PROFESSIONAL");
        when(trainerProfileRepository.findAll()).thenReturn(List.of(older, neverSubmitted, newer));

        List<TrainerProfileDTO> result = service.getTrainerProfilesForAdmin(null, "ALL");

        assertEquals(2L, result.get(0).getUserId());
        assertEquals(1L, result.get(1).getUserId());
        assertEquals(3L, result.get(2).getUserId());
    }

    // =================================================================
    // reviewTrainerProfile
    // =================================================================

    @Test
    void reviewTrainerProfileShouldThrowWhenProfileNotFound() {
        when(trainerProfileRepository.findById(99L)).thenReturn(Optional.empty());

        TrainerReviewRequest req = new TrainerReviewRequest();
        req.setStatus("VERIFIED");

        assertThrows(IllegalArgumentException.class, () -> service.reviewTrainerProfile(99L, req));
    }

    @Test
    void reviewTrainerProfileShouldUseAdminProvidedRevenueShareWhenVerifying() {
        TrainerProfile p = profile(1L, "AWAITING_APPROVAL", "PROFESSIONAL");
        when(trainerProfileRepository.findById(1L)).thenReturn(Optional.of(p));
        when(trainerProfileRepository.save(any(TrainerProfile.class))).thenAnswer(inv -> inv.getArgument(0));

        TrainerReviewRequest req = new TrainerReviewRequest();
        req.setStatus("VERIFIED");
        req.setRevenueShare(0.75);
        req.setAdminNotes("Custom rate approved");

        TrainerProfileDTO result = service.reviewTrainerProfile(1L, req);

        assertEquals("VERIFIED", result.getStatus());
        assertEquals(0.75, result.getRevenueShare());
        assertNotNull(p.getReviewedAt());
        verify(emailService, never()).sendTrainerStatusNotificationEmail(anyString(), anyString(), any());
    }

    @Test
    void reviewTrainerProfileShouldDefaultToSeventyPercentForProfessionalWhenNoRevenueShareGiven() {
        TrainerProfile p = profile(1L, "AWAITING_APPROVAL", "PROFESSIONAL");
        when(trainerProfileRepository.findById(1L)).thenReturn(Optional.of(p));
        when(trainerProfileRepository.save(any(TrainerProfile.class))).thenAnswer(inv -> inv.getArgument(0));

        TrainerReviewRequest req = new TrainerReviewRequest();
        req.setStatus("VERIFIED");

        TrainerProfileDTO result = service.reviewTrainerProfile(1L, req);

        assertEquals(0.70, result.getRevenueShare());
    }

    @Test
    void reviewTrainerProfileShouldDefaultToSixtyPercentForPeerTutorWhenNoRevenueShareGiven() {
        TrainerProfile p = profile(1L, "AWAITING_APPROVAL", "PEER_TUTOR");
        when(trainerProfileRepository.findById(1L)).thenReturn(Optional.of(p));
        when(trainerProfileRepository.save(any(TrainerProfile.class))).thenAnswer(inv -> inv.getArgument(0));

        TrainerReviewRequest req = new TrainerReviewRequest();
        req.setStatus("VERIFIED");

        TrainerProfileDTO result = service.reviewTrainerProfile(1L, req);

        assertEquals(0.60, result.getRevenueShare());
    }

    @Test
    void reviewTrainerProfileShouldNotRecalculateRevenueShareWhenSuspending() {
        TrainerProfile p = profile(1L, "VERIFIED", "PROFESSIONAL");
        p.setRevenueShare(0.70);
        when(trainerProfileRepository.findById(1L)).thenReturn(Optional.of(p));
        when(trainerProfileRepository.save(any(TrainerProfile.class))).thenAnswer(inv -> inv.getArgument(0));

        TrainerReviewRequest req = new TrainerReviewRequest();
        req.setStatus("SUSPENDED");
        req.setAdminNotes("Fraudulent documents");

        TrainerProfileDTO result = service.reviewTrainerProfile(1L, req);

        assertEquals("SUSPENDED", result.getStatus());
        assertEquals(0.70, result.getRevenueShare());
    }

    @Test
    void reviewTrainerProfileShouldSendStatusNotificationEmailWhenUserPresent() {
        User user = learnerUser(1L, "trainer@example.com");
        TrainerProfile p = profile(1L, "AWAITING_APPROVAL", "PROFESSIONAL");
        p.setUser(user);
        when(trainerProfileRepository.findById(1L)).thenReturn(Optional.of(p));
        when(trainerProfileRepository.save(any(TrainerProfile.class))).thenAnswer(inv -> inv.getArgument(0));

        TrainerReviewRequest req = new TrainerReviewRequest();
        req.setStatus("VERIFIED");
        req.setAdminNotes("Welcome aboard");

        service.reviewTrainerProfile(1L, req);

        verify(emailService).sendTrainerStatusNotificationEmail("trainer@example.com", "VERIFIED", "Welcome aboard");
    }
}
