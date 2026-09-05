package com.hango.hango_backend.service;

import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.core.type.TypeReference;
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
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpStatus;
import org.springframework.security.core.userdetails.UsernameNotFoundException;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.transaction.support.TransactionSynchronization;
import org.springframework.transaction.support.TransactionSynchronizationManager;

import java.time.LocalDateTime;
import java.net.URI;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.HashSet;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.Objects;
import java.util.Set;
import java.util.stream.Collectors;

@Service
@RequiredArgsConstructor
@Slf4j
public class TrainerOnboardingServiceImpl implements TrainerOnboardingService {
    private static final String DOC_TYPE_PEDAGOGICAL_DEGREE = "PEDAGOGICAL_DEGREE";
    private static final String DOC_TYPE_TEACHING_CERTIFICATE = "TEACHING_CERTIFICATE";
    private static final String DOC_TYPE_LANGUAGE_PROFICIENCY = "LANGUAGE_PROFICIENCY";
    private static final String DOC_TYPE_ACADEMIC_TRANSCRIPT = "ACADEMIC_TRANSCRIPT";
    private static final String DOC_TYPE_TEACHING_CV = "TEACHING_CV";
    private static final String DOC_TYPE_OTHER = "OTHER";
    private static final String TRAINER_TYPE_PROFESSIONAL = "PROFESSIONAL";
    private static final String TRAINER_TYPE_PEER_TUTOR = "PEER_TUTOR";
    private static final String STATUS_PENDING = "PENDING_VERIFICATION";
    private static final String STATUS_AWAITING = "AWAITING_APPROVAL";
    private static final String STATUS_VERIFIED = "VERIFIED";
    private static final String STATUS_SUSPENDED = "SUSPENDED";
    private static final String CURRENT_AGREEMENT_VERSION = "v1.0-2026-08-14";
    private static final int MAX_DOCUMENTS = 10;
    private static final Set<String> ALLOWED_TRAINER_TYPES = Set.of(
            TRAINER_TYPE_PROFESSIONAL,
            TRAINER_TYPE_PEER_TUTOR);
    private static final Set<String> ALLOWED_REVIEW_STATUSES = Set.of(
            "VERIFIED",
            "PENDING_VERIFICATION",
            "SUSPENDED");

    private final UserRepository userRepository;
    private final RoleRepository roleRepository;
    private final TrainerProfileRepository trainerProfileRepository;
    private final JwtUtils jwtUtils;
    private final EmailService emailService;
    private final NotificationService notificationService;
    private final ObjectMapper objectMapper;

    @Value("${cloudinary.cloud-name:}")
    private String cloudinaryCloudName;

    @Override
    @Transactional
    public LoginResponse becomeTrainer(String email, String trainerType) {
        User user = userRepository.findByEmail(email)
                .orElseThrow(() -> new UsernameNotFoundException("User not found with email: " + email));
        assertEligibleSelfServiceUser(user);
        String normalizedTrainerType = normalizeTrainerType(trainerType);

        // 1. Ensure Trainer role exists and assign it
        Role trainerRole = roleRepository.findByRoleName("TRAINER")
                .orElseGet(() -> {
                    Role newRole = Role.builder().roleName("TRAINER").build();
                    return roleRepository.save(newRole);
                });

        boolean alreadyTrainer = user.getRoles().stream()
                .anyMatch(r -> "TRAINER".equalsIgnoreCase(r.getRoleName()));

        if (!alreadyTrainer) {
            user.getRoles().add(trainerRole);
            user = userRepository.save(user);
            log.info("Granted Trainer role to user ID: {}", user.getId());
        }

        // 2. Initialize TrainerProfile if missing
        TrainerProfile profile = trainerProfileRepository.findById(user.getId()).orElse(null);
        if (profile == null) {
            double defaultShare = defaultRevenueShareForTrainerType(normalizedTrainerType);
            profile = TrainerProfile.builder()
                    .user(user)
                    .trainerType(normalizedTrainerType)
                    .revenueShare(defaultShare)
                    .status("PENDING_VERIFICATION")
                    .build();
            trainerProfileRepository.save(profile);
            log.info("Initialized TrainerProfile for user ID: {} with type: {}", user.getId(), normalizedTrainerType);
        } else {
            // Update type if they switch before submitting
            if ("PENDING_VERIFICATION".equalsIgnoreCase(profile.getStatus())) {
                profile.setTrainerType(normalizedTrainerType);
                profile.setRevenueShare(defaultRevenueShareForTrainerType(normalizedTrainerType));
                trainerProfileRepository.save(profile);
            }
        }

        // 3. Issue a updated JWT token with the new ROLE_TRAINER authority
        String jwt = jwtUtils.generateJwtTokenFromUsername(user.getEmail());

        List<String> roles = user.getRoles().stream()
                .map(Role::getRoleName)
                .collect(Collectors.toList());

        return new LoginResponse(
                jwt,
                user.getId(),
                user.getEmail(),
                user.getFullName(),
                roles,
                user.getAvatarUrl()
        );
    }

    @Override
    @Transactional
    public TrainerProfileDTO getTrainerProfile(String email) {
        User user = userRepository.findByEmail(email)
                .orElseThrow(() -> new UsernameNotFoundException("User not found with email: " + email));
        assertEligibleSelfServiceUser(user);

        TrainerProfile profile = trainerProfileRepository.findById(user.getId()).orElse(null);
        if (profile == null) {
            if (!hasRole(user, "TRAINER")) {
                throw new ApiException("Start the trainer registration flow before loading a trainer profile.",
                        HttpStatus.NOT_FOUND);
            }
            profile = trainerProfileRepository.save(TrainerProfile.builder()
                    .user(user)
                    .trainerType(TRAINER_TYPE_PROFESSIONAL)
                    .revenueShare(defaultRevenueShareForTrainerType(TRAINER_TYPE_PROFESSIONAL))
                    .status(STATUS_PENDING)
                    .build());
        }

        return mapToDTO(profile);
    }

    @Override
    @Transactional
    public TrainerProfileDTO saveProfileDraft(String email, TrainerProfileDTO dto) {
        if (dto == null) {
            throw new ApiException("Trainer profile payload is required.", HttpStatus.BAD_REQUEST);
        }
        User user = userRepository.findByEmail(email)
                .orElseThrow(() -> new UsernameNotFoundException("User not found with email: " + email));
        assertEligibleSelfServiceUser(user);

        TrainerProfile profile = trainerProfileRepository.findById(user.getId())
                .orElseThrow(() -> new ApiException("Trainer profile not found for user: " + email, HttpStatus.NOT_FOUND));

        // Prevent modification if already waiting or suspended
        if (STATUS_AWAITING.equalsIgnoreCase(profile.getStatus())) {
            throw new ApiException("Application is currently awaiting approval. Profile details cannot be modified.",
                    HttpStatus.CONFLICT);
        }
        if (STATUS_SUSPENDED.equalsIgnoreCase(profile.getStatus())) {
            throw new ApiException("Your trainer account has been suspended.", HttpStatus.CONFLICT);
        }

        validateDraftFields(dto);

        // Auto-save updating fields
        if (dto.getBio() != null) profile.setBio(dto.getBio().trim());
        if (Boolean.TRUE.equals(dto.getAgreementSigned())
                && (!Boolean.TRUE.equals(profile.getAgreementSigned())
                    || !CURRENT_AGREEMENT_VERSION.equals(profile.getAgreementVersion()))) {
            profile.setAgreementSigned(true);
            profile.setAgreementVersion(CURRENT_AGREEMENT_VERSION);
            profile.setAgreementAcceptedAt(LocalDateTime.now());
        }
        
        if (hasDocumentPayload(dto)) {
            List<TrainerDocumentDTO> incomingDocuments = resolveDocuments(dto);
            if (STATUS_VERIFIED.equalsIgnoreCase(profile.getStatus())
                    && !documentsEquivalent(extractDocuments(profile), incomingDocuments)) {
                throw new ApiException(
                        "Verified credentials cannot be replaced through draft save. Submit a credential update for review.",
                        HttpStatus.CONFLICT);
            }
            if (!STATUS_VERIFIED.equalsIgnoreCase(profile.getStatus())) {
                applyDocuments(profile, incomingDocuments);
            }
        }

        if (dto.getBankName() != null) profile.setBankName(dto.getBankName().trim());
        if (dto.getBankAccount() != null) profile.setBankAccount(dto.getBankAccount().trim());
        if (dto.getBankAccountName() != null) profile.setBankAccountName(dto.getBankAccountName().trim().toUpperCase(Locale.ROOT));
        if (dto.getTaxCode() != null) profile.setTaxCode(dto.getTaxCode().trim());
        if (dto.getCitizenId() != null) profile.setCitizenId(dto.getCitizenId().trim());
        User u = profile.getUser() != null ? profile.getUser() : user;
        if (u != null) {
            if (dto.getPhoneNumber() != null) u.setPhoneNumber(dto.getPhoneNumber().trim());
            if (dto.getGender() != null) u.setGender(dto.getGender().trim().toUpperCase(Locale.ROOT));
            String requestedUsername = dto.getUsername() != null ? dto.getUsername().trim() : null;
            if (requestedUsername != null && !requestedUsername.equalsIgnoreCase(u.getUsername())) {
                if (userRepository.existsByUsername(requestedUsername)) {
                    throw new ApiException("Error: Username is already in use!", HttpStatus.CONFLICT);
                }
                u.setUsername(requestedUsername);
            }
            if (dto.getDateOfBirth() != null) u.setDateOfBirth(dto.getDateOfBirth());
            if (dto.getAddress() != null) u.setAddress(dto.getAddress().trim());
            if (dto.getAvatarUrl() != null) {
                u.setAvatarUrl(dto.getAvatarUrl().trim());
            }
            User savedUser = userRepository.save(u);
            profile.setUser(savedUser);
        }

        TrainerProfile saved = trainerProfileRepository.save(profile);
        return mapToDTO(saved);
    }

    @Override
    @Transactional
    public TrainerProfileDTO submitProfileForReview(String email, TrainerProfileDTO dto) {
        User user = userRepository.findByEmail(email)
                .orElseThrow(() -> new UsernameNotFoundException("User not found with email: " + email));
        assertEligibleSelfServiceUser(user);

        TrainerProfile profile = trainerProfileRepository.findById(user.getId())
                .orElseThrow(() -> new ApiException("Trainer profile not found for user: " + email, HttpStatus.NOT_FOUND));

        if (!STATUS_PENDING.equalsIgnoreCase(profile.getStatus())) {
            throw new ApiException("Only a pending trainer application can be submitted for initial review.",
                    HttpStatus.CONFLICT);
        }

        // 1. Sync any incoming updates first
        saveProfileDraft(email, dto);
        profile = trainerProfileRepository.findById(user.getId())
                .orElseThrow(() -> new ApiException("Trainer profile not found for user: " + email, HttpStatus.NOT_FOUND));

        // 2. Re-validate persisted state, not just the incoming request.
        validateCompleteProfile(profile, user);

        // 3. Mark submitted and freeze edits
        profile.setStatus(STATUS_AWAITING);
        profile.setSubmittedAt(LocalDateTime.now());
        // Preserve previous adminNotes so the reviewing admin can verify what was previously requested

        TrainerProfile saved = trainerProfileRepository.save(profile);
        log.info("Trainer profile submitted for review for user ID: {}", user.getId());

        notifyAdminsOfSubmission(user, email, false);


        return mapToDTO(saved);
    }

    @Override
    @Transactional
    public TrainerProfileDTO submitCredentialUpdate(String email, TrainerProfileDTO dto) {
        if (dto == null || !hasDocumentPayload(dto)) {
            throw new ApiException("Credential documents are required.", HttpStatus.BAD_REQUEST);
        }
        User user = userRepository.findByEmail(email)
                .orElseThrow(() -> new UsernameNotFoundException("User not found with email: " + email));
        if (!hasRole(user, "TRAINER")) {
            throw new ApiException("Only trainer accounts can submit credential updates.", HttpStatus.FORBIDDEN);
        }

        TrainerProfile profile = trainerProfileRepository.findByIdForUpdate(user.getId())
                .orElseThrow(() -> new ApiException("Trainer profile not found for user: " + email,
                        HttpStatus.NOT_FOUND));
        if (!STATUS_VERIFIED.equalsIgnoreCase(profile.getStatus())) {
            throw new ApiException("Only a verified trainer can submit a credential update.", HttpStatus.CONFLICT);
        }

        List<TrainerDocumentDTO> incomingDocuments = resolveDocuments(dto);
        if (documentsEquivalent(extractDocuments(profile), incomingDocuments)) {
            throw new ApiException("No credential changes were detected.", HttpStatus.BAD_REQUEST);
        }
        applyDocuments(profile, incomingDocuments);
        validateCredentialDocuments(profile);
        profile.setStatus(STATUS_AWAITING);
        profile.setSubmittedAt(LocalDateTime.now());
        profile.setAdminNotes(null);

        TrainerProfile saved = trainerProfileRepository.save(profile);
        notifyAdminsOfSubmission(user, email, true);
        return mapToDTO(saved);
    }

    @Override
    @Transactional(readOnly = true)
    public List<TrainerProfileDTO> getTrainerProfilesForAdmin(String search, String status) {
        List<TrainerProfile> all = trainerProfileRepository.findAllWithUser();
        List<TrainerProfile> filtered = new ArrayList<>();

        for (TrainerProfile p : all) {
            try {
                if (p.getUser() == null || p.getUser().getEmail() == null) {
                    continue; // Skip orphan profiles without valid user
                }
            } catch (Exception e) {
                log.warn("Skipping orphan trainer profile user_id {}: missing User entity", p.getUserId());
                continue;
            }

            // Apply status filter
            if (status != null && !status.trim().isEmpty() && !"ALL".equalsIgnoreCase(status.trim())) {
                String reqStatus = status.trim().toUpperCase();
                if ("REJECTED".equals(reqStatus) || "PENDING_VERIFICATION".equals(reqStatus)) {
                    boolean isRejected = "PENDING_VERIFICATION".equalsIgnoreCase(p.getStatus()) ||
                            "SUSPENDED".equalsIgnoreCase(p.getStatus()) ||
                            "REJECTED".equalsIgnoreCase(p.getStatus());
                    if (!isRejected) {
                        continue;
                    }
                } else if (!reqStatus.equalsIgnoreCase(p.getStatus())) {
                    continue;
                }
            }

            // Apply search query (email or full name)
            if (search != null && !search.trim().isEmpty()) {
                String q = search.trim().toLowerCase();
                String name = "";
                String email = "";
                try {
                    name = p.getUser().getFullName() != null ? p.getUser().getFullName() : "";
                    email = p.getUser().getEmail() != null ? p.getUser().getEmail() : "";
                } catch (Exception e) {
                    continue;
                }
                if (!name.toLowerCase().contains(q) && !email.toLowerCase().contains(q)) {
                    continue;
                }
            }

            filtered.add(p);
        }

        // Sort by submission date (newest first)
        filtered.sort((p1, p2) -> {
            if (p1.getSubmittedAt() == null && p2.getSubmittedAt() == null) return 0;
            if (p1.getSubmittedAt() == null) return 1;
            if (p2.getSubmittedAt() == null) return -1;
            return p2.getSubmittedAt().compareTo(p1.getSubmittedAt());
        });

        return filtered.stream().map(this::mapToAdminDTO).collect(Collectors.toList());
    }

    @Override
    @Transactional
    public TrainerProfileDTO reviewTrainerProfile(Long userId, TrainerReviewRequest request) {
        TrainerProfile profile = trainerProfileRepository.findByIdForUpdate(userId)
                .orElseThrow(() -> new ApiException("Trainer profile not found for user ID: " + userId, HttpStatus.NOT_FOUND));

        String newStatus = normalizeReviewStatus(request != null ? request.getStatus() : null);
        String currentStatus = normalizeStoredStatus(profile.getStatus());
        validateReviewTransition(currentStatus, newStatus);
        String adminNotes = request != null ? trimToNull(request.getAdminNotes()) : null;
        if (!STATUS_VERIFIED.equals(newStatus) && adminNotes == null) {
            throw new ApiException("Administrator notes are required when requesting revisions or suspending a trainer.",
                    HttpStatus.BAD_REQUEST);
        }

        if (STATUS_VERIFIED.equals(newStatus)) {
            validateCompleteProfile(profile, profile.getUser());
        }

        profile.setStatus(newStatus);
        profile.setReviewedAt(LocalDateTime.now());
        profile.setAdminNotes(adminNotes);

        if (STATUS_VERIFIED.equals(newStatus)) {
            double resolvedShare = request != null && request.getRevenueShare() != null
                    ? validateReviewRevenueShare(request.getRevenueShare())
                    : defaultRevenueShareForTrainerType(profile.getTrainerType());
            profile.setRevenueShare(resolvedShare);

            // Automatically grant TRAINER role to user if not already present
            if (profile.getUser() != null) {
                User user = profile.getUser();
                Role trainerRole = roleRepository.findByRoleName("TRAINER")
                        .orElseGet(() -> roleRepository.save(Role.builder().roleName("TRAINER").build()));
                if (user.getRoles() == null) {
                    user.setRoles(new HashSet<>());
                }
                boolean alreadyTrainer = user.getRoles().stream()
                        .anyMatch(role -> "TRAINER".equalsIgnoreCase(role.getRoleName()));
                if (!alreadyTrainer) {
                    user.getRoles().add(trainerRole);
                    userRepository.save(user);
                    log.info("Granted TRAINER role to user ID: {}", user.getId());
                }
            }
            log.info("Admin APPROVED trainer ID: {} with split rate: {}", userId, profile.getRevenueShare());
        } else {
            log.info("Admin reviewed trainer ID: {} with new status: {}", userId, newStatus);
        }

        TrainerProfile saved = trainerProfileRepository.save(profile);
        if (saved.getUser() != null && saved.getUser().getEmail() != null) {
            String trainerName = (saved.getUser().getFullName() != null && !saved.getUser().getFullName().trim().isEmpty())
                    ? saved.getUser().getFullName().trim()
                    : saved.getUser().getUsername();
            sendTrainerStatusEmailAfterCommit(
                    saved.getUser().getEmail(),
                    trainerName,
                    newStatus,
                    adminNotes);
        }
        if (saved.getUser() != null) {
            boolean approved = STATUS_VERIFIED.equals(newStatus);
            boolean suspended = STATUS_SUSPENDED.equals(newStatus);
            
            String notifTitle;
            String notifMsg;
            if (approved) {
                notifTitle = "Trainer Application Approved";
                notifMsg = "Congratulations! Your trainer application has been approved by administration.";
            } else if (suspended) {
                notifTitle = "Trainer Account Suspended";
                notifMsg = "Your trainer account status has been set to SUSPENDED." +
                        (adminNotes != null ? " Reason: " + adminNotes : "");
            } else {
                notifTitle = "Trainer Application Revisions Requested";
                notifMsg = "Your trainer application requires modifications before approval." +
                        (adminNotes != null ? " Reason: " + adminNotes : "");
            }

            try {
                notificationService.notifyUser(
                        saved.getUser(),
                        NotificationService.TYPE_TRAINER_APPLICATION_REVIEWED,
                        notifTitle,
                        notifMsg,
                        null);
            } catch (Exception e) {
                log.warn("Failed to send trainer review in-app notification: {}", e.getMessage());
            }
        }
        return mapToDTO(saved);
    }

    private void sendTrainerStatusEmailAfterCommit(String email, String trainerName, String status, String adminNotes) {
        Runnable sendEmail = () -> {
            try {
                emailService.sendTrainerStatusNotificationEmail(email, trainerName, status, adminNotes);
            } catch (Exception e) {
                log.warn("Failed to send trainer status email notification: {}", e.getMessage());
            }
        };

        if (TransactionSynchronizationManager.isSynchronizationActive()) {
            TransactionSynchronizationManager.registerSynchronization(new TransactionSynchronization() {
                @Override
                public void afterCommit() {
                    sendEmail.run();
                }
            });
        } else {
            // Keeps direct/unit-test invocations deterministic when no Spring
            // transaction synchronization is active.
            sendEmail.run();
        }
    }

    private TrainerProfileDTO mapToDTO(TrainerProfile p) {
        String fullName = "N/A";
        String email = "N/A";
        String phoneNumber = "N/A";
        String gender = null;
        String avatarUrl = null;
        String username = null;
        java.time.LocalDate dateOfBirth = null;
        String address = null;

        try {
            User user = p.getUser();
            if (user != null) {
                fullName = user.getFullName() != null ? user.getFullName() : "N/A";
                email = user.getEmail() != null ? user.getEmail() : "N/A";
                phoneNumber = user.getPhoneNumber() != null ? user.getPhoneNumber() : "N/A";
                gender = user.getGender();
                avatarUrl = user.getAvatarUrl();
                username = user.getUsername();
                dateOfBirth = user.getDateOfBirth();
                address = user.getAddress();
            }
        } catch (Exception e) {
            log.warn("Could not load User entity for trainer_profile user_id {}: {}", p.getUserId(), e.getMessage());
        }

        return TrainerProfileDTO.builder()
                .userId(p.getUserId())
                .trainerType(p.getTrainerType())
                .revenueShare(p.getRevenueShare())
                .bio(p.getBio())
                .scoreReportUrl(p.getScoreReportUrl())
                .pedagogicalDegreeUrl(p.getPedagogicalDegreeUrl())
                .cvUrl(p.getCvUrl())
                .certificates(extractDocuments(p))
                .bankName(p.getBankName())
                .bankAccount(p.getBankAccount())
                .bankAccountName(p.getBankAccountName())
                .taxCode(p.getTaxCode())
                .citizenId(p.getCitizenId())
                .agreementSigned(p.getAgreementSigned())
                .agreementVersion(p.getAgreementVersion())
                .agreementAcceptedAt(p.getAgreementAcceptedAt())
                .status(p.getStatus())
                .submittedAt(p.getSubmittedAt())
                .reviewedAt(p.getReviewedAt())
                .adminNotes(p.getAdminNotes())
                .fullName(fullName)
                .email(email)
                .phoneNumber(phoneNumber)
                .gender(gender)
                .avatarUrl(avatarUrl)
                .username(username)
                .dateOfBirth(dateOfBirth)
                .address(address)
                .build();
    }

    private TrainerProfileDTO mapToAdminDTO(TrainerProfile profile) {
        TrainerProfileDTO dto = mapToDTO(profile);
        // Trainer review does not require payout credentials. Keep sensitive data
        // out of list responses that are retained in browser memory.
        dto.setBankName(null);
        dto.setBankAccount(null);
        dto.setBankAccountName(null);
        dto.setTaxCode(null);
        dto.setCitizenId(null);
        return dto;
    }

    private boolean hasDocumentPayload(TrainerProfileDTO dto) {
        return dto.getCertificates() != null
                || dto.getScoreReportUrl() != null
                || dto.getPedagogicalDegreeUrl() != null
                || dto.getCvUrl() != null;
    }

    private List<TrainerDocumentDTO> resolveDocuments(TrainerProfileDTO dto) {
        List<TrainerDocumentDTO> rawDocuments = new ArrayList<>();

        if (dto.getCertificates() != null) {
            rawDocuments.addAll(dto.getCertificates());
        } else if (!isEmpty(dto.getScoreReportUrl()) && dto.getScoreReportUrl().trim().startsWith("[")) {
            rawDocuments.addAll(parseDocumentsJson(dto.getScoreReportUrl()));
        }

        Map<String, TrainerDocumentDTO> byUrl = new LinkedHashMap<>();
        for (TrainerDocumentDTO document : rawDocuments) {
            TrainerDocumentDTO normalized = normalizeDocument(document, true);
            if (normalized != null) {
                byUrl.put(normalized.getUrl(), normalized);
            }
        }

        mergeIncomingLegacyUrl(byUrl, dto.getPedagogicalDegreeUrl(), DOC_TYPE_PEDAGOGICAL_DEGREE,
                canonicalTitleForType(DOC_TYPE_PEDAGOGICAL_DEGREE));
        mergeIncomingLegacyUrl(byUrl, dto.getCvUrl(), DOC_TYPE_TEACHING_CV,
                canonicalTitleForType(DOC_TYPE_TEACHING_CV));

        if (!isEmpty(dto.getScoreReportUrl()) && !dto.getScoreReportUrl().trim().startsWith("[")) {
            mergeIncomingLegacyUrl(byUrl, dto.getScoreReportUrl(), DOC_TYPE_OTHER,
                    canonicalTitleForType(DOC_TYPE_OTHER));
        }
        if (byUrl.size() > MAX_DOCUMENTS) {
            throw new ApiException("A trainer profile can contain at most 10 credential documents.",
                    HttpStatus.BAD_REQUEST);
        }

        return new ArrayList<>(byUrl.values());
    }

    private List<TrainerDocumentDTO> extractDocuments(TrainerProfile profile) {
        Map<String, TrainerDocumentDTO> byUrl = new LinkedHashMap<>();

        for (TrainerDocumentDTO document : parseDocumentsJson(profile.getScoreReportUrl())) {
            TrainerDocumentDTO normalized = normalizeDocument(document, false);
            if (normalized != null) {
                byUrl.put(normalized.getUrl(), normalized);
            }
        }

        mergeStoredLegacyUrl(byUrl, profile.getPedagogicalDegreeUrl(), DOC_TYPE_PEDAGOGICAL_DEGREE,
                canonicalTitleForType(DOC_TYPE_PEDAGOGICAL_DEGREE));
        mergeStoredLegacyUrl(byUrl, profile.getCvUrl(), DOC_TYPE_TEACHING_CV,
                canonicalTitleForType(DOC_TYPE_TEACHING_CV));

        if (byUrl.isEmpty() && !isEmpty(profile.getScoreReportUrl()) && !profile.getScoreReportUrl().trim().startsWith("[")) {
            mergeStoredLegacyUrl(byUrl, profile.getScoreReportUrl(), DOC_TYPE_OTHER,
                    canonicalTitleForType(DOC_TYPE_OTHER));
        }

        return new ArrayList<>(byUrl.values());
    }

    private List<TrainerDocumentDTO> parseDocumentsJson(String rawJson) {
        if (isEmpty(rawJson) || !rawJson.trim().startsWith("[")) {
            return List.of();
        }

        try {
            List<TrainerDocumentDTO> parsed = objectMapper.readValue(
                    rawJson,
                    new TypeReference<List<TrainerDocumentDTO>>() {});
            return parsed != null ? parsed : List.of();
        } catch (JsonProcessingException e) {
            log.warn("Could not parse trainer document JSON payload: {}", e.getMessage());
            return List.of();
        }
    }

    private void applyDocuments(TrainerProfile profile, List<TrainerDocumentDTO> rawDocuments) {
        List<TrainerDocumentDTO> documents = rawDocuments.stream()
                .filter(Objects::nonNull)
                .collect(Collectors.toList());

        if (documents.isEmpty()) {
            profile.setScoreReportUrl(null);
            profile.setPedagogicalDegreeUrl(null);
            profile.setCvUrl(null);
            return;
        }

        profile.setScoreReportUrl(writeDocumentsJson(documents));
        profile.setPedagogicalDegreeUrl(findFirstUrlByTypes(documents, DOC_TYPE_PEDAGOGICAL_DEGREE, DOC_TYPE_TEACHING_CERTIFICATE));
        profile.setCvUrl(findFirstUrlByTypes(documents, DOC_TYPE_TEACHING_CV));
    }

    private String writeDocumentsJson(List<TrainerDocumentDTO> documents) {
        try {
            return objectMapper.writeValueAsString(documents);
        } catch (JsonProcessingException e) {
            throw new IllegalStateException("Could not serialize trainer documents.", e);
        }
    }

    private TrainerDocumentDTO normalizeDocument(TrainerDocumentDTO document, boolean rejectUnsafe) {
        if (document == null || isEmpty(document.getUrl())) {
            return null;
        }

        String url = document.getUrl().trim();
        if (!isManagedCloudinaryUrl(url)) {
            if (rejectUnsafe) {
                throw new ApiException("Trainer credential URLs must use HanGo-managed Cloudinary HTTPS storage.",
                        HttpStatus.BAD_REQUEST);
            }
            log.warn("Ignoring unmanaged trainer credential URL for an existing profile.");
            return null;
        }

        String normalizedType = !isEmpty(document.getType())
                ? document.getType().trim().toUpperCase(Locale.ROOT)
                : null;
        if (normalizedType != null && !isKnownDocumentType(normalizedType)) {
            if (rejectUnsafe) {
                throw new ApiException("Unsupported trainer credential type.", HttpStatus.BAD_REQUEST);
            }
            normalizedType = DOC_TYPE_OTHER;
        }
        String type = normalizedType != null ? normalizedType : DOC_TYPE_OTHER;
        String name = !isEmpty(document.getName()) ? document.getName().trim() : canonicalTitleForType(type);
        if (name.length() > 200) {
            throw new ApiException("Trainer credential names must not exceed 200 characters.",
                    HttpStatus.BAD_REQUEST);
        }

        TrainerDocumentDTO.TrainerDocumentDTOBuilder builder = TrainerDocumentDTO.builder()
                .type(type)
                .name(name)
                .url(url);

        if (!isEmpty(document.getIssuingInstitution())) {
            builder.issuingInstitution(document.getIssuingInstitution().trim());
        }
        if (!isEmpty(document.getHolderName())) {
            builder.holderName(document.getHolderName().trim());
        }
        if (!isEmpty(document.getSource())) {
            builder.source(document.getSource().trim());
        }

        return builder.build();
    }

    private boolean isKnownDocumentType(String type) {
        return DOC_TYPE_PEDAGOGICAL_DEGREE.equals(type)
                || DOC_TYPE_TEACHING_CERTIFICATE.equals(type)
                || DOC_TYPE_LANGUAGE_PROFICIENCY.equals(type)
                || DOC_TYPE_ACADEMIC_TRANSCRIPT.equals(type)
                || DOC_TYPE_TEACHING_CV.equals(type)
                || DOC_TYPE_OTHER.equals(type);
    }

    private void mergeIncomingLegacyUrl(Map<String, TrainerDocumentDTO> byUrl, String url, String type, String name) {
        if (isEmpty(url)) {
            return;
        }

        TrainerDocumentDTO normalized = normalizeDocument(TrainerDocumentDTO.builder()
                .type(type)
                .name(name)
                .url(url.trim())
                .build(), true);
        byUrl.putIfAbsent(normalized.getUrl(), normalized);
    }

    private void mergeStoredLegacyUrl(Map<String, TrainerDocumentDTO> byUrl, String url, String type, String name) {
        if (isEmpty(url)) {
            return;
        }
        TrainerDocumentDTO normalized = normalizeDocument(TrainerDocumentDTO.builder()
                .type(type)
                .name(name)
                .url(url.trim())
                .build(), false);
        if (normalized != null) {
            byUrl.putIfAbsent(normalized.getUrl(), normalized);
        }
    }

    private String findFirstUrlByTypes(List<TrainerDocumentDTO> documents, String... types) {
        for (TrainerDocumentDTO document : documents) {
            if (document == null || isEmpty(document.getUrl())) {
                continue;
            }
            for (String type : types) {
                if (type.equalsIgnoreCase(document.getType())) {
                    return document.getUrl();
                }
            }
        }
        return null;
    }

    private boolean isPedagogicalDocumentType(String type) {
        return DOC_TYPE_PEDAGOGICAL_DEGREE.equalsIgnoreCase(type)
                || DOC_TYPE_TEACHING_CERTIFICATE.equalsIgnoreCase(type);
    }

    private String canonicalTitleForType(String type) {
        return switch (type) {
            case DOC_TYPE_PEDAGOGICAL_DEGREE -> "Bachelor of English Pedagogy Degree";
            case DOC_TYPE_TEACHING_CERTIFICATE -> "TEFL / TESOL Teaching Certificate";
            case DOC_TYPE_LANGUAGE_PROFICIENCY -> "IELTS / Proficiency Certificate";
            case DOC_TYPE_ACADEMIC_TRANSCRIPT -> "High School Academic Records";
            case DOC_TYPE_TEACHING_CV -> "Professional Teaching CV / Resume";
            default -> "Other Credential Proof";
        };
    }

    private boolean isManagedCloudinaryUrl(String rawUrl) {
        try {
            URI uri = URI.create(rawUrl);
            if (!"https".equalsIgnoreCase(uri.getScheme())
                    || !"res.cloudinary.com".equalsIgnoreCase(uri.getHost())) {
                return false;
            }
            String path = uri.getPath();
            if (isEmpty(path)) {
                return false;
            }
            if (!isEmpty(cloudinaryCloudName)) {
                return path.startsWith("/" + cloudinaryCloudName.trim() + "/");
            }
            return path.split("/").length >= 4;
        } catch (IllegalArgumentException e) {
            return false;
        }
    }

    private boolean documentsEquivalent(List<TrainerDocumentDTO> first, List<TrainerDocumentDTO> second) {
        return documentFingerprints(first).equals(documentFingerprints(second));
    }

    private List<String> documentFingerprints(List<TrainerDocumentDTO> documents) {
        return documents.stream()
                .filter(Objects::nonNull)
                .map(document -> String.join("|",
                        Objects.toString(document.getType(), ""),
                        Objects.toString(document.getName(), ""),
                        Objects.toString(document.getUrl(), ""),
                        Objects.toString(document.getIssuingInstitution(), ""),
                        Objects.toString(document.getHolderName(), "")))
                .sorted(Comparator.naturalOrder())
                .toList();
    }

    private void validateDraftFields(TrainerProfileDTO dto) {
        requireMaxLength(dto.getBio(), 5000, "Bio");
        requireMaxLength(dto.getBankName(), 100, "Bank name");
        requireMaxLength(dto.getBankAccount(), 50, "Bank account");
        requireMaxLength(dto.getBankAccountName(), 100, "Bank account owner name");
        requireMaxLength(dto.getTaxCode(), 50, "Tax code");
        requireMaxLength(dto.getCitizenId(), 50, "Citizen ID");
        requireMaxLength(dto.getUsername(), 100, "Username");
        requireMaxLength(dto.getAddress(), 500, "Address");
        requireMaxLength(dto.getAvatarUrl(), 2048, "Avatar URL");

        String avatarUrl = trimToNull(dto.getAvatarUrl());
        if (avatarUrl != null && !isTrustedAvatarUrl(avatarUrl)) {
            throw new ApiException("Avatar URL must reference a trusted HTTPS image.", HttpStatus.BAD_REQUEST);
        }

        String phone = trimToNull(dto.getPhoneNumber());
        if (phone != null && !isValidVietnamesePhone(phone)) {
            throw new ApiException("A valid Vietnamese contact phone number is required.", HttpStatus.BAD_REQUEST);
        }
        String bankAccount = trimToNull(dto.getBankAccount());
        if (bankAccount != null
                && (!bankAccount.matches("\\d{6,20}") || isDummyFinancialNumber(bankAccount))) {
            throw new ApiException("Bank account number must contain 6 to 20 digits.", HttpStatus.BAD_REQUEST);
        }
        String accountName = trimToNull(dto.getBankAccountName());
        if (accountName != null && !accountName.toUpperCase(Locale.ROOT).matches("[A-Z ]{2,100}")) {
            throw new ApiException("Bank account owner name must contain uppercase unaccented letters only.",
                    HttpStatus.BAD_REQUEST);
        }
        String taxCode = trimToNull(dto.getTaxCode());
        if (taxCode != null
                && (!taxCode.matches("\\d{10}(\\d{3})?") || isDummyFinancialNumber(taxCode))) {
            throw new ApiException("Tax code must contain 10 or 13 digits.", HttpStatus.BAD_REQUEST);
        }
        String citizenId = trimToNull(dto.getCitizenId());
        if (citizenId != null
                && (!citizenId.matches("\\d{12}") || isDummyFinancialNumber(citizenId))) {
            throw new ApiException("Citizen ID must contain exactly 12 digits.", HttpStatus.BAD_REQUEST);
        }
        if (dto.getCertificates() != null && dto.getCertificates().size() > MAX_DOCUMENTS) {
            throw new ApiException("A trainer profile can contain at most 10 credential documents.",
                    HttpStatus.BAD_REQUEST);
        }
    }

    private void validateCompleteProfile(TrainerProfile profile, User user) {
        if (isEmpty(profile.getTrainerType()) || !ALLOWED_TRAINER_TYPES.contains(profile.getTrainerType().toUpperCase(Locale.ROOT))) {
            throw new ApiException("A valid trainer type is required.", HttpStatus.BAD_REQUEST);
        }
        if (isEmpty(profile.getBio()) || profile.getBio().trim().length() < 50) {
            throw new ApiException("Bio must be at least 50 characters long.", HttpStatus.BAD_REQUEST);
        }
        if (!Boolean.TRUE.equals(profile.getAgreementSigned())) {
            throw new ApiException("Please review and accept the trainer agreement before submitting your application.",
                    HttpStatus.BAD_REQUEST);
        }

        String phone = user != null ? user.getPhoneNumber() : null;
        if (!isValidVietnamesePhone(phone)) {
            throw new ApiException("A valid 10-digit contact phone number starting with 03/05/07/08/09 is required.",
                    HttpStatus.BAD_REQUEST);
        }
        if (user == null || isEmpty(user.getGender())) {
            throw new ApiException("Please select your gender.", HttpStatus.BAD_REQUEST);
        }
        if (user == null || isEmpty(user.getAvatarUrl())) {
            throw new ApiException("Please upload an avatar image.", HttpStatus.BAD_REQUEST);
        }
        validateCredentialDocuments(profile);
    }

    private void validateCredentialDocuments(TrainerProfile profile) {
        List<TrainerDocumentDTO> documents = extractDocuments(profile);
        if (documents.isEmpty()) {
            throw new ApiException("Please upload at least one credentials proof document or CV.",
                    HttpStatus.BAD_REQUEST);
        }
        boolean hasPedagogicalProof = documents.stream()
                .map(TrainerDocumentDTO::getType)
                .anyMatch(this::isPedagogicalDocumentType);
        if (TRAINER_TYPE_PROFESSIONAL.equalsIgnoreCase(profile.getTrainerType()) && !hasPedagogicalProof) {
            throw new ApiException("A teaching/pedagogical degree or certificate is required for Teacher applications.",
                    HttpStatus.BAD_REQUEST);
        }
    }

    private boolean isValidVietnamesePhone(String phone) {
        if (phone == null) {
            return false;
        }
        String normalized = phone.trim();
        return normalized.matches("^(03|05|07|08|09)\\d{8}$")
                && !normalized.matches("^(\\d)\\1{9}$")
                && !"1234567890".equals(normalized);
    }

    private boolean isDummyFinancialNumber(String value) {
        return value.matches("^(\\d)\\1+$")
                || "1234567890".equals(value)
                || "123456789012".equals(value)
                || "1234567890123".equals(value)
                || "0123456789".equals(value);
    }

    private boolean isTrustedAvatarUrl(String rawUrl) {
        try {
            URI uri = URI.create(rawUrl);
            if (!"https".equalsIgnoreCase(uri.getScheme())) {
                return false;
            }
            String host = Objects.toString(uri.getHost(), "").toLowerCase(Locale.ROOT);
            if ("lh3.googleusercontent.com".equals(host)) {
                return true;
            }
            String path = Objects.toString(uri.getPath(), "").toLowerCase(Locale.ROOT);
            return "res.cloudinary.com".equals(host)
                    && path.contains("/image/upload/")
                    && (path.endsWith(".png") || path.endsWith(".jpg")
                        || path.endsWith(".jpeg") || path.endsWith(".webp"));
        } catch (IllegalArgumentException e) {
            return false;
        }
    }

    private void validateReviewTransition(String currentStatus, String newStatus) {
        boolean allowed = switch (currentStatus) {
            case STATUS_AWAITING -> ALLOWED_REVIEW_STATUSES.contains(newStatus);
            case STATUS_VERIFIED -> STATUS_SUSPENDED.equals(newStatus);
            case STATUS_SUSPENDED -> STATUS_VERIFIED.equals(newStatus);
            default -> false;
        };
        if (!allowed) {
            throw new ApiException(
                    "Invalid trainer review transition from " + currentStatus + " to " + newStatus + ".",
                    HttpStatus.CONFLICT);
        }
    }

    private String normalizeStoredStatus(String status) {
        if (isEmpty(status) || "REJECTED".equalsIgnoreCase(status)) {
            return STATUS_PENDING;
        }
        return status.trim().toUpperCase(Locale.ROOT);
    }

    private void notifyAdminsOfSubmission(User user, String fallbackEmail, boolean credentialUpdate) {
        try {
            String trainerName = user.getFullName() != null ? user.getFullName() : fallbackEmail;
            notificationService.notifyRole(
                    NotificationService.RECIPIENT_ADMIN,
                    NotificationService.TYPE_TRAINER_APPLICATION_SUBMITTED,
                    credentialUpdate ? "Trainer Credential Update Submitted" : "New Trainer Application Submitted",
                    trainerName + (credentialUpdate
                            ? " submitted updated credentials for review."
                            : " submitted a trainer application for review."),
                    null);
        } catch (Throwable e) {
            log.warn("Could not send admin notification for trainer submission: {}", e.getMessage());
        }
    }

    private boolean hasRole(User user, String roleName) {
        return user != null && user.getRoles() != null && user.getRoles().stream()
                .map(Role::getRoleName)
                .filter(Objects::nonNull)
                .anyMatch(roleName::equalsIgnoreCase);
    }

    private String trimToNull(String value) {
        return isEmpty(value) ? null : value.trim();
    }

    private void requireMaxLength(String value, int maxLength, String fieldName) {
        if (value != null && value.length() > maxLength) {
            throw new ApiException(fieldName + " must not exceed " + maxLength + " characters.",
                    HttpStatus.BAD_REQUEST);
        }
    }

    private void assertEligibleSelfServiceUser(User user) {
        boolean eligible = user.getRoles() != null
                && user.getRoles().stream()
                        .map(Role::getRoleName)
                        .filter(Objects::nonNull)
                        .anyMatch(role -> "LEARNER".equalsIgnoreCase(role) || "TRAINER".equalsIgnoreCase(role));
        if (!eligible) {
            throw new ApiException("Only learner or trainer accounts can access the trainer onboarding flow.",
                    HttpStatus.FORBIDDEN);
        }
    }

    private String normalizeTrainerType(String trainerType) {
        String normalizedType = !isEmpty(trainerType)
                ? trainerType.trim().toUpperCase(Locale.ROOT)
                : TRAINER_TYPE_PROFESSIONAL;
        if (!ALLOWED_TRAINER_TYPES.contains(normalizedType)) {
            throw new ApiException("trainerType must be PROFESSIONAL or PEER_TUTOR.", HttpStatus.BAD_REQUEST);
        }
        return normalizedType;
    }

    private double defaultRevenueShareForTrainerType(String trainerType) {
        return TRAINER_TYPE_PEER_TUTOR.equalsIgnoreCase(trainerType) ? 0.60 : 0.70;
    }

    private String normalizeReviewStatus(String status) {
        if (isEmpty(status)) {
            throw new ApiException("status is required for trainer profile review.", HttpStatus.BAD_REQUEST);
        }
        String normalizedStatus = status.trim().toUpperCase(Locale.ROOT);
        if (!ALLOWED_REVIEW_STATUSES.contains(normalizedStatus)) {
            throw new ApiException("status must be one of VERIFIED, PENDING_VERIFICATION, or SUSPENDED.",
                    HttpStatus.BAD_REQUEST);
        }
        return normalizedStatus;
    }

    private double validateReviewRevenueShare(Double revenueShare) {
        if (revenueShare == null || revenueShare < 0.50 || revenueShare > 0.95) {
            throw new ApiException("Trainer revenue share must be between 0.50 (50%) and 0.95 (95%).",
                    HttpStatus.BAD_REQUEST);
        }
        return revenueShare;
    }

    private boolean isEmpty(String str) {
        return str == null || str.trim().isEmpty();
    }
}
