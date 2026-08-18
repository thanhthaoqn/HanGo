package com.hango.hango_backend.controller;

import java.time.LocalDateTime;
import java.util.List;
import java.util.Optional;

import com.hango.hango_backend.dto.AdminUserUpdateRequest;
import com.hango.hango_backend.dto.PermissionDTO;
import com.hango.hango_backend.dto.RegisterRequest;
import com.hango.hango_backend.dto.RoleDTO;
import com.hango.hango_backend.dto.RolePermissionsUpdateRequest;
import com.hango.hango_backend.dto.UserResponse;
import com.hango.hango_backend.entity.AiUsageLog;
import com.hango.hango_backend.entity.AuditLog;
import com.hango.hango_backend.entity.Course;
import com.hango.hango_backend.entity.Permission;
import com.hango.hango_backend.entity.Role;
import com.hango.hango_backend.entity.User;
import com.hango.hango_backend.repository.AiUsageLogRepository;
import com.hango.hango_backend.repository.AuditLogRepository;
import com.hango.hango_backend.repository.CourseRepository;
import com.hango.hango_backend.repository.EnrollmentRepository;
import com.hango.hango_backend.repository.PermissionRepository;
import com.hango.hango_backend.repository.RoleRepository;
import com.hango.hango_backend.repository.TopCourseProjection;
import com.hango.hango_backend.repository.UserRepository;
import com.hango.hango_backend.service.AuthService;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.security.core.userdetails.UsernameNotFoundException;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.doThrow;
import static org.mockito.Mockito.lenient;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class AdminControllerTest {

    @Mock
    private UserRepository userRepository;
    @Mock
    private RoleRepository roleRepository;
    @Mock
    private AuthService authService;
    @Mock
    private AuditLogRepository auditLogRepository;
    @Mock
    private AiUsageLogRepository aiUsageLogRepository;
    @Mock
    private CourseRepository courseRepository;
    @Mock
    private EnrollmentRepository enrollmentRepository;
    @Mock
    private PermissionRepository permissionRepository;

    @InjectMocks
    private AdminController adminController;

    private User targetUser(Long id, String email) {
        return User.builder().id(id).email(email).fullName("User " + id).status("ACTIVE").roles(java.util.Set.of()).build();
    }

    private User userWithRole(Long id, String email, String roleName) {
        Role role = Role.builder().id(1L).roleName(roleName).build();
        return User.builder().id(id).email(email).fullName("User " + id).status("ACTIVE")
                .roles(new java.util.HashSet<>(java.util.Set.of(role))).build();
    }

    private UserDetails adminPrincipal(String email) {
        UserDetails principal = mock(UserDetails.class);
        lenient().when(principal.getUsername()).thenReturn(email);
        return principal;
    }


    @Test
    void getUsersShouldFilterByLearnerRoleType() {
        User learner = userWithRole(1L, "learner@example.com", "LEARNER");
        when(userRepository.findUsersByRoleNamesAndSearch(org.mockito.ArgumentMatchers.anyList(), org.mockito.ArgumentMatchers.any(), org.mockito.ArgumentMatchers.any()))
            .thenReturn(new org.springframework.data.domain.PageImpl<>(List.of(learner)));

        ResponseEntity<?> response = adminController.getUsers("learner", null, 0, 10);

        @SuppressWarnings("unchecked")
        java.util.Map<String, Object> body = (java.util.Map<String, Object>) response.getBody();
        assertEquals(1, body.get("totalElements"));
    }

    @Test
    void getUsersShouldTreatCourseManagerAsAliasForTrainerLead() {
        User courseManager = userWithRole(1L, "cm@example.com", "COURSE_MANAGER");
        when(userRepository.findUsersByRoleNamesAndSearch(org.mockito.ArgumentMatchers.anyList(), org.mockito.ArgumentMatchers.any(), org.mockito.ArgumentMatchers.any()))
            .thenReturn(new org.springframework.data.domain.PageImpl<>(List.of(courseManager)));

        ResponseEntity<?> response = adminController.getUsers("course_manager", null, 0, 10);

        @SuppressWarnings("unchecked")
        java.util.Map<String, Object> body = (java.util.Map<String, Object>) response.getBody();
        assertEquals(1, body.get("totalElements"));
    }

    @Test
    void getUsersShouldFilterBySearchQueryMatchingNameOrEmail() {
        User alice = targetUser(1L, "alice@example.com");
        alice.setFullName("Alice Nguyen");
        User bob = targetUser(2L, "bob@example.com");
        bob.setFullName("Bob Tran");
        when(userRepository.findUsersNotInRoleNamesAndSearch(org.mockito.ArgumentMatchers.anyList(), org.mockito.ArgumentMatchers.any(), org.mockito.ArgumentMatchers.any()))
            .thenReturn(new org.springframework.data.domain.PageImpl<>(List.of(alice)));

        ResponseEntity<?> response = adminController.getUsers("staff", "alice", 0, 10);

        @SuppressWarnings("unchecked")
        java.util.Map<String, Object> body = (java.util.Map<String, Object>) response.getBody();
        assertEquals(1, body.get("totalElements"));
    }

    @Test
    void getUsersShouldDefaultToStaffFilterExcludingLearners() {
        User learner = userWithRole(1L, "learner@example.com", "LEARNER");
        User trainer = userWithRole(2L, "trainer@example.com", "TRAINER");
        when(userRepository.findUsersNotInRoleNamesAndSearch(org.mockito.ArgumentMatchers.anyList(), org.mockito.ArgumentMatchers.any(), org.mockito.ArgumentMatchers.any()))
            .thenReturn(new org.springframework.data.domain.PageImpl<>(List.of(trainer)));

        ResponseEntity<?> response = adminController.getUsers("staff", null, 0, 10);

        @SuppressWarnings("unchecked")
        java.util.Map<String, Object> body = (java.util.Map<String, Object>) response.getBody();
        assertEquals(1, body.get("totalElements"));
    }

    @Test
    void getUsersShouldPaginateResults() {
        List<User> users = new java.util.ArrayList<>();
        for (long i = 1; i <= 15; i++) {
            users.add(userWithRole(i, "trainer" + i + "@example.com", "TRAINER"));
        }
        when(userRepository.findUsersByRoleNamesAndSearch(org.mockito.ArgumentMatchers.anyList(), org.mockito.ArgumentMatchers.any(), org.mockito.ArgumentMatchers.any()))
            .thenReturn(new org.springframework.data.domain.PageImpl<>(users.subList(10, 15), org.springframework.data.domain.PageRequest.of(1, 10), 15));

        ResponseEntity<?> response = adminController.getUsers("trainer", null, 1, 10);

        @SuppressWarnings("unchecked")
        java.util.Map<String, Object> body = (java.util.Map<String, Object>) response.getBody();
        assertEquals(15, body.get("totalElements"));
        assertEquals(2, body.get("totalPages"));
        @SuppressWarnings("unchecked")
        List<?> content = (List<?>) body.get("content");
        assertEquals(5, content.size());
    }

    @Test
    void getUsersShouldFilterByAdminRoleType() {
        User admin = userWithRole(1L, "admin@example.com", "ADMINISTRATOR");
        when(userRepository.findUsersByRoleNamesAndSearch(org.mockito.ArgumentMatchers.anyList(), org.mockito.ArgumentMatchers.any(), org.mockito.ArgumentMatchers.any()))
            .thenReturn(new org.springframework.data.domain.PageImpl<>(List.of(admin)));

        ResponseEntity<?> response = adminController.getUsers("admin", null, 0, 10);

        @SuppressWarnings("unchecked")
        java.util.Map<String, Object> body = (java.util.Map<String, Object>) response.getBody();
        assertEquals(1, body.get("totalElements"));
    }

    @Test
    void getUsersShouldReturnEmptyContentWhenPageExceedsTotalElements() {
        when(userRepository.findUsersNotInRoleNamesAndSearch(org.mockito.ArgumentMatchers.anyList(), org.mockito.ArgumentMatchers.any(), org.mockito.ArgumentMatchers.any()))
            .thenReturn(new org.springframework.data.domain.PageImpl<>(java.util.Collections.emptyList()));

        ResponseEntity<?> response = adminController.getUsers("trainer", null, 5, 10);

        @SuppressWarnings("unchecked")
        java.util.Map<String, Object> body = (java.util.Map<String, Object>) response.getBody();
        assertEquals(1, body.get("totalElements"));
        @SuppressWarnings("unchecked")
        List<?> content = (List<?>) body.get("content");
        assertTrue(content.isEmpty());
    }

    @Test
    void getUsersShouldReturn400WhenRepositoryThrows() {
        when(userRepository.findAll()).thenThrow(new RuntimeException("DB error"));

        ResponseEntity<?> response = adminController.getUsers("staff", null, 0, 10);

        assertEquals(400, response.getStatusCode().value());
        assertEquals("Error: DB error", response.getBody());
    }

    // =================================================================
    // updateUserStatus
    // =================================================================

    @Test
    void updateUserStatusShouldRejectStatusOutsideWhitelist() {
        ResponseEntity<?> response = adminController.updateUserStatus(5L, "LOCKED", mock(UserDetails.class));

        assertEquals(400, response.getStatusCode().value());
        verify(userRepository, never()).findById(any());
        verify(userRepository, never()).save(any());
    }

    @Test
    void updateUserStatusShouldReturn404WhenTargetNotFound() {
        when(userRepository.findById(99L)).thenReturn(Optional.empty());

        ResponseEntity<?> response = adminController.updateUserStatus(99L, "INACTIVE", mock(UserDetails.class));

        assertEquals(404, response.getStatusCode().value());
    }

    @Test
    void updateUserStatusShouldRejectAdminChangingOwnStatus() {
        User admin = targetUser(1L, "admin@example.com");
        when(userRepository.findById(1L)).thenReturn(Optional.of(admin));

        ResponseEntity<?> response = adminController.updateUserStatus(1L, "INACTIVE", adminPrincipal("admin@example.com"));

        assertEquals(400, response.getStatusCode().value());
        verify(userRepository, never()).save(any());
    }

    @Test
    void updateUserStatusShouldUpdateStatusForAnotherUserAndLogAudit() {
        User target = targetUser(2L, "learner@example.com");
        when(userRepository.findById(2L)).thenReturn(Optional.of(target));
        when(userRepository.findByEmail("admin@example.com")).thenReturn(Optional.of(targetUser(1L, "admin@example.com")));

        ResponseEntity<?> response = adminController.updateUserStatus(2L, "inactive", adminPrincipal("admin@example.com"));

        assertEquals(200, response.getStatusCode().value());
        assertEquals("INACTIVE", target.getStatus());
        verify(userRepository).save(target);
        ArgumentCaptor<AuditLog> captor = ArgumentCaptor.forClass(AuditLog.class);
        verify(auditLogRepository).save(captor.capture());
        assertEquals("UPDATE_USER_STATUS", captor.getValue().getActionType());
        assertEquals(2L, captor.getValue().getTargetUserId());
    }

    @Test
    void updateUserStatusShouldReturn400WhenRepositoryThrowsGenericException() {
        when(userRepository.findById(2L)).thenThrow(new RuntimeException("DB error"));

        ResponseEntity<?> response = adminController.updateUserStatus(2L, "INACTIVE", mock(UserDetails.class));

        assertEquals(400, response.getStatusCode().value());
        assertEquals("Error: DB error", response.getBody());
    }

    // =================================================================
    // getUserDetail
    // =================================================================

    @Test
    void getUserDetailShouldReturnUserResponseWhenFound() {
        UserResponse userResponse = UserResponse.builder().id(1L).email("a@example.com").build();
        when(authService.getUserById(1L)).thenReturn(userResponse);

        ResponseEntity<?> response = adminController.getUserDetail(1L);

        assertEquals(200, response.getStatusCode().value());
        assertEquals(userResponse, response.getBody());
    }

    @Test
    void getUserDetailShouldReturn404WhenUserNotFound() {
        when(authService.getUserById(99L)).thenThrow(new UsernameNotFoundException("User not found with id: 99"));

        ResponseEntity<?> response = adminController.getUserDetail(99L);

        assertEquals(404, response.getStatusCode().value());
    }

    @Test
    void getUserDetailShouldReturn400WhenServiceThrowsGenericException() {
        when(authService.getUserById(1L)).thenThrow(new RuntimeException("boom"));

        ResponseEntity<?> response = adminController.getUserDetail(1L);

        assertEquals(400, response.getStatusCode().value());
        assertEquals("Error: boom", response.getBody());
    }

    // =================================================================
    // createUserByAdmin
    // =================================================================

    @Test
    void createUserByAdminShouldReturnCreatedUserAndLogAudit() {
        RegisterRequest request = new RegisterRequest();
        request.setEmail("newcm@example.com");
        request.setPassword("Password123");
        request.setFullName("New Course Manager");
        request.setRole("COURSE_MANAGER");
        UserResponse created = UserResponse.builder().id(5L).email("newcm@example.com")
                .roles(List.of("COURSE_MANAGER")).build();
        when(authService.createUserByAdmin(request)).thenReturn(created);
        when(userRepository.findByEmail("admin@example.com")).thenReturn(Optional.of(targetUser(1L, "admin@example.com")));

        ResponseEntity<?> response = adminController.createUserByAdmin(request, adminPrincipal("admin@example.com"));

        assertEquals(200, response.getStatusCode().value());
        ArgumentCaptor<AuditLog> captor = ArgumentCaptor.forClass(AuditLog.class);
        verify(auditLogRepository).save(captor.capture());
        assertEquals("CREATE_USER", captor.getValue().getActionType());
        assertEquals(5L, captor.getValue().getTargetUserId());
    }

    @Test
    void createUserByAdminShouldReturn400WhenServiceThrowsAndNotLogAudit() {
        RegisterRequest request = new RegisterRequest();
        request.setEmail("dup@example.com");
        request.setPassword("Password123");
        request.setFullName("Dup");
        when(authService.createUserByAdmin(any())).thenThrow(new IllegalArgumentException("Error: Email is already in use!"));

        ResponseEntity<?> response = adminController.createUserByAdmin(request, mock(UserDetails.class));

        assertEquals(400, response.getStatusCode().value());
        verify(auditLogRepository, never()).save(any());
    }

    // =================================================================
    // updateUserByAdmin
    // =================================================================

    @Test
    void updateUserByAdminShouldReturn404WhenUserNotFound() {
        when(userRepository.findById(99L)).thenReturn(Optional.empty());

        ResponseEntity<?> response = adminController.updateUserByAdmin(99L, new AdminUserUpdateRequest(), mock(UserDetails.class));

        assertEquals(404, response.getStatusCode().value());
    }

    @Test
    void updateUserByAdminShouldRejectStatusOutsideWhitelist() {
        // Regression test: previously this endpoint set status directly with no whitelist at all,
        // letting a caller set arbitrary strings (e.g. "BANNED") bypassing updateUserStatus's rules.
        User target = targetUser(2L, "learner@example.com");
        when(userRepository.findById(2L)).thenReturn(Optional.of(target));
        AdminUserUpdateRequest request = new AdminUserUpdateRequest();
        request.setStatus("BANNED");

        ResponseEntity<?> response = adminController.updateUserByAdmin(2L, request, mock(UserDetails.class));

        assertEquals(400, response.getStatusCode().value());
        assertEquals("ACTIVE", target.getStatus());
        verify(userRepository, never()).save(any());
    }

    @Test
    void updateUserByAdminShouldRejectAdminChangingOwnStatus() {
        User admin = targetUser(1L, "admin@example.com");
        when(userRepository.findById(1L)).thenReturn(Optional.of(admin));
        AdminUserUpdateRequest request = new AdminUserUpdateRequest();
        request.setStatus("INACTIVE");

        ResponseEntity<?> response = adminController.updateUserByAdmin(1L, request, adminPrincipal("admin@example.com"));

        assertEquals(400, response.getStatusCode().value());
        verify(userRepository, never()).save(any());
    }

    @Test
    void updateUserByAdminShouldAllowAdminSettingOwnStatusToSameCurrentValue() {
        // The self-lock guard only fires when the requested status differs from the current
        // one, so requesting the SAME status (just different casing) bypasses it entirely.
        User admin = targetUser(1L, "admin@example.com");
        when(userRepository.findById(1L)).thenReturn(Optional.of(admin));
        when(authService.getUserById(1L)).thenReturn(UserResponse.builder().id(1L).build());
        when(userRepository.findByEmail("admin@example.com")).thenReturn(Optional.of(admin));
        AdminUserUpdateRequest request = new AdminUserUpdateRequest();
        request.setStatus("active");

        ResponseEntity<?> response = adminController.updateUserByAdmin(1L, request, adminPrincipal("admin@example.com"));

        assertEquals(200, response.getStatusCode().value());
        verify(userRepository).save(admin);
        ArgumentCaptor<AuditLog> captor = ArgumentCaptor.forClass(AuditLog.class);
        verify(auditLogRepository).save(captor.capture());
        assertTrue(captor.getValue().getDetails().contains("status=ACTIVE"));
    }

    @Test
    void updateUserByAdminShouldThrowWhenEmailAlreadyInUse() {
        User target = targetUser(2L, "learner@example.com");
        when(userRepository.findById(2L)).thenReturn(Optional.of(target));
        when(userRepository.existsByEmail("taken@example.com")).thenReturn(true);
        AdminUserUpdateRequest request = new AdminUserUpdateRequest();
        request.setEmail("taken@example.com");

        ResponseEntity<?> response = adminController.updateUserByAdmin(2L, request, mock(UserDetails.class));

        assertEquals(400, response.getStatusCode().value());
        verify(userRepository, never()).save(any());
    }

    @Test
    void updateUserByAdminShouldThrowWhenRoleNotFound() {
        User target = targetUser(2L, "learner@example.com");
        when(userRepository.findById(2L)).thenReturn(Optional.of(target));
        when(roleRepository.findByRoleName("GHOST_ROLE")).thenReturn(Optional.empty());
        AdminUserUpdateRequest request = new AdminUserUpdateRequest();
        request.setRole("ghost_role");

        ResponseEntity<?> response = adminController.updateUserByAdmin(2L, request, mock(UserDetails.class));

        assertEquals(400, response.getStatusCode().value());
        verify(userRepository, never()).save(any());
    }

    @Test
    void updateUserByAdminShouldUpdateFullNameStatusAndRoleThenLogAudit() {
        User target = targetUser(2L, "learner@example.com");
        Role trainerRole = Role.builder().id(2L).roleName("TRAINER").build();
        when(userRepository.findById(2L)).thenReturn(Optional.of(target));
        when(roleRepository.findByRoleName("TRAINER")).thenReturn(Optional.of(trainerRole));
        when(authService.getUserById(2L)).thenReturn(UserResponse.builder().id(2L).build());
        when(userRepository.findByEmail("admin@example.com")).thenReturn(Optional.of(targetUser(1L, "admin@example.com")));

        AdminUserUpdateRequest request = new AdminUserUpdateRequest();
        request.setFullName("Updated Name");
        request.setStatus("inactive");
        request.setRole("trainer");

        ResponseEntity<?> response = adminController.updateUserByAdmin(2L, request, adminPrincipal("admin@example.com"));

        assertEquals(200, response.getStatusCode().value());
        assertEquals("Updated Name", target.getFullName());
        assertEquals("INACTIVE", target.getStatus());
        assertTrue(target.getRoles().contains(trainerRole));
        verify(userRepository).save(target);
        ArgumentCaptor<AuditLog> captor = ArgumentCaptor.forClass(AuditLog.class);
        verify(auditLogRepository).save(captor.capture());
        assertEquals("UPDATE_USER", captor.getValue().getActionType());
        assertTrue(captor.getValue().getDetails().contains("status=INACTIVE"));
    }

    @Test
    void updateUserByAdminShouldReplaceExistingRolesWithNewSingleRole() {
        User target = userWithRole(2L, "learner@example.com", "LEARNER");
        Role trainerRole = Role.builder().id(2L).roleName("TRAINER").build();
        when(userRepository.findById(2L)).thenReturn(Optional.of(target));
        when(roleRepository.findByRoleName("TRAINER")).thenReturn(Optional.of(trainerRole));
        when(authService.getUserById(2L)).thenReturn(UserResponse.builder().id(2L).build());

        AdminUserUpdateRequest request = new AdminUserUpdateRequest();
        request.setRole("trainer");

        ResponseEntity<?> response = adminController.updateUserByAdmin(2L, request, mock(UserDetails.class));

        assertEquals(200, response.getStatusCode().value());
        assertEquals(1, target.getRoles().size());
        assertTrue(target.getRoles().contains(trainerRole));
    }

    @Test
    void updateUserByAdminShouldSaveButNotLogAuditWhenOnlyPhoneNumberChanged() {
        // Documents a real production gap: phoneNumber/gender/dateOfBirth are applied to the
        // User and saved, but never appended to the `changes` list, so no audit log entry is
        // written even though the record was actually mutated. See GAP-RBAC-1 in utc-sheet-rbac.csv.
        User target = targetUser(2L, "learner@example.com");
        when(userRepository.findById(2L)).thenReturn(Optional.of(target));
        when(authService.getUserById(2L)).thenReturn(UserResponse.builder().id(2L).build());
        AdminUserUpdateRequest request = new AdminUserUpdateRequest();
        request.setPhoneNumber("0999999999");

        ResponseEntity<?> response = adminController.updateUserByAdmin(2L, request, mock(UserDetails.class));

        assertEquals(200, response.getStatusCode().value());
        assertEquals("0999999999", target.getPhoneNumber());
        verify(userRepository).save(target);
        verify(auditLogRepository, never()).save(any());
    }

    @Test
    void updateUserByAdminShouldNotLogAuditWhenNothingActuallyChanged() {
        User target = targetUser(2L, "learner@example.com");
        when(userRepository.findById(2L)).thenReturn(Optional.of(target));
        when(authService.getUserById(2L)).thenReturn(UserResponse.builder().id(2L).build());

        ResponseEntity<?> response = adminController.updateUserByAdmin(2L, new AdminUserUpdateRequest(), mock(UserDetails.class));

        assertEquals(200, response.getStatusCode().value());
        verify(auditLogRepository, never()).save(any());
    }

    // =================================================================
    // getAuditLog
    // =================================================================

    @Test
    void getAuditLogShouldReturnMappedEntriesWithSystemFallbackWhenActorMissing() {
        User admin = targetUser(1L, "admin@example.com");
        AuditLog byAdmin = AuditLog.builder().id(1L).actor(admin).actionType("CREATE_USER").targetUserId(2L)
                .details("Created account").createdAt(LocalDateTime.now()).build();
        AuditLog systemEntry = AuditLog.builder().id(2L).actor(null).actionType("UPDATE_USER_STATUS").targetUserId(3L)
                .details("Status changed").createdAt(LocalDateTime.now()).build();
        when(auditLogRepository.findAllByOrderByCreatedAtDesc(any())).thenReturn(List.of(byAdmin, systemEntry));

        ResponseEntity<?> response = adminController.getAuditLog(50);

        @SuppressWarnings("unchecked")
        List<java.util.Map<String, Object>> body = (List<java.util.Map<String, Object>>) response.getBody();
        assertEquals(2, body.size());
        assertEquals("admin@example.com", body.get(0).get("actorEmail"));
        assertEquals("System", body.get(1).get("actorName"));
    }

    // =================================================================
    // getAiUsageStats
    // =================================================================

    @Test
    void getAiUsageStatsShouldComputeSuccessRateAndCallTypeBreakdown() {
        when(aiUsageLogRepository.count()).thenReturn(10L);
        when(aiUsageLogRepository.countBySuccess(true)).thenReturn(8L);
        when(aiUsageLogRepository.countBySuccess(false)).thenReturn(2L);
        when(aiUsageLogRepository.countByCallType("CHAT")).thenReturn(6L);
        when(aiUsageLogRepository.countByCallType("EMBEDDING")).thenReturn(4L);
        when(aiUsageLogRepository.findByCreatedAtAfter(any())).thenReturn(List.of());

        ResponseEntity<?> response = adminController.getAiUsageStats();

        @SuppressWarnings("unchecked")
        java.util.Map<String, Object> body = (java.util.Map<String, Object>) response.getBody();
        assertEquals(10L, body.get("totalCalls"));
        assertEquals(80.0, body.get("successRate"));
        assertEquals(6L, body.get("chatCalls"));
        assertEquals(4L, body.get("embeddingCalls"));
    }

    @Test
    void getAiUsageStatsShouldReturnZeroSuccessRateWhenNoCallsYet() {
        when(aiUsageLogRepository.count()).thenReturn(0L);
        when(aiUsageLogRepository.countBySuccess(true)).thenReturn(0L);
        when(aiUsageLogRepository.countBySuccess(false)).thenReturn(0L);
        when(aiUsageLogRepository.countByCallType(anyString())).thenReturn(0L);
        when(aiUsageLogRepository.findByCreatedAtAfter(any())).thenReturn(List.of());

        ResponseEntity<?> response = adminController.getAiUsageStats();

        @SuppressWarnings("unchecked")
        java.util.Map<String, Object> body = (java.util.Map<String, Object>) response.getBody();
        assertEquals(0.0, body.get("successRate"));
    }

    // =================================================================
    // getAllPermissions
    // =================================================================

    @Test
    void getAllPermissionsShouldReturnMappedPermissionList() {
        Permission p = Permission.builder().code("MANAGE_OWN_COURSES").name("Manage own courses")
                .description("desc").module("Course Management").coreForRoles("TRAINER").restrictedForRoles(null)
                .build();
        when(permissionRepository.findAll()).thenReturn(List.of(p));

        ResponseEntity<?> response = adminController.getAllPermissions();

        assertEquals(200, response.getStatusCode().value());
        @SuppressWarnings("unchecked")
        List<PermissionDTO> body = (List<PermissionDTO>) response.getBody();
        assertEquals(1, body.size());
        assertEquals("MANAGE_OWN_COURSES", body.get(0).getCode());
        assertEquals("TRAINER", body.get(0).getCoreForRoles());
    }

    @Test
    void getAllPermissionsShouldReturn400OnRepositoryError() {
        when(permissionRepository.findAll()).thenThrow(new RuntimeException("db down"));

        ResponseEntity<?> response = adminController.getAllPermissions();

        assertEquals(400, response.getStatusCode().value());
    }

    // =================================================================
    // getAllRolesWithPermissions
    // =================================================================

    @Test
    void getAllRolesWithPermissionsShouldMapEachRoleWithItsPermissions() {
        Permission p = Permission.builder().code("MANAGE_OWN_COURSES").name("Manage own courses").build();
        Role trainerRole = Role.builder().id(1L).roleName("TRAINER").permissions(java.util.Set.of(p)).build();
        when(roleRepository.findAll()).thenReturn(List.of(trainerRole));

        ResponseEntity<?> response = adminController.getAllRolesWithPermissions();

        assertEquals(200, response.getStatusCode().value());
        @SuppressWarnings("unchecked")
        List<RoleDTO> body = (List<RoleDTO>) response.getBody();
        assertEquals(1, body.size());
        assertEquals("TRAINER", body.get(0).getRoleName());
        assertEquals(1, body.get(0).getPermissions().size());
        assertEquals("MANAGE_OWN_COURSES", body.get(0).getPermissions().get(0).getCode());
    }

    @Test
    void getAllRolesWithPermissionsShouldReturnEmptyPermissionsListWhenRoleHasNone() {
        Role learnerRole = Role.builder().id(1L).roleName("LEARNER").permissions(null).build();
        when(roleRepository.findAll()).thenReturn(List.of(learnerRole));

        ResponseEntity<?> response = adminController.getAllRolesWithPermissions();

        @SuppressWarnings("unchecked")
        List<RoleDTO> body = (List<RoleDTO>) response.getBody();
        assertTrue(body.get(0).getPermissions().isEmpty());
    }

    // =================================================================
    // updateRolePermissions
    // =================================================================

    @Test
    void updateRolePermissionsShouldReturn404WhenRoleNotFound() {
        when(roleRepository.findByRoleName("TRAINER")).thenReturn(Optional.empty());

        ResponseEntity<?> response = adminController.updateRolePermissions("trainer",
                new RolePermissionsUpdateRequest(List.of()), mock(UserDetails.class));

        assertEquals(404, response.getStatusCode().value());
        verify(roleRepository, never()).save(any());
    }

    @Test
    void updateRolePermissionsShouldDropRequestedPermissionRestrictedForThisRole() {
        Role trainerRole = Role.builder().id(1L).roleName("TRAINER").permissions(new java.util.HashSet<>()).build();
        Permission restricted = Permission.builder().code("REFUND_REQUEST").restrictedForRoles("TRAINER,LEARNER").build();
        when(roleRepository.findByRoleName("TRAINER")).thenReturn(Optional.of(trainerRole));
        when(permissionRepository.findByCode("REFUND_REQUEST")).thenReturn(Optional.of(restricted));
        when(permissionRepository.findAll()).thenReturn(List.of(restricted));

        adminController.updateRolePermissions("TRAINER",
                new RolePermissionsUpdateRequest(List.of("REFUND_REQUEST")), mock(UserDetails.class));

        assertTrue(trainerRole.getPermissions().isEmpty());
    }

    @Test
    void updateRolePermissionsShouldForceAddCorePermissionEvenIfNotRequested() {
        Role trainerRole = Role.builder().id(1L).roleName("TRAINER").permissions(new java.util.HashSet<>()).build();
        Permission core = Permission.builder().code("MANAGE_OWN_COURSES").coreForRoles("TRAINER").build();
        when(roleRepository.findByRoleName("TRAINER")).thenReturn(Optional.of(trainerRole));
        when(permissionRepository.findAll()).thenReturn(List.of(core));

        adminController.updateRolePermissions("TRAINER",
                new RolePermissionsUpdateRequest(List.of()), mock(UserDetails.class));

        assertEquals(1, trainerRole.getPermissions().size());
        assertTrue(trainerRole.getPermissions().contains(core));
    }

    @Test
    void updateRolePermissionsShouldIgnoreUnknownPermissionCode() {
        Role trainerRole = Role.builder().id(1L).roleName("TRAINER").permissions(new java.util.HashSet<>()).build();
        when(roleRepository.findByRoleName("TRAINER")).thenReturn(Optional.of(trainerRole));
        when(permissionRepository.findByCode("NOT_A_REAL_CODE")).thenReturn(Optional.empty());
        when(permissionRepository.findAll()).thenReturn(List.of());

        ResponseEntity<?> response = adminController.updateRolePermissions("TRAINER",
                new RolePermissionsUpdateRequest(List.of("NOT_A_REAL_CODE")), mock(UserDetails.class));

        assertEquals(200, response.getStatusCode().value());
        assertTrue(trainerRole.getPermissions().isEmpty());
    }

    @Test
    void updateRolePermissionsShouldSaveGrantedPermissionAndLogAudit() {
        Role trainerRole = Role.builder().id(1L).roleName("TRAINER").permissions(new java.util.HashSet<>()).build();
        Permission granted = Permission.builder().code("MANAGE_OWN_COURSES").restrictedForRoles(null).build();
        when(roleRepository.findByRoleName("TRAINER")).thenReturn(Optional.of(trainerRole));
        when(permissionRepository.findByCode("MANAGE_OWN_COURSES")).thenReturn(Optional.of(granted));
        when(permissionRepository.findAll()).thenReturn(List.of(granted));
        when(userRepository.findByEmail("admin@example.com")).thenReturn(Optional.of(targetUser(1L, "admin@example.com")));

        ResponseEntity<?> response = adminController.updateRolePermissions("TRAINER",
                new RolePermissionsUpdateRequest(List.of("MANAGE_OWN_COURSES")), adminPrincipal("admin@example.com"));

        assertEquals(200, response.getStatusCode().value());
        assertTrue(trainerRole.getPermissions().contains(granted));
        verify(roleRepository).save(trainerRole);
        ArgumentCaptor<AuditLog> captor = ArgumentCaptor.forClass(AuditLog.class);
        verify(auditLogRepository).save(captor.capture());
        assertEquals("UPDATE_ROLE_PERMISSIONS", captor.getValue().getActionType());
    }

    @Test
    void updateRolePermissionsShouldUppercaseRoleNameForLookup() {
        Role role = Role.builder().id(1L).roleName("TRAINER").permissions(new java.util.HashSet<>()).build();
        when(roleRepository.findByRoleName("TRAINER")).thenReturn(Optional.of(role));
        when(permissionRepository.findAll()).thenReturn(List.of());

        ResponseEntity<?> response = adminController.updateRolePermissions("trainer",
                new RolePermissionsUpdateRequest(List.of()), mock(UserDetails.class));

        assertEquals(200, response.getStatusCode().value());
        verify(roleRepository).findByRoleName("TRAINER");
    }
}
