package com.hango.hango_backend.config;

import com.hango.hango_backend.entity.Permission;
import com.hango.hango_backend.entity.Role;
import com.hango.hango_backend.repository.PermissionRepository;
import com.hango.hango_backend.repository.RoleRepository;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.util.HashSet;
import java.util.Optional;
import java.util.Set;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.atLeastOnce;
import static org.mockito.Mockito.lenient;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.times;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class RolePermissionDataInitializerTest {

    @Mock
    private RoleRepository roleRepository;
    @Mock
    private PermissionRepository permissionRepository;

    @InjectMocks
    private RolePermissionDataInitializer initializer;

    private void stubNoExistingPermissionsAndNoRoles() throws Exception {
        lenient().when(permissionRepository.findByCode(anyString())).thenReturn(Optional.empty());
        lenient().when(permissionRepository.save(any(Permission.class))).thenAnswer(inv -> inv.getArgument(0));
        lenient().when(roleRepository.findByRoleName(anyString())).thenReturn(Optional.empty());
    }

    // =================================================================
    // run — permission seeding (createPermissionIfNotFound)
    // =================================================================

    @Test
    void runShouldCreateAllFourteenPermissionsWhenNoneExistYet() throws Exception {
        stubNoExistingPermissionsAndNoRoles();

        initializer.run();

        verify(permissionRepository, times(14)).save(any(Permission.class));
    }

    @Test
    void runShouldUpdateModuleCoreAndRestrictedFieldsWhenExistingPermissionDiffersFromSeed() throws Exception {
        stubNoExistingPermissionsAndNoRoles();
        Permission stale = Permission.builder().code("ENROLL_AND_LEARN_COURSES").name("Old name")
                .module("STALE_MODULE").coreForRoles("STALE").restrictedForRoles("STALE").build();
        when(permissionRepository.findByCode("ENROLL_AND_LEARN_COURSES")).thenReturn(Optional.of(stale));

        initializer.run();

        ArgumentCaptor<Permission> captor = ArgumentCaptor.forClass(Permission.class);
        verify(permissionRepository, atLeastOnce()).save(captor.capture());
        Permission saved = captor.getAllValues().stream()
                .filter(p -> "ENROLL_AND_LEARN_COURSES".equals(p.getCode())).findFirst().orElseThrow();
        assertEquals("Learning & Enrollment", saved.getModule());
        assertEquals("LEARNER", saved.getCoreForRoles());
        assertEquals("TRAINER,COURSE_MANAGER", saved.getRestrictedForRoles());
    }

    @Test
    void runShouldNotResavePermissionWhenAllFieldsAlreadyMatchSeed() throws Exception {
        stubNoExistingPermissionsAndNoRoles();
        Permission upToDate = Permission.builder().code("ENROLL_AND_LEARN_COURSES").name("Enroll & Learn Courses")
                .module("Learning & Enrollment").coreForRoles("LEARNER").restrictedForRoles("TRAINER,COURSE_MANAGER").build();
        when(permissionRepository.findByCode("ENROLL_AND_LEARN_COURSES")).thenReturn(Optional.of(upToDate));

        initializer.run();

        // 14 permissions total, 1 already up to date -> only the other 13 get created/saved.
        verify(permissionRepository, times(13)).save(any(Permission.class));
    }

    // =================================================================
    // run — role assignment (assignPermissionsToRole)
    // =================================================================

    @Test
    void runShouldAssignDefaultPermissionSetToRoleWithNoExistingPermissions() throws Exception {
        stubNoExistingPermissionsAndNoRoles();
        Role learnerRole = Role.builder().id(1L).roleName("LEARNER").permissions(new HashSet<>()).build();
        when(roleRepository.findByRoleName("LEARNER")).thenReturn(Optional.of(learnerRole));
        when(roleRepository.save(any(Role.class))).thenAnswer(inv -> inv.getArgument(0));

        initializer.run();

        verify(roleRepository).save(learnerRole);
        assertEquals(4, learnerRole.getPermissions().size());
    }

    @Test
    void runShouldNotOverwriteRolesExistingPermissions() throws Exception {
        stubNoExistingPermissionsAndNoRoles();
        Permission existing = Permission.builder().code("CUSTOM_GRANT").build();
        Role learnerRole = Role.builder().id(1L).roleName("LEARNER")
                .permissions(new HashSet<>(Set.of(existing))).build();
        when(roleRepository.findByRoleName("LEARNER")).thenReturn(Optional.of(learnerRole));

        initializer.run();

        verify(roleRepository, never()).save(learnerRole);
        assertEquals(Set.of(existing), learnerRole.getPermissions());
    }

    @Test
    void runShouldSkipAssignmentWhenNoRoleRowsExistInDatabase() throws Exception {
        stubNoExistingPermissionsAndNoRoles();

        initializer.run();

        verify(roleRepository, never()).save(any(Role.class));
    }

    @Test
    void runShouldOnlyAssignPermissionsToRolesThatExist() throws Exception {
        stubNoExistingPermissionsAndNoRoles();
        Role trainerRole = Role.builder().id(2L).roleName("TRAINER").permissions(new HashSet<>()).build();
        when(roleRepository.findByRoleName("TRAINER")).thenReturn(Optional.of(trainerRole));
        when(roleRepository.save(any(Role.class))).thenAnswer(inv -> inv.getArgument(0));

        initializer.run();

        verify(roleRepository, times(1)).save(any(Role.class));
        assertTrue(trainerRole.getPermissions().stream()
                .anyMatch(p -> "MANAGE_OWN_COURSES".equals(p.getCode())));
    }
}
