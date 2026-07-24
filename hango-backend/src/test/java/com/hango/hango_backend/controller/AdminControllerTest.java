package com.hango.hango_backend.controller;

import java.time.LocalDateTime;
import java.util.List;
import java.util.Optional;

import com.hango.hango_backend.dto.AdminUserUpdateRequest;
import com.hango.hango_backend.dto.RegisterRequest;
import com.hango.hango_backend.dto.UserResponse;
import com.hango.hango_backend.entity.AiUsageLog;
import com.hango.hango_backend.entity.AuditLog;
import com.hango.hango_backend.entity.Course;
import com.hango.hango_backend.entity.Role;
import com.hango.hango_backend.entity.User;
import com.hango.hango_backend.repository.AiUsageLogRepository;
import com.hango.hango_backend.repository.AuditLogRepository;
import com.hango.hango_backend.repository.CourseRepository;
import com.hango.hango_backend.repository.EnrollmentRepository;
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

    // =================================================================
    // getDashboardStats
    // =================================================================

    @Test
    void getDashboardStatsShouldReturnRealCounts() {
        when(userRepository.count()).thenReturn(42L);
        when(roleRepository.count()).thenReturn(4L);
        when(userRepository.findAll()).thenReturn(List.of());
        when(courseRepository.count()).thenReturn(7L);
        when(enrollmentRepository.count()).thenReturn(15L);
        TopCourseProjection top = mock(TopCourseProjection.class);
        lenient().when(top.getId()).thenReturn(1L);
        lenient().when(top.getTitle()).thenReturn("English Grammar Mastery");
        lenient().when(top.getEnrollmentCount()).thenReturn(10L);
        when(courseRepository.findTopCoursesByEnrollment(5)).thenReturn(List.of(top));

        ResponseEntity<?> response = adminController.getDashboardStats();

        assertEquals(200, response.getStatusCode().value());
        @SuppressWarnings("unchecked")
        java.util.Map<String, Object> body = (java.util.Map<String, Object>) response.getBody();
        assertEquals(42L, body.get("totalUsers"));
        assertEquals(4L, body.get("totalRoles"));
        assertEquals(7L, body.get("totalCourses"));
        assertEquals(15L, body.get("totalEnrollments"));
    }

    @Test
    void getDashboardStatsShouldReturnAllZeroWeeklyValuesWhenNoRecentRegistrationsInsteadOfFabricatingData() {
        // Regression test: previously fabricated positive weekly values (totalUsers/7 based) whenever
        // no registration happened in the last 7 days — dishonest data indistinguishable from real signups.
        User oldUser = User.builder().id(1L).email("old@example.com")
                .createdAt(LocalDateTime.now().minusDays(30)).build();
        when(userRepository.count()).thenReturn(10L);
        when(roleRepository.count()).thenReturn(4L);
        when(userRepository.findAll()).thenReturn(List.of(oldUser));
        when(courseRepository.count()).thenReturn(0L);
        when(enrollmentRepository.count()).thenReturn(0L);
        when(courseRepository.findTopCoursesByEnrollment(5)).thenReturn(List.of());

        ResponseEntity<?> response = adminController.getDashboardStats();

        @SuppressWarnings("unchecked")
        java.util.Map<String, Object> body = (java.util.Map<String, Object>) response.getBody();
        @SuppressWarnings("unchecked")
        List<Long> weeklyValues = (List<Long>) body.get("weeklyValues");
        assertTrue(weeklyValues.stream().allMatch(v -> v == 0L), "weekly values must be real zeros, not fabricated");
    }

    // =================================================================
    // getUsers
    // =================================================================

    @Test
    void getUsersShouldFilterByLearnerRoleType() {
        User learner = userWithRole(1L, "learner@example.com", "LEARNER");
        User trainer = userWithRole(2L, "trainer@example.com", "TRAINER");
        when(userRepository.findAll()).thenReturn(List.of(learner, trainer));

        ResponseEntity<?> response = adminController.getUsers("learner", null, 0, 10);

        @SuppressWarnings("unchecked")
        java.util.Map<String, Object> body = (java.util.Map<String, Object>) response.getBody();
        assertEquals(1, body.get("totalElements"));
    }

    @Test
    void getUsersShouldTreatCourseManagerAsAliasForTrainerLead() {
        User courseManager = userWithRole(1L, "cm@example.com", "TRAINER_LEAD");
        when(userRepository.findAll()).thenReturn(List.of(courseManager));

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
        when(userRepository.findAll()).thenReturn(List.of(alice, bob));

        ResponseEntity<?> response = adminController.getUsers("staff", "alice", 0, 10);

        @SuppressWarnings("unchecked")
        java.util.Map<String, Object> body = (java.util.Map<String, Object>) response.getBody();
        assertEquals(1, body.get("totalElements"));
    }

    @Test
    void getUsersShouldDefaultToStaffFilterExcludingLearners() {
        User learner = userWithRole(1L, "learner@example.com", "LEARNER");
        User trainer = userWithRole(2L, "trainer@example.com", "TRAINER");
        when(userRepository.findAll()).thenReturn(List.of(learner, trainer));

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
        when(userRepository.findAll()).thenReturn(users);

        ResponseEntity<?> response = adminController.getUsers("trainer", null, 1, 10);

        @SuppressWarnings("unchecked")
        java.util.Map<String, Object> body = (java.util.Map<String, Object>) response.getBody();
        assertEquals(15, body.get("totalElements"));
        assertEquals(2, body.get("totalPages"));
        @SuppressWarnings("unchecked")
        List<?> content = (List<?>) body.get("content");
        assertEquals(5, content.size());
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

    // =================================================================
    // createUserByAdmin
    // =================================================================

    @Test
    void createUserByAdminShouldReturnCreatedUserAndLogAudit() {
        RegisterRequest request = new RegisterRequest();
        request.setEmail("newcm@example.com");
        request.setPassword("Password123");
        request.setFullName("New Course Manager");
        request.setRole("TRAINER_LEAD");
        UserResponse created = UserResponse.builder().id(5L).email("newcm@example.com")
                .roles(List.of("TRAINER_LEAD")).build();
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
}
