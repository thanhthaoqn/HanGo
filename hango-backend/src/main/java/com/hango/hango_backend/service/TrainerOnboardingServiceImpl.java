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
import com.hango.hango_backend.repository.RoleRepository;
import com.hango.hango_backend.repository.TrainerProfileRepository;
import com.hango.hango_backend.repository.UserRepository;
import com.hango.hango_backend.util.JwtUtils;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.security.core.userdetails.UsernameNotFoundException;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.text.Normalizer;
import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.HashSet;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.Objects;
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

    private final UserRepository userRepository;
    private final RoleRepository roleRepository;
    private final TrainerProfileRepository trainerProfileRepository;
    private final JwtUtils jwtUtils;
    private final EmailService emailService;
    private final NotificationService notificationService;
    private final org.springframework.jdbc.core.JdbcTemplate jdbcTemplate;
    private final ObjectMapper objectMapper;

    @jakarta.annotation.PostConstruct
    public void initSchemaFix() {
        try {
            jdbcTemplate.execute("ALTER TABLE trainer_profiles MODIFY COLUMN score_report_url LONGTEXT");
            log.info("Successfully altered trainer_profiles score_report_url to LONGTEXT.");

            // Clean up redundant columns if they still exist in DB
            String[] colsToDrop = {
                "slogan", "target_low_range", "target_mid_range", "target_high_range",
                "format_exam_prep", "format_grammar_vocab", "format_reading", "format_last_minute",
                "degree_url", "ielts_url"
            };
            for (String col : colsToDrop) {
                try {
                    jdbcTemplate.execute("ALTER TABLE trainer_profiles DROP COLUMN " + col);
                    log.info("Dropped redundant column: trainer_profiles.{}", col);
                } catch (Exception ignored) {}
            }
        } catch (Exception e) {
            log.warn("Failed schema fix on trainer_profiles: {}", e.getMessage());
        }
    }

    @Override
    @Transactional
    public LoginResponse becomeTrainer(String email, String trainerType) {
        User user = userRepository.findByEmail(email)
                .orElseThrow(() -> new UsernameNotFoundException("User not found with email: " + email));

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
            log.info("Granted Trainer role to user: {}", email);
        }

        // 2. Initialize TrainerProfile if missing
        TrainerProfile profile = trainerProfileRepository.findById(user.getId()).orElse(null);
        if (profile == null) {
            double defaultShare = "PEER_TUTOR".equalsIgnoreCase(trainerType) ? 0.60 : 0.70;
            profile = TrainerProfile.builder()
                    .user(user)
                    .trainerType(trainerType.toUpperCase())
                    .revenueShare(defaultShare)
                    .status("PENDING_VERIFICATION")
                    .build();
            trainerProfileRepository.save(profile);
            log.info("Initialized TrainerProfile for user ID: {} with type: {}", user.getId(), trainerType);
        } else if (trainerType != null) {
            // Update type if they switch before submitting
            if ("PENDING_VERIFICATION".equalsIgnoreCase(profile.getStatus())) {
                profile.setTrainerType(trainerType.toUpperCase());
                double defaultShare = "PEER_TUTOR".equalsIgnoreCase(trainerType) ? 0.60 : 0.70;
                profile.setRevenueShare(defaultShare);
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

        TrainerProfile profile = trainerProfileRepository.findById(user.getId())
                .orElseGet(() -> {
                    // Fallback JIT-creation for trainers without profiles
                    TrainerProfile newProfile = TrainerProfile.builder()
                            .user(user)
                            .trainerType(null)
                            .revenueShare(0.70)
                            .status("PENDING_VERIFICATION")
                            .build();
                    return trainerProfileRepository.save(newProfile);
                });

        return mapToDTO(profile);
    }

    @Override
    @Transactional
    public TrainerProfileDTO saveProfileDraft(String email, TrainerProfileDTO dto) {
        User user = userRepository.findByEmail(email)
                .orElseThrow(() -> new UsernameNotFoundException("User not found with email: " + email));

        TrainerProfile profile = trainerProfileRepository.findById(user.getId())
                .orElseThrow(() -> new IllegalArgumentException("Trainer profile not found for user: " + email));

        // Prevent modification if already waiting or suspended
        if ("AWAITING_APPROVAL".equalsIgnoreCase(profile.getStatus())) {
            throw new IllegalStateException("Application is currently awaiting approval. Profile details cannot be modified.");
        }
        if ("SUSPENDED".equalsIgnoreCase(profile.getStatus())) {
            throw new IllegalStateException("Your trainer account has been suspended.");
        }

        // Auto-save updating fields
        if (dto.getBio() != null) profile.setBio(dto.getBio());
        if (dto.getWorkplace() != null) profile.setWorkplace(dto.getWorkplace());
        if (dto.getAgreementSigned() != null) profile.setAgreementSigned(dto.getAgreementSigned());
        
        if (hasDocumentPayload(dto)) {
            applyDocuments(profile, resolveDocuments(dto));
        }

        if (dto.getBankName() != null) profile.setBankName(dto.getBankName());
        if (dto.getBankAccount() != null) profile.setBankAccount(dto.getBankAccount());
        if (dto.getBankAccountName() != null) profile.setBankAccountName(dto.getBankAccountName().toUpperCase());
        if (dto.getTaxCode() != null) profile.setTaxCode(dto.getTaxCode());
        if (dto.getCitizenId() != null) profile.setCitizenId(dto.getCitizenId());
        log.info("saveProfileDraft: email={}, incoming avatarUrl={}", email, dto.getAvatarUrl());
        User u = profile.getUser() != null ? profile.getUser() : user;
        if (u != null) {
            if (dto.getPhoneNumber() != null) u.setPhoneNumber(dto.getPhoneNumber());
            if (dto.getGender() != null) u.setGender(dto.getGender());
            if (dto.getUsername() != null && !dto.getUsername().equalsIgnoreCase(u.getUsername())) {
                if (userRepository.existsByUsername(dto.getUsername())) {
                    throw new IllegalArgumentException("Error: Username is already in use!");
                }
                u.setUsername(dto.getUsername());
            }
            if (dto.getDateOfBirth() != null) u.setDateOfBirth(dto.getDateOfBirth());
            if (dto.getAddress() != null) u.setAddress(dto.getAddress());
            if (dto.getAvatarUrl() != null) {
                log.info("saveProfileDraft: updating user avatar from {} to {}", u.getAvatarUrl(), dto.getAvatarUrl());
                u.setAvatarUrl(dto.getAvatarUrl());
            }
            User savedUser = userRepository.save(u);
            log.info("saveProfileDraft: user saved. persisted avatarUrl={}", savedUser.getAvatarUrl());
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

        TrainerProfile profile = trainerProfileRepository.findById(user.getId())
                .orElseThrow(() -> new IllegalArgumentException("Trainer profile not found for user: " + email));

        if ("AWAITING_APPROVAL".equalsIgnoreCase(profile.getStatus())) {
            throw new IllegalStateException("Application is currently under review.");
        }

        // 1. Sync any incoming updates first
        saveProfileDraft(email, dto);

        // 2. Validate mandatory fields
        if (isEmpty(profile.getBio()) || profile.getBio().trim().length() < 50) {
            throw new IllegalArgumentException("Teaching experience & bio must be at least 50 characters long.");
        }
        
        String phone = user != null ? user.getPhoneNumber() : null;
        boolean validPhone = phone != null 
                && phone.trim().matches("^(03|05|07|08|09)\\d{8}$") 
                && !phone.trim().matches("^(\\d)\\1{9}$") 
                && !"1234567890".equals(phone.trim());

        if (!validPhone) {
            throw new IllegalArgumentException("A valid 10-digit contact phone number starting with 03/05/07/08/09 is required.");
        }
        if (user == null || isEmpty(user.getGender())) {
            throw new IllegalArgumentException("Please select your gender.");
        }
        if (user == null || isEmpty(user.getAvatarUrl())) {
            throw new IllegalArgumentException("Please upload an avatar image.");
        }

        List<TrainerDocumentDTO> documents = extractDocuments(profile);
        boolean hasPedagogicalProof = documents.stream()
                .map(TrainerDocumentDTO::getType)
                .anyMatch(this::isPedagogicalDocumentType);
        boolean hasAnyProof = documents.stream()
                .map(TrainerDocumentDTO::getUrl)
                .anyMatch(url -> !isEmpty(url));

        if ("PROFESSIONAL".equalsIgnoreCase(profile.getTrainerType()) && !hasPedagogicalProof) {
            throw new IllegalArgumentException("A teaching/pedagogical degree or credential is required for Teacher applications.");
        }

        // At least one credentials proof document or CV
        if (!hasAnyProof) {
            throw new IllegalArgumentException("Please upload at least one credentials proof document or CV.");
        }

        // 3. Mark submitted and freeze edits
        profile.setStatus("AWAITING_APPROVAL");
        profile.setSubmittedAt(LocalDateTime.now());
        profile.setAdminNotes(null); // Clear previous admin rejection reasons

        TrainerProfile saved = trainerProfileRepository.save(profile);
        log.info("Trainer profile submitted for review: {}", email);

        try {
            String trainerName = user.getFullName() != null ? user.getFullName() : email;
            notificationService.notifyRole(
                    NotificationService.RECIPIENT_ADMIN,
                    NotificationService.TYPE_TRAINER_APPLICATION_SUBMITTED,
                    "New Trainer Application Submitted",
                    trainerName + " submitted a trainer application for review.",
                    null);
        } catch (Throwable e) {
            log.warn("Could not send admin notification for trainer submission: {}", e.getMessage());
        }


        return mapToDTO(saved);
    }

    @Override
    @Transactional(readOnly = true)
    public List<TrainerProfileDTO> getTrainerProfilesForAdmin(String search, String status) {
        List<TrainerProfile> all = trainerProfileRepository.findAll();
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
            if (p1.getSubmittedAt() == null) return 1;
            if (p2.getSubmittedAt() == null) return -1;
            return p2.getSubmittedAt().compareTo(p1.getSubmittedAt());
        });

        return filtered.stream().map(this::mapToDTO).collect(Collectors.toList());
    }

    @Override
    @Transactional
    public TrainerProfileDTO reviewTrainerProfile(Long userId, TrainerReviewRequest request) {
        TrainerProfile profile = trainerProfileRepository.findById(userId)
                .orElseThrow(() -> new IllegalArgumentException("Trainer profile not found for user ID: " + userId));

        String newStatus = request.getStatus().toUpperCase();
        profile.setStatus(newStatus);
        profile.setReviewedAt(LocalDateTime.now());
        profile.setAdminNotes(request.getAdminNotes());

        if ("VERIFIED".equalsIgnoreCase(newStatus)) {
            // Automatically assign fixed revenue share based on trainer type: 70% Teacher, 60% Tutor
            double autoShare = "PEER_TUTOR".equalsIgnoreCase(profile.getTrainerType()) ? 0.60 : 0.70;
            profile.setRevenueShare(autoShare);

            // Automatically grant TRAINER role to user if not already present
            if (profile.getUser() != null) {
                User user = profile.getUser();
                Role trainerRole = roleRepository.findByRoleName("TRAINER").orElse(null);
                if (trainerRole != null) {
                    if (user.getRoles() == null) {
                        user.setRoles(new java.util.HashSet<>());
                    }
                    if (!user.getRoles().contains(trainerRole)) {
                        user.getRoles().add(trainerRole);
                        userRepository.save(user);
                        log.info("Granted TRAINER role to user ID: {}", user.getId());
                    }
                }
            }
            log.info("Admin APPROVED trainer ID: {} with split rate: {}", userId, profile.getRevenueShare());
        } else {
            log.info("Admin reviewed trainer ID: {} with new status: {}", userId, newStatus);
        }

        TrainerProfile saved = trainerProfileRepository.save(profile);
        if (saved.getUser() != null && saved.getUser().getEmail() != null) {
            try {
                emailService.sendTrainerStatusNotificationEmail(saved.getUser().getEmail(), newStatus, request.getAdminNotes());
            } catch (Exception e) {
                log.warn("Failed to send trainer status email notification: {}", e.getMessage());
            }
        }
        if (saved.getUser() != null) {
            boolean approved = "VERIFIED".equalsIgnoreCase(newStatus);
            boolean suspended = "SUSPENDED".equalsIgnoreCase(newStatus);
            
            String notifTitle;
            String notifMsg;
            if (approved) {
                notifTitle = "Trainer Application Approved";
                notifMsg = "Congratulations! Your trainer application has been approved by administration.";
            } else if (suspended) {
                notifTitle = "Trainer Account Suspended";
                notifMsg = "Your trainer account status has been set to SUSPENDED." +
                        (request.getAdminNotes() != null && !request.getAdminNotes().isBlank()
                                ? " Reason: " + request.getAdminNotes() : "");
            } else {
                notifTitle = "Trainer Application Revisions Requested";
                notifMsg = "Your trainer application requires modifications before approval." +
                        (request.getAdminNotes() != null && !request.getAdminNotes().isBlank()
                                ? " Reason: " + request.getAdminNotes() : "");
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
                .workplace(p.getWorkplace())
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

    private boolean hasDocumentPayload(TrainerProfileDTO dto) {
        return dto.getCertificates() != null
                || dto.getScoreReportUrl() != null
                || dto.getPedagogicalDegreeUrl() != null
                || dto.getCvUrl() != null;
    }

    private List<TrainerDocumentDTO> resolveDocuments(TrainerProfileDTO dto) {
        List<TrainerDocumentDTO> documents = new ArrayList<>();

        if (dto.getCertificates() != null) {
            documents.addAll(dto.getCertificates());
        } else if (!isEmpty(dto.getScoreReportUrl()) && dto.getScoreReportUrl().trim().startsWith("[")) {
            documents.addAll(parseDocumentsJson(dto.getScoreReportUrl()));
        }

        Map<String, TrainerDocumentDTO> byUrl = new LinkedHashMap<>();
        for (TrainerDocumentDTO document : documents) {
            TrainerDocumentDTO normalized = normalizeDocument(document);
            if (normalized != null) {
                byUrl.put(normalized.getUrl(), normalized);
            }
        }

        mergeLegacyUrl(byUrl, dto.getPedagogicalDegreeUrl(), DOC_TYPE_PEDAGOGICAL_DEGREE, canonicalTitleForType(DOC_TYPE_PEDAGOGICAL_DEGREE));
        mergeLegacyUrl(byUrl, dto.getCvUrl(), DOC_TYPE_TEACHING_CV, canonicalTitleForType(DOC_TYPE_TEACHING_CV));

        if (!isEmpty(dto.getScoreReportUrl()) && !dto.getScoreReportUrl().trim().startsWith("[")) {
            String inferredType = inferDocumentType(null, dto.getScoreReportUrl(), null, null);
            mergeLegacyUrl(byUrl, dto.getScoreReportUrl(), inferredType, canonicalTitleForType(inferredType));
        }

        return new ArrayList<>(byUrl.values());
    }

    private List<TrainerDocumentDTO> extractDocuments(TrainerProfile profile) {
        Map<String, TrainerDocumentDTO> byUrl = new LinkedHashMap<>();

        for (TrainerDocumentDTO document : parseDocumentsJson(profile.getScoreReportUrl())) {
            TrainerDocumentDTO normalized = normalizeDocument(document);
            if (normalized != null) {
                byUrl.put(normalized.getUrl(), normalized);
            }
        }

        mergeLegacyUrl(byUrl, profile.getPedagogicalDegreeUrl(), DOC_TYPE_PEDAGOGICAL_DEGREE, canonicalTitleForType(DOC_TYPE_PEDAGOGICAL_DEGREE));
        mergeLegacyUrl(byUrl, profile.getCvUrl(), DOC_TYPE_TEACHING_CV, canonicalTitleForType(DOC_TYPE_TEACHING_CV));

        if (byUrl.isEmpty() && !isEmpty(profile.getScoreReportUrl()) && !profile.getScoreReportUrl().trim().startsWith("[")) {
            String inferredType = inferDocumentType(null, profile.getScoreReportUrl(), null, null);
            mergeLegacyUrl(byUrl, profile.getScoreReportUrl(), inferredType, canonicalTitleForType(inferredType));
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
                .map(this::normalizeDocument)
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

    private TrainerDocumentDTO normalizeDocument(TrainerDocumentDTO document) {
        if (document == null || isEmpty(document.getUrl())) {
            return null;
        }

        String type = shouldPreserveManualDocumentType(document.getType(), document.getSource())
                ? document.getType().trim().toUpperCase()
                : inferDocumentType(
                        document.getType(),
                        document.getName(),
                        document.getUrl(),
                        document.getIssuingInstitution());
        String name = !isEmpty(document.getName()) ? document.getName().trim() : canonicalTitleForType(type);

        TrainerDocumentDTO.TrainerDocumentDTOBuilder builder = TrainerDocumentDTO.builder()
                .type(type)
                .name(name)
                .url(document.getUrl().trim());

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

    private boolean shouldPreserveManualDocumentType(String explicitType, String source) {
        String normalizedExplicitType = !isEmpty(explicitType) ? explicitType.trim().toUpperCase() : null;
        String normalizedSource = !isEmpty(source) ? source.trim().toLowerCase(Locale.ROOT) : null;

        return normalizedExplicitType != null
                && !DOC_TYPE_OTHER.equals(normalizedExplicitType)
                && isKnownDocumentType(normalizedExplicitType)
                && normalizedSource != null
                && normalizedSource.endsWith("_manual");
    }

    private boolean isKnownDocumentType(String type) {
        return DOC_TYPE_PEDAGOGICAL_DEGREE.equals(type)
                || DOC_TYPE_TEACHING_CERTIFICATE.equals(type)
                || DOC_TYPE_LANGUAGE_PROFICIENCY.equals(type)
                || DOC_TYPE_ACADEMIC_TRANSCRIPT.equals(type)
                || DOC_TYPE_TEACHING_CV.equals(type)
                || DOC_TYPE_OTHER.equals(type);
    }

    private void mergeLegacyUrl(Map<String, TrainerDocumentDTO> byUrl, String url, String type, String name) {
        if (isEmpty(url)) {
            return;
        }

        String trimmedUrl = url.trim();
        byUrl.computeIfAbsent(trimmedUrl, key -> TrainerDocumentDTO.builder()
                .type(type)
                .name(name)
                .url(trimmedUrl)
                .build());
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
                || DOC_TYPE_TEACHING_CERTIFICATE.equalsIgnoreCase(type)
                || DOC_TYPE_TEACHING_CV.equalsIgnoreCase(type);
    }

    private String inferDocumentType(String explicitType, String name, String url, String issuingInstitution) {
        String normalizedExplicitType = !isEmpty(explicitType) ? explicitType.trim().toUpperCase() : null;
        Map<String, Integer> scores = initializeDocumentScores();

        if (normalizedExplicitType != null && scores.containsKey(normalizedExplicitType)) {
            addDocumentScore(scores, normalizedExplicitType, 2);
        }

        scoreDocumentText(scores, name, 2);
        scoreDocumentText(scores, url, 1);
        scoreDocumentText(scores, issuingInstitution, 1);

        String detectedType = bestScoringDocumentType(scores);
        int detectedScore = scores.getOrDefault(detectedType, 0);

        if (normalizedExplicitType != null && scores.containsKey(normalizedExplicitType) && detectedScore <= 2) {
            return normalizedExplicitType;
        }

        if (detectedScore > 0) {
            return detectedType;
        }

        return normalizedExplicitType != null && scores.containsKey(normalizedExplicitType)
                ? normalizedExplicitType
                : DOC_TYPE_OTHER;
    }

    private Map<String, Integer> initializeDocumentScores() {
        Map<String, Integer> scores = new LinkedHashMap<>();
        scores.put(DOC_TYPE_PEDAGOGICAL_DEGREE, 0);
        scores.put(DOC_TYPE_TEACHING_CERTIFICATE, 0);
        scores.put(DOC_TYPE_LANGUAGE_PROFICIENCY, 0);
        scores.put(DOC_TYPE_ACADEMIC_TRANSCRIPT, 0);
        scores.put(DOC_TYPE_TEACHING_CV, 0);
        scores.put(DOC_TYPE_OTHER, 0);
        return scores;
    }

    private void scoreDocumentText(Map<String, Integer> scores, String rawText, int multiplier) {
        String normalizedText = normalizeComparableText(rawText);
        if (normalizedText.isBlank()) {
            return;
        }

        addScoreIfContains(scores, normalizedText, DOC_TYPE_TEACHING_CERTIFICATE, 8 * multiplier,
                "tefl", "tesol", "celta", "teaching certificate", "teaching certification",
                "teacher licence", "teacher license");
        addScoreIfContains(scores, normalizedText, DOC_TYPE_TEACHING_CERTIFICATE, 4 * multiplier,
                "teaching english", "lead trainer", "course director", "teaching practice");

        addScoreIfContains(scores, normalizedText, DOC_TYPE_LANGUAGE_PROFICIENCY, 8 * multiplier,
                "ielts", "toeic", "toefl", "aptis", "vstep", "test report form",
                "international english language testing system");
        addScoreIfContains(scores, normalizedText, DOC_TYPE_LANGUAGE_PROFICIENCY, 5 * multiplier,
                "trf", "british council", "idp", "cambridge english", "cambridge assessment",
                "certificate of proficiency");
        addScoreIfContains(scores, normalizedText, DOC_TYPE_LANGUAGE_PROFICIENCY, 3 * multiplier,
                "cefr", "language proficiency", "proficiency", "ngoai ngu");

        addScoreIfContains(scores, normalizedText, DOC_TYPE_PEDAGOGICAL_DEGREE, 8 * multiplier,
                "the degree of bachelor", "degree of bachelor", "bachelor of", "bang cu nhan",
                "bang tot nghiep", "cu nhan", "tot nghiep", "graduation diploma");
        addScoreIfContains(scores, normalizedText, DOC_TYPE_PEDAGOGICAL_DEGREE, 4 * multiplier,
                "pedagogy", "pedagogical", "pedagog", "su pham", "qualification", "degree",
                "diploma", "english language teaching");
        addScoreIfContains(scores, normalizedText, DOC_TYPE_PEDAGOGICAL_DEGREE, multiplier,
                "university", "college of foreign languages", "college", "dai hoc",
                "faculty of education");

        addScoreIfContains(scores, normalizedText, DOC_TYPE_ACADEMIC_TRANSCRIPT, 8 * multiplier,
                "hoc ba", "bang diem", "transcript", "academic records", "report card");
        addScoreIfContains(scores, normalizedText, DOC_TYPE_ACADEMIC_TRANSCRIPT, 4 * multiplier,
                "hoc luc", "grade table", "school year", "semester", "grade point");

        addScoreIfContains(scores, normalizedText, DOC_TYPE_TEACHING_CV, 8 * multiplier,
                "curriculum vitae", "resume", "teacher profile", "so yeu ly lich", " cv ");
        addScoreIfContains(scores, normalizedText, DOC_TYPE_TEACHING_CV, 4 * multiplier,
                "work experience", "employment history", "teaching experience", "career objective",
                "professional summary");
    }

    private void addScoreIfContains(Map<String, Integer> scores, String normalizedText, String type, int points,
                                    String... patterns) {
        for (String pattern : patterns) {
            if (normalizedText.contains(normalizeComparableText(pattern))) {
                addDocumentScore(scores, type, points);
            }
        }
    }

    private void addDocumentScore(Map<String, Integer> scores, String type, int points) {
        scores.put(type, scores.getOrDefault(type, 0) + points);
    }

    private String bestScoringDocumentType(Map<String, Integer> scores) {
        String bestType = DOC_TYPE_OTHER;
        int bestScore = -1;

        for (String type : List.of(
                DOC_TYPE_LANGUAGE_PROFICIENCY,
                DOC_TYPE_TEACHING_CERTIFICATE,
                DOC_TYPE_PEDAGOGICAL_DEGREE,
                DOC_TYPE_ACADEMIC_TRANSCRIPT,
                DOC_TYPE_TEACHING_CV,
                DOC_TYPE_OTHER)) {
            int score = scores.getOrDefault(type, 0);
            if (score > bestScore) {
                bestScore = score;
                bestType = type;
            }
        }

        return bestType;
    }

    private String normalizeComparableText(String rawText) {
        if (isEmpty(rawText)) {
            return "";
        }

        String normalized = Normalizer.normalize(rawText, Normalizer.Form.NFD)
                .replaceAll("\\p{M}+", "")
                .toLowerCase()
                .replace('\u0111', 'd')
                .replaceAll("[^a-z0-9]+", " ")
                .trim();

        return normalized.isEmpty() ? "" : " " + normalized + " ";
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

    private boolean isEmpty(String str) {
        return str == null || str.trim().isEmpty();
    }
}
