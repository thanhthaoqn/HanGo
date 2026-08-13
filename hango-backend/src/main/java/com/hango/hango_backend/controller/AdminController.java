package com.hango.hango_backend.controller;

import com.hango.hango_backend.repository.RoleRepository;
import com.hango.hango_backend.repository.UserRepository;
import com.hango.hango_backend.repository.AuditLogRepository;
import com.hango.hango_backend.repository.AiUsageLogRepository;
import com.hango.hango_backend.repository.CourseRepository;
import com.hango.hango_backend.repository.EnrollmentRepository;
import com.hango.hango_backend.repository.TopCourseProjection;
import com.hango.hango_backend.entity.User;
import com.hango.hango_backend.entity.Role;
import com.hango.hango_backend.entity.AuditLog;
import com.hango.hango_backend.entity.AiUsageLog;
import com.hango.hango_backend.entity.Comment;
import com.hango.hango_backend.repository.CommentRepository;
import com.hango.hango_backend.service.AuthService;
import com.hango.hango_backend.dto.RegisterRequest;
import com.hango.hango_backend.dto.UserResponse;
import com.hango.hango_backend.dto.AdminUserUpdateRequest;
import jakarta.validation.Valid;
import com.hango.hango_backend.entity.Permission;
import com.hango.hango_backend.repository.PermissionRepository;
import com.hango.hango_backend.dto.RoleDTO;
import com.hango.hango_backend.dto.PermissionDTO;
import com.hango.hango_backend.dto.RolePermissionsUpdateRequest;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Pageable;
import org.springframework.data.domain.Sort;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.security.core.userdetails.UsernameNotFoundException;
import org.springframework.validation.annotation.Validated;
import org.springframework.web.bind.annotation.*;

import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.format.DateTimeFormatter;
import java.util.*;

@CrossOrigin(origins = "*", maxAge = 3600)
@RestController
@RequestMapping("/api/admin")
@Validated
public class AdminController {

    @Autowired
    private UserRepository userRepository;

    @Autowired
    private RoleRepository roleRepository;

    @Autowired
    private PermissionRepository permissionRepository;

    @Autowired
    private AuthService authService;

    @Autowired
    private AuditLogRepository auditLogRepository;

    @Autowired
    private AiUsageLogRepository aiUsageLogRepository;

    @Autowired
    private CourseRepository courseRepository;

    @Autowired
    private EnrollmentRepository enrollmentRepository;

    @Autowired
    private CommentRepository commentRepository;

    @GetMapping("/dashboard/stats")
    @PreAuthorize("hasAuthority('VIEW_PLATFORM_DASHBOARD') or hasAuthority('MANAGE_ACCOUNTS_ROLES') or hasRole('ADMINISTRATOR')")
    public ResponseEntity<?> getDashboardStats() {
        try {
            // Run all queries in parallel to avoid network latency accumulation
            java.util.concurrent.CompletableFuture<Long> usersFuture = java.util.concurrent.CompletableFuture.supplyAsync(() -> userRepository.count());
            java.util.concurrent.CompletableFuture<Long> rolesFuture = java.util.concurrent.CompletableFuture.supplyAsync(() -> roleRepository.count());
            java.util.concurrent.CompletableFuture<Long> coursesFuture = java.util.concurrent.CompletableFuture.supplyAsync(() -> courseRepository.count());
            java.util.concurrent.CompletableFuture<Long> enrollmentsFuture = java.util.concurrent.CompletableFuture.supplyAsync(() -> enrollmentRepository.count());
            java.util.concurrent.CompletableFuture<List<TopCourseProjection>> topCoursesFuture = java.util.concurrent.CompletableFuture.supplyAsync(() -> courseRepository.findTopCoursesByEnrollment(5));
            
            LocalDate today = LocalDate.now();
            LocalDateTime startOf7DaysAgo = today.minusDays(6).atStartOfDay();
            java.util.concurrent.CompletableFuture<List<Object[]>> weeklyStatsFuture = java.util.concurrent.CompletableFuture.supplyAsync(() -> userRepository.countUsersRegisteredByDate(startOf7DaysAgo));

            // Wait for all queries to finish
            java.util.concurrent.CompletableFuture.allOf(usersFuture, rolesFuture, coursesFuture, enrollmentsFuture, topCoursesFuture, weeklyStatsFuture).join();

            // Calculate weekly registration counts for the last 7 days
            List<String> labels = new ArrayList<>();
            List<Long> values = new ArrayList<>();
            DateTimeFormatter labelFormatter = DateTimeFormatter.ofPattern("d/M");
            
            List<Object[]> rawWeeklyStats = weeklyStatsFuture.get();
            Map<String, Long> dateToCountMap = new HashMap<>();
            for (Object[] row : rawWeeklyStats) {
                if (row != null && row.length == 2 && row[0] != null && row[1] != null) {
                    dateToCountMap.put(row[0].toString(), ((Number) row[1]).longValue());
                }
            }

            for (int i = 6; i >= 0; i--) {
                LocalDate date = today.minusDays(i);
                labels.add(date.format(labelFormatter));
                
                String dateStr = date.toString(); // SQL DATE() returns yyyy-MM-dd
                values.add(dateToCountMap.getOrDefault(dateStr, 0L));
            }

            List<TopCourseProjection> topCourses = topCoursesFuture.get();

            Map<String, Object> response = new HashMap<>();
            response.put("totalUsers", usersFuture.get());
            response.put("totalRoles", rolesFuture.get());
            response.put("totalCourses", coursesFuture.get());
            response.put("totalEnrollments", enrollmentsFuture.get());
            response.put("weeklyLabels", labels);
            response.put("weeklyValues", values);
            response.put("topCourses", topCourses.stream().map(tc -> {
                Map<String, Object> m = new HashMap<>();
                m.put("id", tc.getId());
                m.put("title", tc.getTitle());
                m.put("enrollmentCount", tc.getEnrollmentCount());
                return m;
            }).toList());

            return ResponseEntity.ok(response);
        } catch (Exception e) {
            return ResponseEntity.badRequest().body("Error: " + e.getMessage());
        }
    }

    @GetMapping("/users")
    @PreAuthorize("hasAuthority('MANAGE_ACCOUNTS_ROLES') or hasRole('ADMINISTRATOR')")
    public ResponseEntity<?> getUsers(
            @RequestParam(defaultValue = "staff") String roleType,
            @RequestParam(required = false) String search,
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "10") int size) {
        try {
            Pageable pageable = PageRequest.of(page, size, Sort.by(Sort.Direction.DESC, "id"));
            Page<User> userPage;
            
            String safeSearch = (search != null && !search.trim().isEmpty()) ? search.trim() : null;

            if ("learner".equalsIgnoreCase(roleType)) {
                userPage = userRepository.findUsersByRoleNamesAndSearch(List.of("LEARNER", "ROLE_LEARNER"), safeSearch, pageable);
            } else if ("trainer".equalsIgnoreCase(roleType)) {
                userPage = userRepository.findUsersByRoleNamesAndSearch(List.of("TRAINER", "ROLE_TRAINER"), safeSearch, pageable);
            } else if ("course_manager".equalsIgnoreCase(roleType)) {
                userPage = userRepository.findUsersByRoleNamesAndSearch(List.of("COURSE_MANAGER", "ROLE_COURSE_MANAGER"), safeSearch, pageable);
            } else if ("admin".equalsIgnoreCase(roleType)) {
                userPage = userRepository.findUsersByRoleNamesAndSearch(List.of("ADMINISTRATOR", "ROLE_ADMINISTRATOR", "ADMIN"), safeSearch, pageable);
            } else { // "staff" - meaning anyone who is NOT just a learner
                userPage = userRepository.findUsersNotInRoleNamesAndSearch(List.of("LEARNER", "ROLE_LEARNER"), safeSearch, pageable);
            }

            List<User> pagedUsers = userPage.getContent();
            long totalCount = userPage.getTotalElements();
            int totalPages = userPage.getTotalPages();
            if (totalPages == 0) totalPages = 1;

            // 5. Map to safe JSON structure
            List<Map<String, Object>> content = pagedUsers.stream().map(u -> {
                Map<String, Object> map = new HashMap<>();
                map.put("id", u.getId());
                map.put("fullName", u.getFullName());
                map.put("email", u.getEmail());
                map.put("status", u.getStatus() != null ? u.getStatus() : "ACTIVE");
                
                List<String> roleNames = u.getRoles().stream()
                        .map(Role::getRoleName)
                        .toList();
                map.put("roles", roleNames);
                return map;
            }).toList();

            Map<String, Object> response = new HashMap<>();
            response.put("content", content);
            response.put("totalElements", totalCount);
            response.put("totalPages", totalPages);
            response.put("page", page);
            response.put("size", size);

            return ResponseEntity.ok(response);
        } catch (Exception e) {
            return ResponseEntity.badRequest().body("Error: " + e.getMessage());
        }
    }

    private static final Set<String> ALLOWED_USER_STATUSES = Set.of("ACTIVE", "INACTIVE");

    @PutMapping("/users/{id}/status")
    @PreAuthorize("hasAuthority('MANAGE_ACCOUNTS_ROLES') or hasRole('ADMINISTRATOR')")
    public ResponseEntity<?> updateUserStatus(@PathVariable Long id, @RequestParam String status,
            @AuthenticationPrincipal UserDetails currentAdmin) {
        try {
            String normalizedStatus = status == null ? "" : status.trim().toUpperCase();
            if (!ALLOWED_USER_STATUSES.contains(normalizedStatus)) {
                return ResponseEntity.badRequest().body("Error: status must be one of " + ALLOWED_USER_STATUSES);
            }

            Optional<User> userOpt = userRepository.findById(id);
            if (userOpt.isPresent()) {
                User user = userOpt.get();

                if (currentAdmin != null && currentAdmin.getUsername().equalsIgnoreCase(user.getEmail())) {
                    return ResponseEntity.badRequest().body("Error: Admin cannot change the status of their own account");
                }

                user.setStatus(normalizedStatus);
                userRepository.save(user);
                logAudit(currentAdmin, "UPDATE_USER_STATUS", id, "Status changed to " + normalizedStatus);
                return ResponseEntity.ok(Map.of("success", true, "message", "User status updated successfully"));
            } else {
                return ResponseEntity.status(404).body("User not found");
            }
        } catch (Exception e) {
            return ResponseEntity.badRequest().body("Error: " + e.getMessage());
        }
    }

    @GetMapping("/users/{id}")
    @PreAuthorize("hasAuthority('MANAGE_ACCOUNTS_ROLES') or hasRole('ADMINISTRATOR')")
    public ResponseEntity<?> getUserDetail(@PathVariable Long id) {
        try {
            return ResponseEntity.ok(authService.getUserById(id));
        } catch (UsernameNotFoundException e) {
            return ResponseEntity.status(404).body("Error: " + e.getMessage());
        } catch (Exception e) {
            return ResponseEntity.badRequest().body("Error: " + e.getMessage());
        }
    }

    @PostMapping("/users")
    @PreAuthorize("hasAuthority('MANAGE_ACCOUNTS_ROLES') or hasRole('ADMINISTRATOR')")
    public ResponseEntity<?> createUserByAdmin(@Valid @RequestBody RegisterRequest registerRequest,
            @AuthenticationPrincipal UserDetails currentAdmin) {
        try {
            UserResponse response = authService.createUserByAdmin(registerRequest);
            logAudit(currentAdmin, "CREATE_USER", response.getId(),
                    "Created account " + response.getEmail() + " with role(s) " + response.getRoles());
            return ResponseEntity.ok(response);
        } catch (Exception e) {
            return ResponseEntity.badRequest().body("Error: " + e.getMessage());
        }
    }

    @PutMapping("/users/{id}")
    @PreAuthorize("hasAuthority('MANAGE_ACCOUNTS_ROLES') or hasRole('ADMINISTRATOR')")
    public ResponseEntity<?> updateUserByAdmin(
            @PathVariable Long id,
            @Valid @RequestBody AdminUserUpdateRequest updateRequest,
            @AuthenticationPrincipal UserDetails currentAdmin) {
        try {
            Optional<User> userOpt = userRepository.findById(id);
            if (userOpt.isPresent()) {
                User user = userOpt.get();
                List<String> changes = new ArrayList<>();

                if (updateRequest.getFullName() != null) {
                    user.setFullName(updateRequest.getFullName());
                    changes.add("fullName");
                }

                if (updateRequest.getEmail() != null && !updateRequest.getEmail().equalsIgnoreCase(user.getEmail())) {
                    if (userRepository.existsByEmail(updateRequest.getEmail())) {
                        throw new IllegalArgumentException("Error: Email is already in use!");
                    }
                    user.setEmail(updateRequest.getEmail());
                    changes.add("email");
                }

                if (updateRequest.getPhoneNumber() != null) {
                    user.setPhoneNumber(updateRequest.getPhoneNumber());
                }

                if (updateRequest.getGender() != null) {
                    user.setGender(updateRequest.getGender());
                }

                if (updateRequest.getDateOfBirth() != null) {
                    user.setDateOfBirth(updateRequest.getDateOfBirth());
                }

                if (updateRequest.getStatus() != null) {
                    String normalizedStatus = updateRequest.getStatus().trim().toUpperCase();
                    if (!ALLOWED_USER_STATUSES.contains(normalizedStatus)) {
                        return ResponseEntity.badRequest().body("Error: status must be one of " + ALLOWED_USER_STATUSES);
                    }
                    if (!normalizedStatus.equals(user.getStatus())
                            && currentAdmin != null && currentAdmin.getUsername().equalsIgnoreCase(user.getEmail())) {
                        return ResponseEntity.badRequest().body("Error: Admin cannot change the status of their own account");
                    }
                    user.setStatus(normalizedStatus);
                    changes.add("status=" + normalizedStatus);
                }

                if (updateRequest.getRole() != null) {
                    Role roleObj = roleRepository.findByRoleName(updateRequest.getRole().toUpperCase()).orElse(null);
                    if (roleObj == null) {
                        throw new IllegalArgumentException("Error: Role not found!");
                    }
                    Set<Role> roles = new HashSet<>();
                    roles.add(roleObj);
                    user.setRoles(roles);
                    changes.add("role=" + roleObj.getRoleName());
                }

                userRepository.save(user);
                if (!changes.isEmpty()) {
                    logAudit(currentAdmin, "UPDATE_USER", id, "Updated fields: " + String.join(", ", changes));
                }
                return ResponseEntity.ok(authService.getUserById(id));
            } else {
                return ResponseEntity.status(404).body("User not found");
            }
        } catch (Exception e) {
            return ResponseEntity.badRequest().body("Error: " + e.getMessage());
        }
    }

    // ------------------------------------------------------------------
    // Audit Log (FR-RBAC-08) — scoped to admin actions on users/roles
    // ------------------------------------------------------------------

    private void logAudit(UserDetails currentAdmin, String actionType, Long targetUserId, String details) {
        if (currentAdmin == null) return;
        User actor = userRepository.findByEmail(currentAdmin.getUsername()).orElse(null);
        if (actor == null) return;
        
        AuditLog log = AuditLog.builder()
                .actor(actor)
                .actionType(actionType)
                .action(actionType)
                .targetUserId(targetUserId)
                .entityType(targetUserId != null ? "USER" : "ROLE")
                .entityId(targetUserId != null ? targetUserId : 0L)
                .details(details)
                .build();
        auditLogRepository.save(log);
    }

    @GetMapping("/audit-log")
    @PreAuthorize("hasAuthority('AUDIT_LOG_AI_USAGE') or hasAuthority('MANAGE_ACCOUNTS_ROLES') or hasRole('ADMINISTRATOR')")
    public ResponseEntity<?> getAuditLog(@RequestParam(defaultValue = "50") int limit) {
        DateTimeFormatter formatter = DateTimeFormatter.ofPattern("dd/MM/yyyy HH:mm");
        List<AuditLog> logs = auditLogRepository.findAllByOrderByCreatedAtDesc(PageRequest.of(0, limit));

        List<Map<String, Object>> response = logs.stream().map(l -> {
            Map<String, Object> map = new HashMap<>();
            map.put("id", l.getId());
            map.put("actorName", l.getActor() != null ? l.getActor().getFullName() : "System");
            map.put("actorEmail", l.getActor() != null ? l.getActor().getEmail() : null);
            map.put("actionType", l.getActionType());
            map.put("targetUserId", l.getTargetUserId());
            map.put("details", l.getDetails());
            map.put("createdAt", l.getCreatedAt() != null ? l.getCreatedAt().format(formatter) : "");
            return map;
        }).toList();

        return ResponseEntity.ok(response);
    }

    // ------------------------------------------------------------------
    // AI Usage Monitoring (FR-RBAC-07) — real counts from AiUsageLog,
    // populated by GeminiClientService on every generateChatResponse/generateEmbedding call
    // ------------------------------------------------------------------

    @GetMapping("/ai-usage")
    @PreAuthorize("hasAuthority('AUDIT_LOG_AI_USAGE') or hasAuthority('MANAGE_ACCOUNTS_ROLES') or hasRole('ADMINISTRATOR')")
    public ResponseEntity<?> getAiUsageStats() {
        long totalCalls = aiUsageLogRepository.count();
        long successCount = aiUsageLogRepository.countBySuccess(true);
        long failureCount = aiUsageLogRepository.countBySuccess(false);
        long chatCalls = aiUsageLogRepository.countByCallType("CHAT");
        long embeddingCalls = aiUsageLogRepository.countByCallType("EMBEDDING");
        double successRate = totalCalls == 0 ? 0.0 : Math.round((double) successCount / totalCalls * 1000) / 10.0;

        List<AiUsageLog> lastWeekLogs = aiUsageLogRepository.findByCreatedAtAfter(LocalDateTime.now().minusDays(7));
        List<String> labels = new ArrayList<>();
        List<Long> values = new ArrayList<>();
        DateTimeFormatter labelFormatter = DateTimeFormatter.ofPattern("d/M");
        LocalDate today = LocalDate.now();
        for (int i = 6; i >= 0; i--) {
            LocalDate date = today.minusDays(i);
            labels.add(date.format(labelFormatter));
            long count = lastWeekLogs.stream()
                    .filter(l -> l.getCreatedAt() != null && l.getCreatedAt().toLocalDate().equals(date))
                    .count();
            values.add(count);
        }

        Map<String, Object> response = new HashMap<>();
        response.put("totalCalls", totalCalls);
        response.put("successCount", successCount);
        response.put("failureCount", failureCount);
        response.put("chatCalls", chatCalls);
        response.put("embeddingCalls", embeddingCalls);
        response.put("successRate", successRate);
        response.put("weeklyLabels", labels);
        response.put("weeklyValues", values);

        return ResponseEntity.ok(response);
    }

    @GetMapping("/permissions")
    @PreAuthorize("hasAuthority('MANAGE_ACCOUNTS_ROLES') or hasRole('ADMINISTRATOR')")
    public ResponseEntity<?> getAllPermissions() {
        try {
            List<Permission> permissions = permissionRepository.findAll();
            List<PermissionDTO> response = permissions.stream()
                    .map(p -> PermissionDTO.builder()
                            .code(p.getCode())
                            .name(p.getName())
                            .description(p.getDescription())
                            .module(p.getModule())
                            .coreForRoles(p.getCoreForRoles())
                            .restrictedForRoles(p.getRestrictedForRoles())
                            .build())
                    .toList();
            return ResponseEntity.ok(response);
        } catch (Exception e) {
            return ResponseEntity.badRequest().body("Error: " + e.getMessage());
        }
    }

    @GetMapping("/roles")
    @PreAuthorize("hasAuthority('MANAGE_ACCOUNTS_ROLES') or hasRole('ADMINISTRATOR')")
    public ResponseEntity<?> getAllRolesWithPermissions() {
        try {
            List<Role> roles = roleRepository.findAll();
            List<RoleDTO> response = roles.stream().map(role -> {
                List<PermissionDTO> perms = new ArrayList<>();
                if (role.getPermissions() != null) {
                    perms = role.getPermissions().stream()
                            .map(p -> PermissionDTO.builder()
                                    .code(p.getCode())
                                    .name(p.getName())
                                    .description(p.getDescription())
                                    .module(p.getModule())
                                    .coreForRoles(p.getCoreForRoles())
                                    .restrictedForRoles(p.getRestrictedForRoles())
                                    .build())
                            .toList();
                }
                return RoleDTO.builder()
                        .roleName(role.getRoleName())
                        .permissions(perms)
                        .build();
            }).toList();
            return ResponseEntity.ok(response);
        } catch (Exception e) {
            return ResponseEntity.badRequest().body("Error: " + e.getMessage());
        }
    }

    @PutMapping("/roles/{roleName}/permissions")
    @PreAuthorize("hasAuthority('MANAGE_ACCOUNTS_ROLES') or hasRole('ADMINISTRATOR')")
    public ResponseEntity<?> updateRolePermissions(
            @PathVariable String roleName,
            @RequestBody RolePermissionsUpdateRequest request,
            @AuthenticationPrincipal UserDetails currentAdmin) {
        try {
            Optional<Role> roleOpt = roleRepository.findByRoleName(roleName.toUpperCase());
            if (roleOpt.isEmpty()) {
                return ResponseEntity.status(404).body("Role not found");
            }
            Role role = roleOpt.get();
            Set<Permission> newPermissions = new HashSet<>();
            if (request.getPermissionCodes() != null) {
                for (String code : request.getPermissionCodes()) {
                    Optional<Permission> pOpt = permissionRepository.findByCode(code);
                    pOpt.ifPresent(p -> {
                        String restricted = p.getRestrictedForRoles();
                        if (restricted == null || !restricted.contains(role.getRoleName())) {
                            newPermissions.add(p);
                        }
                    });
                }
            }
            
            // Enforce Core permissions (must have)
            List<Permission> allPermissions = permissionRepository.findAll();
            for (Permission p : allPermissions) {
                String core = p.getCoreForRoles();
                if (core != null && core.contains(role.getRoleName())) {
                    newPermissions.add(p);
                }
            }

            role.setPermissions(newPermissions);
            roleRepository.save(role);

            logAudit(currentAdmin, "UPDATE_ROLE_PERMISSIONS", null, "Updated permissions for role " + roleName);
            return ResponseEntity.ok(Map.of("success", true, "message", "Permissions updated successfully"));
        } catch (Exception e) {
            e.printStackTrace();
            return ResponseEntity.badRequest().body("Error: " + e.getMessage());
        }
    }
}
