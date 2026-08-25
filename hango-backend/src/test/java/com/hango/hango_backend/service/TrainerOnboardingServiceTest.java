package com.hango.hango_backend.service;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.hango.hango_backend.dto.LoginResponse;
import com.hango.hango_backend.dto.TrainerDocumentDTO;
import com.hango.hango_backend.dto.TrainerProfileDTO;
import com.hango.hango_backend.dto.TrainerReviewRequest;
import com.hango.hango_backend.entity.Role;
import com.hango.hango_backend.entity.TrainerProfile;
import com.hango.hango_backend.entity.User;
import com.hango.hango_backend.exception.ApiException;
import com.hango.hango_backend.repository.RoleRepository;
import com.hango.hango_backend.repository.TrainerProfileRepository;
import com.hango.hango_backend.repository.UserRepository;
import com.hango.hango_backend.util.JwtUtils;
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
import org.mockito.Spy;
import org.springframework.http.HttpStatus;
import org.springframework.security.core.userdetails.UsernameNotFoundException;
import org.springframework.transaction.support.TransactionSynchronization;
import org.springframework.transaction.support.TransactionSynchronizationManager;

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
    @Mock
    private NotificationService notificationService;
    @Mock
    private org.springframework.jdbc.core.JdbcTemplate jdbcTemplate;
    @Spy
    private ObjectMapper objectMapper = new ObjectMapper();

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

    private User adminUser(Long id, String email) {
        return User.builder()
                .id(id)
                .email(email)
                .fullName("Admin User")
                .roles(new HashSet<>(Set.of(Role.builder().id(9L).roleName("ADMINISTRATOR").build())))
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
        when(trainerProfileRepository.save(any(TrainerProfile.class))).thenAnswer(inv -> inv.getArgument(0));
        when(jwtUtils.generateJwtTokenFromUsername(anyString())).thenReturn("trainer-jwt-token");

        service.becomeTrainer("known@example.com", null);

        assertEquals("PROFESSIONAL", existing.getTrainerType());
        assertEquals(0.70, existing.getRevenueShare());
        verify(trainerProfileRepository).save(existing);
    }

    @Test
    void becomeTrainerShouldDefaultMissingTrainerTypeToProfessionalWhenNoProfileExists() {
        User user = learnerUser(1L, "known@example.com");
        user.getRoles().add(Role.builder().id(2L).roleName("TRAINER").build());
        when(userRepository.findByEmail("known@example.com")).thenReturn(Optional.of(user));
        when(trainerProfileRepository.findById(1L)).thenReturn(Optional.empty());
        when(trainerProfileRepository.save(any(TrainerProfile.class))).thenAnswer(inv -> inv.getArgument(0));
        when(jwtUtils.generateJwtTokenFromUsername(anyString())).thenReturn("trainer-jwt-token");

        service.becomeTrainer("known@example.com", null);

        var captor = org.mockito.ArgumentCaptor.forClass(TrainerProfile.class);
        verify(trainerProfileRepository).save(captor.capture());
        assertEquals("PROFESSIONAL", captor.getValue().getTrainerType());
        assertEquals(0.70, captor.getValue().getRevenueShare());
    }

    @Test
    void becomeTrainerShouldRejectUnsupportedTrainerType() {
        User user = learnerUser(1L, "known@example.com");
        when(userRepository.findByEmail("known@example.com")).thenReturn(Optional.of(user));

        ApiException ex = assertThrows(ApiException.class,
                () -> service.becomeTrainer("known@example.com", "MENTOR"));
        assertEquals(HttpStatus.BAD_REQUEST, ex.getStatus());
        assertTrue(ex.getMessage().contains("trainerType"));
    }

    @Test
    void becomeTrainerShouldRejectNonLearnerNonTrainerAccounts() {
        when(userRepository.findByEmail("admin@example.com")).thenReturn(Optional.of(adminUser(1L, "admin@example.com")));

        ApiException ex = assertThrows(ApiException.class,
                () -> service.becomeTrainer("admin@example.com", "PROFESSIONAL"));
        assertEquals(HttpStatus.FORBIDDEN, ex.getStatus());
        assertTrue(ex.getMessage().contains("learner or trainer"));
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
        user.getRoles().add(Role.builder().id(2L).roleName("TRAINER").build());
        when(userRepository.findByEmail("known@example.com")).thenReturn(Optional.of(user));
        when(trainerProfileRepository.findById(1L)).thenReturn(Optional.empty());
        when(trainerProfileRepository.save(any(TrainerProfile.class))).thenAnswer(inv -> inv.getArgument(0));

        TrainerProfileDTO dto = service.getTrainerProfile("known@example.com");

        assertEquals("PENDING_VERIFICATION", dto.getStatus());
        assertEquals(0.70, dto.getRevenueShare());
        assertEquals("PROFESSIONAL", dto.getTrainerType());
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

        ApiException ex = assertThrows(ApiException.class,
                () -> service.saveProfileDraft("known@example.com", new TrainerProfileDTO()));
        assertEquals(HttpStatus.NOT_FOUND, ex.getStatus());
    }

    @Test
    void saveProfileDraftShouldRejectEditWhenAwaitingApproval() {
        User user = learnerUser(1L, "known@example.com");
        when(userRepository.findByEmail("known@example.com")).thenReturn(Optional.of(user));
        when(trainerProfileRepository.findById(1L)).thenReturn(Optional.of(profile(1L, "AWAITING_APPROVAL", "PROFESSIONAL")));

        ApiException ex = assertThrows(ApiException.class,
                () -> service.saveProfileDraft("known@example.com", new TrainerProfileDTO()));
        assertEquals(HttpStatus.CONFLICT, ex.getStatus());
        assertTrue(ex.getMessage().contains("awaiting approval"));
    }

    @Test
    void saveProfileDraftShouldRejectEditWhenSuspended() {
        User user = learnerUser(1L, "known@example.com");
        when(userRepository.findByEmail("known@example.com")).thenReturn(Optional.of(user));
        when(trainerProfileRepository.findById(1L)).thenReturn(Optional.of(profile(1L, "SUSPENDED", "PROFESSIONAL")));

        ApiException ex = assertThrows(ApiException.class,
                () -> service.saveProfileDraft("known@example.com", new TrainerProfileDTO()));
        assertEquals(HttpStatus.CONFLICT, ex.getStatus());
        assertTrue(ex.getMessage().contains("suspended"));
    }

    @Test
    void saveProfileDraftShouldOnlyUpdateFieldsPresentOnDto() {
        User user = learnerUser(1L, "known@example.com");
        when(userRepository.findByEmail("known@example.com")).thenReturn(Optional.of(user));
        TrainerProfile existing = profile(1L, "PENDING_VERIFICATION", "PROFESSIONAL");
        when(trainerProfileRepository.findById(1L)).thenReturn(Optional.of(existing));
        when(userRepository.save(any(User.class))).thenAnswer(inv -> inv.getArgument(0));
        when(trainerProfileRepository.save(any(TrainerProfile.class))).thenAnswer(inv -> inv.getArgument(0));

        TrainerProfileDTO dto = new TrainerProfileDTO();
        dto.setBio("New bio");

        TrainerProfileDTO result = service.saveProfileDraft("known@example.com", dto);

        assertEquals("New bio", result.getBio());
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
        dto.setAvatarUrl("https://res.cloudinary.com/test-cloud/image/upload/avatar.png");

        service.saveProfileDraft("known@example.com", dto);

        assertEquals("0909123456", user.getPhoneNumber());
        assertEquals("https://res.cloudinary.com/test-cloud/image/upload/avatar.png", user.getAvatarUrl());
        verify(userRepository).save(user);
    }

    @Test
    void saveProfileDraftShouldNormalizeTypedDocumentsAndDeriveLegacyFields() {
        User user = learnerUser(1L, "known@example.com");
        when(userRepository.findByEmail("known@example.com")).thenReturn(Optional.of(user));
        TrainerProfile existing = profile(1L, "PENDING_VERIFICATION", "PROFESSIONAL");
        when(trainerProfileRepository.findById(1L)).thenReturn(Optional.of(existing));
        when(userRepository.save(any(User.class))).thenAnswer(inv -> inv.getArgument(0));
        when(trainerProfileRepository.save(any(TrainerProfile.class))).thenAnswer(inv -> inv.getArgument(0));

        TrainerProfileDTO dto = new TrainerProfileDTO();
        dto.setCertificates(List.of(
                TrainerDocumentDTO.builder()
                        .type("TEACHING_CV")
                        .name("Professional Teaching CV / Resume")
                        .url("https://res.cloudinary.com/test-cloud/image/upload/cv.pdf")
                        .build(),
                TrainerDocumentDTO.builder()
                        .type("LANGUAGE_PROFICIENCY")
                        .name("IELTS / Proficiency Certificate")
                        .url("https://res.cloudinary.com/test-cloud/image/upload/ielts.pdf")
                        .build(),
                TrainerDocumentDTO.builder()
                        .type("PEDAGOGICAL_DEGREE")
                        .name("Bachelor of English Pedagogy Degree")
                        .url("https://res.cloudinary.com/test-cloud/image/upload/degree.pdf")
                        .build()));

        TrainerProfileDTO result = service.saveProfileDraft("known@example.com", dto);

        assertTrue(result.getScoreReportUrl().startsWith("["));
        assertEquals("https://res.cloudinary.com/test-cloud/image/upload/degree.pdf", result.getPedagogicalDegreeUrl());
        assertEquals("https://res.cloudinary.com/test-cloud/image/upload/cv.pdf", result.getCvUrl());
        assertNotNull(result.getCertificates());
        assertEquals(3, result.getCertificates().size());
    }

    @Test
    void saveProfileDraftShouldNotInferDocumentTypeFromFileName() {
        User user = learnerUser(1L, "known@example.com");
        when(userRepository.findByEmail("known@example.com")).thenReturn(Optional.of(user));
        TrainerProfile existing = profile(1L, "PENDING_VERIFICATION", "PROFESSIONAL");
        when(trainerProfileRepository.findById(1L)).thenReturn(Optional.of(existing));
        when(userRepository.save(any(User.class))).thenAnswer(inv -> inv.getArgument(0));
        when(trainerProfileRepository.save(any(TrainerProfile.class))).thenAnswer(inv -> inv.getArgument(0));

        TrainerProfileDTO dto = new TrainerProfileDTO();
        dto.setCertificates(List.of(
                TrainerDocumentDTO.builder()
                        .type("PEDAGOGICAL_DEGREE")
                        .name("TEFL International TESOL Certification")
                        .issuingInstitution("Harvard University")
                        .url("https://res.cloudinary.com/test-cloud/image/upload/tefl.pdf")
                        .build()));

        TrainerProfileDTO result = service.saveProfileDraft("known@example.com", dto);

        assertEquals("PEDAGOGICAL_DEGREE", result.getCertificates().get(0).getType());
        assertEquals("https://res.cloudinary.com/test-cloud/image/upload/tefl.pdf", result.getPedagogicalDegreeUrl());
    }

    @Test
    void saveProfileDraftShouldKeepManualDocumentTypeSelectedByUser() {
        User user = learnerUser(1L, "known@example.com");
        when(userRepository.findByEmail("known@example.com")).thenReturn(Optional.of(user));
        TrainerProfile existing = profile(1L, "PENDING_VERIFICATION", "PROFESSIONAL");
        when(trainerProfileRepository.findById(1L)).thenReturn(Optional.of(existing));
        when(userRepository.save(any(User.class))).thenAnswer(inv -> inv.getArgument(0));
        when(trainerProfileRepository.save(any(TrainerProfile.class))).thenAnswer(inv -> inv.getArgument(0));

        TrainerProfileDTO dto = new TrainerProfileDTO();
        dto.setCertificates(List.of(
                TrainerDocumentDTO.builder()
                        .type("TEACHING_CERTIFICATE")
                        .name("Bachelor of English Pedagogy Degree")
                        .url("https://res.cloudinary.com/test-cloud/image/upload/manual-choice.pdf")
                        .source("trainer_profile_manual")
                        .build()));

        TrainerProfileDTO result = service.saveProfileDraft("known@example.com", dto);

        assertEquals("TEACHING_CERTIFICATE", result.getCertificates().get(0).getType());
        assertEquals("https://res.cloudinary.com/test-cloud/image/upload/manual-choice.pdf", result.getPedagogicalDegreeUrl());
    }

    @Test
    void saveProfileDraftShouldRejectUnmanagedCredentialUrl() {
        User user = learnerUser(1L, "known@example.com");
        when(userRepository.findByEmail("known@example.com")).thenReturn(Optional.of(user));
        when(trainerProfileRepository.findById(1L))
                .thenReturn(Optional.of(profile(1L, "PENDING_VERIFICATION", "PROFESSIONAL")));

        TrainerProfileDTO dto = new TrainerProfileDTO();
        dto.setCertificates(List.of(TrainerDocumentDTO.builder()
                .type("PEDAGOGICAL_DEGREE")
                .name("Unmanaged document")
                .url("https://attacker.example/fake.pdf")
                .build()));

        ApiException ex = assertThrows(ApiException.class,
                () -> service.saveProfileDraft("known@example.com", dto));
        assertEquals(HttpStatus.BAD_REQUEST, ex.getStatus());
        assertTrue(ex.getMessage().contains("Cloudinary"));
    }

    @Test
    void saveProfileDraftShouldRecordServerAgreementMetadata() {
        User user = learnerUser(1L, "known@example.com");
        TrainerProfile existing = profile(1L, "PENDING_VERIFICATION", "PROFESSIONAL");
        when(userRepository.findByEmail("known@example.com")).thenReturn(Optional.of(user));
        when(trainerProfileRepository.findById(1L)).thenReturn(Optional.of(existing));
        when(userRepository.save(any(User.class))).thenAnswer(inv -> inv.getArgument(0));
        when(trainerProfileRepository.save(any(TrainerProfile.class))).thenAnswer(inv -> inv.getArgument(0));

        TrainerProfileDTO dto = new TrainerProfileDTO();
        dto.setAgreementSigned(true);
        TrainerProfileDTO result = service.saveProfileDraft("known@example.com", dto);

        assertTrue(result.getAgreementSigned());
        assertEquals("v1.0-2026-08-14", result.getAgreementVersion());
        assertNotNull(result.getAgreementAcceptedAt());
    }

    @Test
    void saveProfileDraftShouldRejectDummyPayoutNumber() {
        User user = learnerUser(1L, "known@example.com");
        TrainerProfile existing = profile(1L, "PENDING_VERIFICATION", "PROFESSIONAL");
        when(userRepository.findByEmail("known@example.com")).thenReturn(Optional.of(user));
        when(trainerProfileRepository.findById(1L)).thenReturn(Optional.of(existing));

        TrainerProfileDTO dto = new TrainerProfileDTO();
        dto.setBankAccount("0000000000");

        ApiException ex = assertThrows(ApiException.class,
                () -> service.saveProfileDraft("known@example.com", dto));
        assertEquals(HttpStatus.BAD_REQUEST, ex.getStatus());
        assertTrue(ex.getMessage().contains("Bank account"));
    }

    @Test
    void saveProfileDraftShouldRejectCredentialReplacementForVerifiedTrainer() {
        User user = learnerUser(1L, "known@example.com");
        TrainerProfile existing = completeProfile(1L);
        existing.setStatus("VERIFIED");
        when(userRepository.findByEmail("known@example.com")).thenReturn(Optional.of(user));
        when(trainerProfileRepository.findById(1L)).thenReturn(Optional.of(existing));

        TrainerProfileDTO dto = new TrainerProfileDTO();
        dto.setCertificates(List.of(TrainerDocumentDTO.builder()
                .type("PEDAGOGICAL_DEGREE")
                .name("Replacement degree")
                .url("https://res.cloudinary.com/test-cloud/image/upload/replacement.pdf")
                .build()));

        ApiException ex = assertThrows(ApiException.class,
                () -> service.saveProfileDraft("known@example.com", dto));
        assertEquals(HttpStatus.CONFLICT, ex.getStatus());
        assertTrue(ex.getMessage().contains("credential update"));
    }

    @Test
    void submitCredentialUpdateShouldReturnVerifiedTrainerToReviewQueue() {
        User user = learnerUser(1L, "known@example.com");
        user.getRoles().add(Role.builder().id(2L).roleName("TRAINER").build());
        TrainerProfile existing = reviewableProfile(1L, "PROFESSIONAL");
        existing.setStatus("VERIFIED");
        existing.setUser(user);
        when(userRepository.findByEmail("known@example.com")).thenReturn(Optional.of(user));
        when(trainerProfileRepository.findByIdForUpdate(1L)).thenReturn(Optional.of(existing));
        when(trainerProfileRepository.save(any(TrainerProfile.class))).thenAnswer(inv -> inv.getArgument(0));

        TrainerProfileDTO dto = new TrainerProfileDTO();
        dto.setCertificates(List.of(TrainerDocumentDTO.builder()
                .type("TEACHING_CERTIFICATE")
                .name("Updated teaching certificate")
                .url("https://res.cloudinary.com/test-cloud/image/upload/updated-certificate.pdf")
                .build()));

        TrainerProfileDTO result = service.submitCredentialUpdate("known@example.com", dto);

        assertEquals("AWAITING_APPROVAL", result.getStatus());
        assertNotNull(existing.getSubmittedAt());
        verify(notificationService).notifyRole(
                NotificationService.RECIPIENT_ADMIN,
                NotificationService.TYPE_TRAINER_APPLICATION_SUBMITTED,
                "Trainer Credential Update Submitted",
                "Learner User submitted updated credentials for review.",
                null);
    }

    // =================================================================
    // submitProfileForReview
    // =================================================================

    private TrainerProfile completeProfile(Long userId) {
        TrainerProfile p = profile(userId, "PENDING_VERIFICATION", "PROFESSIONAL");
        p.setBio("Experienced teacher with over 5 years of IELTS academic teaching history");
        p.setScoreReportUrl("""
                [{"type":"PEDAGOGICAL_DEGREE","name":"Pedagogical Degree","url":"https://res.cloudinary.com/test-cloud/image/upload/degree.pdf"}]
                """.trim());
        p.setPedagogicalDegreeUrl("https://res.cloudinary.com/test-cloud/image/upload/degree.pdf");
        p.setAgreementSigned(true);
        return p;
    }

    private TrainerProfile reviewableProfile(Long userId, String trainerType) {
        User user = learnerUser(userId, "trainer@example.com");
        user.setPhoneNumber("0909123456");
        user.setGender("MALE");
        user.setAvatarUrl("https://res.cloudinary.com/test-cloud/image/upload/avatar.png");
        user.getRoles().add(Role.builder().id(2L).roleName("TRAINER").build());

        TrainerProfile p = completeProfile(userId);
        p.setStatus("AWAITING_APPROVAL");
        p.setTrainerType(trainerType);
        p.setUser(user);
        if ("PEER_TUTOR".equals(trainerType)) {
            p.setScoreReportUrl("""
                    [{"type":"LANGUAGE_PROFICIENCY","name":"IELTS Certificate","url":"https://res.cloudinary.com/test-cloud/image/upload/ielts.pdf"}]
                    """.trim());
            p.setPedagogicalDegreeUrl(null);
        }
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

        ApiException ex = assertThrows(ApiException.class,
                () -> service.submitProfileForReview("known@example.com", new TrainerProfileDTO()));
        assertEquals(HttpStatus.NOT_FOUND, ex.getStatus());
    }

    @Test
    void submitProfileForReviewShouldRejectWhenAlreadyAwaitingApproval() {
        User user = learnerUser(1L, "known@example.com");
        when(userRepository.findByEmail("known@example.com")).thenReturn(Optional.of(user));
        when(trainerProfileRepository.findById(1L)).thenReturn(Optional.of(profile(1L, "AWAITING_APPROVAL", "PROFESSIONAL")));

        ApiException ex = assertThrows(ApiException.class,
                () -> service.submitProfileForReview("known@example.com", new TrainerProfileDTO()));
        assertEquals(HttpStatus.CONFLICT, ex.getStatus());
    }

    @Test
    void submitProfileForReviewShouldRejectMissingBio() {
        User user = learnerUser(1L, "known@example.com");
        when(userRepository.findByEmail("known@example.com")).thenReturn(Optional.of(user));
        TrainerProfile incomplete = profile(1L, "PENDING_VERIFICATION", "PROFESSIONAL");
        incomplete.setAgreementSigned(true);
        when(trainerProfileRepository.findById(1L)).thenReturn(Optional.of(incomplete));
        when(trainerProfileRepository.save(any(TrainerProfile.class))).thenAnswer(inv -> inv.getArgument(0));
        when(userRepository.save(any(User.class))).thenAnswer(inv -> inv.getArgument(0));

        ApiException ex = assertThrows(ApiException.class,
                () -> service.submitProfileForReview("known@example.com", new TrainerProfileDTO()));
        assertEquals(HttpStatus.BAD_REQUEST, ex.getStatus());
        assertTrue(ex.getMessage().toLowerCase().contains("bio"));
    }

    @Test
    void submitProfileForReviewShouldRejectMissingPhoneNumber() {
        User user = learnerUser(1L, "known@example.com");
        when(userRepository.findByEmail("known@example.com")).thenReturn(Optional.of(user));
        TrainerProfile incomplete = profile(1L, "PENDING_VERIFICATION", "PROFESSIONAL");
        incomplete.setBio("Experienced teacher with over 5 years of IELTS academic teaching history");
        incomplete.setAgreementSigned(true);
        when(trainerProfileRepository.findById(1L)).thenReturn(Optional.of(incomplete));
        when(trainerProfileRepository.save(any(TrainerProfile.class))).thenAnswer(inv -> inv.getArgument(0));
        when(userRepository.save(any(User.class))).thenAnswer(inv -> inv.getArgument(0));

        ApiException ex = assertThrows(ApiException.class,
                () -> service.submitProfileForReview("known@example.com", new TrainerProfileDTO()));
        assertEquals(HttpStatus.BAD_REQUEST, ex.getStatus());
        assertTrue(ex.getMessage().toLowerCase().contains("phone"));
    }

    @Test
    void submitProfileForReviewShouldRejectWhenAgreementNotSigned() {
        User user = learnerUser(1L, "known@example.com");
        user.setPhoneNumber("0909123456");
        user.setGender("MALE");
        user.setAvatarUrl("https://res.cloudinary.com/test-cloud/image/upload/avatar.png");
        when(userRepository.findByEmail("known@example.com")).thenReturn(Optional.of(user));
        TrainerProfile incomplete = profile(1L, "PENDING_VERIFICATION", "PROFESSIONAL");
        incomplete.setBio("Experienced teacher with over 5 years of IELTS academic teaching history");
        incomplete.setPedagogicalDegreeUrl("https://res.cloudinary.com/test-cloud/image/upload/pedagogy_degree.pdf");
        incomplete.setScoreReportUrl("https://res.cloudinary.com/test-cloud/image/upload/pedagogy_degree.pdf");
        incomplete.setAgreementSigned(false);
        when(trainerProfileRepository.findById(1L)).thenReturn(Optional.of(incomplete));
        when(trainerProfileRepository.save(any(TrainerProfile.class))).thenAnswer(inv -> inv.getArgument(0));
        when(userRepository.save(any(User.class))).thenAnswer(inv -> inv.getArgument(0));

        ApiException ex = assertThrows(ApiException.class,
                () -> service.submitProfileForReview("known@example.com", new TrainerProfileDTO()));
        assertEquals(HttpStatus.BAD_REQUEST, ex.getStatus());
        assertTrue(ex.getMessage().toLowerCase().contains("agreement"));
    }

    @Test
    void submitProfileForReviewShouldRejectTeacherWithoutPedagogicalDegree() {
        User user = learnerUser(1L, "known@example.com");
        user.setPhoneNumber("0909123456");
        user.setGender("MALE");
        user.setAvatarUrl("https://res.cloudinary.com/test-cloud/image/upload/avatar.png");
        when(userRepository.findByEmail("known@example.com")).thenReturn(Optional.of(user));
        TrainerProfile teacherProfile = profile(1L, "PENDING_VERIFICATION", "PROFESSIONAL");
        teacherProfile.setBio("Experienced teacher with over 5 years of IELTS academic teaching history");
        teacherProfile.setScoreReportUrl("https://res.cloudinary.com/test-cloud/image/upload/ielts.pdf");
        teacherProfile.setAgreementSigned(true);
        // pedagogicalDegreeUrl is NULL
        when(trainerProfileRepository.findById(1L)).thenReturn(Optional.of(teacherProfile));
        when(trainerProfileRepository.save(any(TrainerProfile.class))).thenAnswer(inv -> inv.getArgument(0));
        when(userRepository.save(any(User.class))).thenAnswer(inv -> inv.getArgument(0));

        ApiException ex = assertThrows(ApiException.class,
                () -> service.submitProfileForReview("known@example.com", new TrainerProfileDTO()));
        assertEquals(HttpStatus.BAD_REQUEST, ex.getStatus());
        assertTrue(ex.getMessage().toLowerCase().contains("pedagogical"));
    }

    @Test
    void submitProfileForReviewShouldRejectTeacherWhenOnlyTeachingCvExists() {
        User user = learnerUser(1L, "known@example.com");
        user.setPhoneNumber("0909123456");
        user.setGender("MALE");
        user.setAvatarUrl("https://res.cloudinary.com/test-cloud/image/upload/avatar.png");
        when(userRepository.findByEmail("known@example.com")).thenReturn(Optional.of(user));
        TrainerProfile teacherProfile = profile(1L, "PENDING_VERIFICATION", "PROFESSIONAL");
        teacherProfile.setBio("Experienced teacher with over 5 years of IELTS academic teaching history");
        teacherProfile.setScoreReportUrl("""
                [{"type":"TEACHING_CV","name":"Professional Teaching CV / Resume","url":"https://res.cloudinary.com/test-cloud/image/upload/cv.pdf"}]
                """.trim());
        teacherProfile.setAgreementSigned(true);
        when(trainerProfileRepository.findById(1L)).thenReturn(Optional.of(teacherProfile));
        when(trainerProfileRepository.save(any(TrainerProfile.class))).thenAnswer(inv -> inv.getArgument(0));
        when(userRepository.save(any(User.class))).thenAnswer(inv -> inv.getArgument(0));

        ApiException ex = assertThrows(ApiException.class,
                () -> service.submitProfileForReview("known@example.com", new TrainerProfileDTO()));

        assertEquals(HttpStatus.BAD_REQUEST, ex.getStatus());
        assertTrue(ex.getMessage().toLowerCase().contains("pedagogical"));
    }

    @Test
    void submitProfileForReviewShouldRejectMissingAllCertificationDocuments() {
        User user = learnerUser(1L, "known@example.com");
        user.setPhoneNumber("0909123456");
        user.setGender("MALE");
        user.setAvatarUrl("https://res.cloudinary.com/test-cloud/image/upload/avatar.png");
        when(userRepository.findByEmail("known@example.com")).thenReturn(Optional.of(user));
        TrainerProfile incomplete = profile(1L, "PENDING_VERIFICATION", "PEER_TUTOR");
        incomplete.setBio("Experienced tutor with over 5 years of IELTS academic teaching history");
        incomplete.setAgreementSigned(true);
        when(trainerProfileRepository.findById(1L)).thenReturn(Optional.of(incomplete));
        when(trainerProfileRepository.save(any(TrainerProfile.class))).thenAnswer(inv -> inv.getArgument(0));
        when(userRepository.save(any(User.class))).thenAnswer(inv -> inv.getArgument(0));

        ApiException ex = assertThrows(ApiException.class,
                () -> service.submitProfileForReview("known@example.com", new TrainerProfileDTO()));
        assertEquals(HttpStatus.BAD_REQUEST, ex.getStatus());
        assertTrue(ex.getMessage().toLowerCase().contains("proof"));
    }

    @Test
    void submitProfileForReviewShouldMarkAwaitingApprovalWhenAllRequiredFieldsPresent() {
        User user = learnerUser(1L, "known@example.com");
        user.setPhoneNumber("0909123456");
        user.setGender("MALE");
        user.setAvatarUrl("https://res.cloudinary.com/test-cloud/image/upload/avatar.png");
        when(userRepository.findByEmail("known@example.com")).thenReturn(Optional.of(user));
        TrainerProfile complete = completeProfile(1L);
        complete.setBio("Experienced teacher with over 5 years of IELTS academic teaching history");
        complete.setPedagogicalDegreeUrl("https://res.cloudinary.com/test-cloud/image/upload/pedagogy_degree.pdf");
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
        p1.setUser(learnerUser(1L, "user1@example.com"));
        TrainerProfile p2 = profile(2L, "PENDING_VERIFICATION", "PEER_TUTOR");
        p2.setUser(learnerUser(2L, "user2@example.com"));
        when(trainerProfileRepository.findAllWithUser()).thenReturn(List.of(p1, p2));

        List<TrainerProfileDTO> result = service.getTrainerProfilesForAdmin(null, "ALL");

        assertEquals(2, result.size());
    }

    @Test
    void getTrainerProfilesForAdminShouldFilterByStatus() {
        TrainerProfile p1 = profile(1L, "VERIFIED", "PROFESSIONAL");
        p1.setUser(learnerUser(1L, "user1@example.com"));
        TrainerProfile p2 = profile(2L, "PENDING_VERIFICATION", "PEER_TUTOR");
        p2.setUser(learnerUser(2L, "user2@example.com"));
        when(trainerProfileRepository.findAllWithUser()).thenReturn(List.of(p1, p2));

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
        when(trainerProfileRepository.findAllWithUser()).thenReturn(List.of(p1, p2));

        List<TrainerProfileDTO> result = service.getTrainerProfilesForAdmin("alice", "ALL");

        assertEquals(1, result.size());
        assertEquals("alice@example.com", result.get(0).getEmail());
    }

    @Test
    void getTrainerProfilesForAdminShouldExcludePayoutCredentials() {
        TrainerProfile p = profile(1L, "AWAITING_APPROVAL", "PROFESSIONAL");
        p.setUser(learnerUser(1L, "trainer@example.com"));
        p.setBankName("Example Bank");
        p.setBankAccount("1023928129");
        p.setBankAccountName("NGUYEN VAN A");
        p.setTaxCode("1234567890");
        p.setCitizenId("001234567890");
        when(trainerProfileRepository.findAllWithUser()).thenReturn(List.of(p));

        TrainerProfileDTO result = service.getTrainerProfilesForAdmin(null, "ALL").get(0);

        assertNull(result.getBankName());
        assertNull(result.getBankAccount());
        assertNull(result.getBankAccountName());
        assertNull(result.getTaxCode());
        assertNull(result.getCitizenId());
    }

    @Test
    void getTrainerProfilesForAdminShouldReturnEmptyWhenNoMatch() {
        when(trainerProfileRepository.findAllWithUser()).thenReturn(List.of(profile(1L, "VERIFIED", "PROFESSIONAL")));

        List<TrainerProfileDTO> result = service.getTrainerProfilesForAdmin("nomatch", "ALL");

        assertTrue(result.isEmpty());
    }

    @Test
    void getTrainerProfilesForAdminShouldSortNewestSubmittedFirstAndPushNullsLast() {
        TrainerProfile older = profile(1L, "AWAITING_APPROVAL", "PROFESSIONAL");
        older.setUser(learnerUser(1L, "user1@example.com"));
        older.setSubmittedAt(LocalDateTime.now().minusDays(2));
        TrainerProfile newer = profile(2L, "AWAITING_APPROVAL", "PROFESSIONAL");
        newer.setUser(learnerUser(2L, "user2@example.com"));
        newer.setSubmittedAt(LocalDateTime.now());
        TrainerProfile neverSubmitted = profile(3L, "PENDING_VERIFICATION", "PROFESSIONAL");
        neverSubmitted.setUser(learnerUser(3L, "user3@example.com"));
        TrainerProfile alsoNeverSubmitted = profile(4L, "PENDING_VERIFICATION", "PEER_TUTOR");
        alsoNeverSubmitted.setUser(learnerUser(4L, "user4@example.com"));
        when(trainerProfileRepository.findAllWithUser())
                .thenReturn(List.of(older, neverSubmitted, newer, alsoNeverSubmitted));

        List<TrainerProfileDTO> result = service.getTrainerProfilesForAdmin(null, "ALL");

        assertEquals(4, result.size());
        assertEquals(2L, result.get(0).getUserId());
        assertEquals(1L, result.get(1).getUserId());
        assertEquals(3L, result.get(2).getUserId());
        assertEquals(4L, result.get(3).getUserId());
    }

    // =================================================================
    // reviewTrainerProfile
    // =================================================================

    @Test
    void reviewTrainerProfileShouldThrowWhenProfileNotFound() {
        when(trainerProfileRepository.findByIdForUpdate(99L)).thenReturn(Optional.empty());

        TrainerReviewRequest req = new TrainerReviewRequest();
        req.setStatus("VERIFIED");

        ApiException ex = assertThrows(ApiException.class, () -> service.reviewTrainerProfile(99L, req));
        assertEquals(HttpStatus.NOT_FOUND, ex.getStatus());
    }

    @Test
    void reviewTrainerProfileShouldAutomaticallySetFixedRevenueShareForTeacher() {
        TrainerProfile p = reviewableProfile(1L, "PROFESSIONAL");
        when(trainerProfileRepository.findByIdForUpdate(1L)).thenReturn(Optional.of(p));
        when(trainerProfileRepository.save(any(TrainerProfile.class))).thenAnswer(inv -> inv.getArgument(0));

        TrainerReviewRequest req = new TrainerReviewRequest();
        req.setStatus("VERIFIED");
        req.setAdminNotes("Credentials verified");

        TrainerProfileDTO result = service.reviewTrainerProfile(1L, req);

        assertEquals("VERIFIED", result.getStatus());
        assertEquals(0.70, result.getRevenueShare());
        assertNotNull(p.getReviewedAt());
        verify(emailService).sendTrainerStatusNotificationEmail(
                "trainer@example.com", "VERIFIED", "Credentials verified");
    }

    @Test
    void reviewTrainerProfileShouldGrantTrainerRoleAndNotifyOnlyAfterCommit() {
        User user = learnerUser(1L, "trainer@example.com");
        user.setPhoneNumber("0909123456");
        user.setGender("MALE");
        user.setAvatarUrl("https://res.cloudinary.com/test-cloud/image/upload/avatar.png");
        TrainerProfile p = reviewableProfile(1L, "PROFESSIONAL");
        p.setUser(user);
        Role trainerRole = Role.builder().id(2L).roleName("TRAINER").build();

        when(trainerProfileRepository.findByIdForUpdate(1L)).thenReturn(Optional.of(p));
        when(roleRepository.findByRoleName("TRAINER")).thenReturn(Optional.of(trainerRole));
        when(userRepository.save(any(User.class))).thenAnswer(inv -> inv.getArgument(0));
        when(trainerProfileRepository.save(any(TrainerProfile.class))).thenAnswer(inv -> inv.getArgument(0));

        TrainerReviewRequest req = new TrainerReviewRequest();
        req.setStatus("VERIFIED");

        TransactionSynchronizationManager.initSynchronization();
        try {
            service.reviewTrainerProfile(1L, req);

            assertTrue(user.getRoles().stream()
                    .anyMatch(role -> "TRAINER".equalsIgnoreCase(role.getRoleName())));
            verify(userRepository).save(user);
            verify(emailService, never())
                    .sendTrainerStatusNotificationEmail(anyString(), anyString(), any());

            List<TransactionSynchronization> synchronizations =
                    TransactionSynchronizationManager.getSynchronizations();
            assertEquals(1, synchronizations.size());
            synchronizations.get(0).afterCommit();

            verify(emailService).sendTrainerStatusNotificationEmail("trainer@example.com", "VERIFIED", null);
        } finally {
            TransactionSynchronizationManager.clearSynchronization();
        }
    }

    @Test
    void reviewTrainerProfileShouldUseAdminProvidedRevenueShareWhenVerifying() {
        TrainerProfile p = reviewableProfile(1L, "PROFESSIONAL");
        when(trainerProfileRepository.findByIdForUpdate(1L)).thenReturn(Optional.of(p));
        when(trainerProfileRepository.save(any(TrainerProfile.class))).thenAnswer(inv -> inv.getArgument(0));

        TrainerReviewRequest req = new TrainerReviewRequest();
        req.setStatus("VERIFIED");
        req.setRevenueShare(0.75);

        TrainerProfileDTO result = service.reviewTrainerProfile(1L, req);

        assertEquals(0.75, result.getRevenueShare());
    }

    @Test
    void reviewTrainerProfileShouldDefaultToSeventyPercentForProfessionalWhenNoRevenueShareGiven() {
        TrainerProfile p = reviewableProfile(1L, "PROFESSIONAL");
        when(trainerProfileRepository.findByIdForUpdate(1L)).thenReturn(Optional.of(p));
        when(trainerProfileRepository.save(any(TrainerProfile.class))).thenAnswer(inv -> inv.getArgument(0));

        TrainerReviewRequest req = new TrainerReviewRequest();
        req.setStatus("VERIFIED");

        TrainerProfileDTO result = service.reviewTrainerProfile(1L, req);

        assertEquals(0.70, result.getRevenueShare());
    }

    @Test
    void reviewTrainerProfileShouldDefaultToSixtyPercentForPeerTutorWhenNoRevenueShareGiven() {
        TrainerProfile p = reviewableProfile(1L, "PEER_TUTOR");
        when(trainerProfileRepository.findByIdForUpdate(1L)).thenReturn(Optional.of(p));
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
        when(trainerProfileRepository.findByIdForUpdate(1L)).thenReturn(Optional.of(p));
        when(trainerProfileRepository.save(any(TrainerProfile.class))).thenAnswer(inv -> inv.getArgument(0));

        TrainerReviewRequest req = new TrainerReviewRequest();
        req.setStatus("SUSPENDED");
        req.setAdminNotes("Fraudulent documents");

        TrainerProfileDTO result = service.reviewTrainerProfile(1L, req);

        assertEquals("SUSPENDED", result.getStatus());
        assertEquals(0.70, result.getRevenueShare());
    }

    @Test
    void reviewTrainerProfileShouldRejectInvalidStatus() {
        TrainerProfile p = profile(1L, "AWAITING_APPROVAL", "PROFESSIONAL");
        when(trainerProfileRepository.findByIdForUpdate(1L)).thenReturn(Optional.of(p));

        TrainerReviewRequest req = new TrainerReviewRequest();
        req.setStatus("REJECTED");

        ApiException ex = assertThrows(ApiException.class, () -> service.reviewTrainerProfile(1L, req));
        assertEquals(HttpStatus.BAD_REQUEST, ex.getStatus());
        assertTrue(ex.getMessage().contains("status must be one of"));
    }

    @Test
    void reviewTrainerProfileShouldRejectInvalidSourceStateTransition() {
        TrainerProfile p = profile(1L, "VERIFIED", "PROFESSIONAL");
        when(trainerProfileRepository.findByIdForUpdate(1L)).thenReturn(Optional.of(p));

        TrainerReviewRequest req = new TrainerReviewRequest();
        req.setStatus("PENDING_VERIFICATION");
        req.setAdminNotes("Revisions requested");

        ApiException ex = assertThrows(ApiException.class,
                () -> service.reviewTrainerProfile(1L, req));
        assertEquals(HttpStatus.CONFLICT, ex.getStatus());
        assertTrue(ex.getMessage().contains("Invalid trainer review transition"));
    }

    @Test
    void reviewTrainerProfileShouldRejectRevenueShareOutsideAllowedRange() {
        TrainerProfile p = reviewableProfile(1L, "PROFESSIONAL");
        when(trainerProfileRepository.findByIdForUpdate(1L)).thenReturn(Optional.of(p));

        TrainerReviewRequest req = new TrainerReviewRequest();
        req.setStatus("VERIFIED");
        req.setRevenueShare(0.99);

        ApiException ex = assertThrows(ApiException.class, () -> service.reviewTrainerProfile(1L, req));
        assertEquals(HttpStatus.BAD_REQUEST, ex.getStatus());
        assertTrue(ex.getMessage().contains("between 0.50"));
    }

    @Test
    void reviewTrainerProfileShouldSendStatusNotificationEmailWhenUserPresent() {
        User user = learnerUser(1L, "trainer@example.com");
        user.setPhoneNumber("0909123456");
        user.setGender("MALE");
        user.setAvatarUrl("https://res.cloudinary.com/test-cloud/image/upload/avatar.png");
        TrainerProfile p = reviewableProfile(1L, "PROFESSIONAL");
        p.setUser(user);
        when(trainerProfileRepository.findByIdForUpdate(1L)).thenReturn(Optional.of(p));
        when(trainerProfileRepository.save(any(TrainerProfile.class))).thenAnswer(inv -> inv.getArgument(0));

        TrainerReviewRequest req = new TrainerReviewRequest();
        req.setStatus("VERIFIED");
        req.setAdminNotes("Welcome aboard");

        service.reviewTrainerProfile(1L, req);

        verify(emailService).sendTrainerStatusNotificationEmail("trainer@example.com", "VERIFIED", "Welcome aboard");
    }
}
