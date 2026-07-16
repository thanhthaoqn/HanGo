package com.hango.hango_backend.service;

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
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.security.core.userdetails.UsernameNotFoundException;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.HashSet;
import java.util.List;
import java.util.stream.Collectors;

@Service
@RequiredArgsConstructor
@Slf4j
public class TrainerOnboardingServiceImpl implements TrainerOnboardingService {

    private final UserRepository userRepository;
    private final RoleRepository roleRepository;
    private final TrainerProfileRepository trainerProfileRepository;
    private final JwtUtils jwtUtils;

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
            throw new IllegalStateException("Hồ sơ đang chờ duyệt, bạn không thể chỉnh sửa thông tin.");
        }
        if ("SUSPENDED".equalsIgnoreCase(profile.getStatus())) {
            throw new IllegalStateException("Tài khoản của bạn đã bị đình chỉ hoạt động.");
        }

        // Auto-save updating fields
        if (dto.getSlogan() != null) profile.setSlogan(dto.getSlogan());
        if (dto.getBio() != null) profile.setBio(dto.getBio());
        if (dto.getWorkplace() != null) profile.setWorkplace(dto.getWorkplace());
        if (dto.getAgreementSigned() != null) profile.setAgreementSigned(dto.getAgreementSigned());
        
        if (dto.getTargetLowRange() != null) profile.setTargetLowRange(dto.getTargetLowRange());
        if (dto.getTargetMidRange() != null) profile.setTargetMidRange(dto.getTargetMidRange());
        if (dto.getTargetHighRange() != null) profile.setTargetHighRange(dto.getTargetHighRange());

        if (dto.getFormatExamPrep() != null) profile.setFormatExamPrep(dto.getFormatExamPrep());
        if (dto.getFormatGrammarVocab() != null) profile.setFormatGrammarVocab(dto.getFormatGrammarVocab());
        if (dto.getFormatReading() != null) profile.setFormatReading(dto.getFormatReading());
        if (dto.getFormatLastMinute() != null) profile.setFormatLastMinute(dto.getFormatLastMinute());

        if (dto.getDegreeUrl() != null) profile.setDegreeUrl(dto.getDegreeUrl());
        if (dto.getIeltsUrl() != null) profile.setIeltsUrl(dto.getIeltsUrl());
        if (dto.getScoreReportUrl() != null) profile.setScoreReportUrl(dto.getScoreReportUrl());

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
            throw new IllegalStateException("Hồ sơ đang ở trạng thái chờ xét duyệt.");
        }

        // 1. Sync any incoming updates first
        saveProfileDraft(email, dto);

        // 2. Validate mandatory fields
        if (isEmpty(profile.getBio())) {
            throw new IllegalArgumentException("Vui lòng điền giới thiệu bản thân & kinh nghiệm giảng dạy.");
        }
        if (user == null || isEmpty(user.getPhoneNumber())) {
            throw new IllegalArgumentException("Vui lòng cung cấp số điện thoại liên hệ.");
        }

        // At least one certification proof
        if (isEmpty(profile.getDegreeUrl()) &&
            isEmpty(profile.getIeltsUrl()) &&
            isEmpty(profile.getScoreReportUrl())) {
            throw new IllegalArgumentException("Vui lòng tải lên ít nhất 1 tài liệu minh chứng năng lực.");
        }

        // 3. Mark submitted and freeze edits
        profile.setStatus("AWAITING_APPROVAL");
        profile.setSubmittedAt(LocalDateTime.now());
        profile.setAdminNotes(null); // Clear previous admin rejection reasons

        TrainerProfile saved = trainerProfileRepository.save(profile);
        log.info("Trainer profile submitted for review: {}", email);
        return mapToDTO(saved);
    }

    @Override
    @Transactional(readOnly = true)
    public List<TrainerProfileDTO> getTrainerProfilesForAdmin(String search, String status) {
        List<TrainerProfile> all = trainerProfileRepository.findAll();
        List<TrainerProfile> filtered = new ArrayList<>();

        for (TrainerProfile p : all) {
            // Apply status filter
            if (status != null && !status.equalsIgnoreCase("ALL")) {
                if (!status.equalsIgnoreCase(p.getStatus())) {
                    continue;
                }
            }

            // Apply search query (email or full name)
            if (search != null && !search.trim().isEmpty()) {
                String q = search.trim().toLowerCase();
                String name = p.getUser() != null ? p.getUser().getFullName() : "";
                String email = p.getUser() != null ? p.getUser().getEmail() : "";
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
                .orElseThrow(() -> new IllegalArgumentException("Không tìm thấy hồ sơ giảng viên cho ID người dùng: " + userId));

        String newStatus = request.getStatus().toUpperCase();
        profile.setStatus(newStatus);
        profile.setReviewedAt(LocalDateTime.now());
        profile.setAdminNotes(request.getAdminNotes());

        if ("VERIFIED".equalsIgnoreCase(newStatus)) {
            // Setup default split rate if not custom-ridden by the admin
            if (request.getRevenueShare() != null) {
                profile.setRevenueShare(request.getRevenueShare());
            } else {
                double defaultShare = "PEER_TUTOR".equalsIgnoreCase(profile.getTrainerType()) ? 0.60 : 0.70;
                profile.setRevenueShare(defaultShare);
            }
            log.info("Admin APPROVED trainer ID: {} with split rate: {}", userId, profile.getRevenueShare());
        } else {
            log.info("Admin reviewed trainer ID: {} with new status: {}", userId, newStatus);
        }

        TrainerProfile saved = trainerProfileRepository.save(profile);
        return mapToDTO(saved);
    }

    private TrainerProfileDTO mapToDTO(TrainerProfile p) {
        User user = p.getUser();
        return TrainerProfileDTO.builder()
                .userId(p.getUserId())
                .trainerType(p.getTrainerType())
                .revenueShare(p.getRevenueShare())
                .slogan(p.getSlogan())
                .bio(p.getBio())
                .workplace(p.getWorkplace())
                .targetLowRange(p.getTargetLowRange())
                .targetMidRange(p.getTargetMidRange())
                .targetHighRange(p.getTargetHighRange())
                .formatExamPrep(p.getFormatExamPrep())
                .formatGrammarVocab(p.getFormatGrammarVocab())
                .formatReading(p.getFormatReading())
                .formatLastMinute(p.getFormatLastMinute())
                .degreeUrl(p.getDegreeUrl())
                .ieltsUrl(p.getIeltsUrl())
                .scoreReportUrl(p.getScoreReportUrl())
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
                .fullName(user != null ? user.getFullName() : "N/A")
                .email(user != null ? user.getEmail() : "N/A")
                .phoneNumber(user != null ? user.getPhoneNumber() : "N/A")
                .gender(user != null ? user.getGender() : null)
                .avatarUrl(user != null ? user.getAvatarUrl() : null)
                .build();
    }

    private boolean isEmpty(String str) {
        return str == null || str.trim().isEmpty();
    }
}
