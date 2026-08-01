package com.hango.hango_backend.config;

import com.hango.hango_backend.entity.Permission;
import com.hango.hango_backend.entity.Role;
import com.hango.hango_backend.repository.PermissionRepository;
import com.hango.hango_backend.repository.RoleRepository;
import org.springframework.boot.CommandLineRunner;
import org.springframework.stereotype.Component;

import java.util.HashSet;
import java.util.Optional;
import java.util.Set;

@Component
public class RolePermissionDataInitializer implements CommandLineRunner {

    private final RoleRepository roleRepository;
    private final PermissionRepository permissionRepository;

    public RolePermissionDataInitializer(RoleRepository roleRepository, PermissionRepository permissionRepository) {
        this.roleRepository = roleRepository;
        this.permissionRepository = permissionRepository;
    }

    @Override
    public void run(String... args) throws Exception {
        // Define all permissions
        Permission learnCourses = createPermissionIfNotFound("ENROLL_AND_LEARN_COURSES", "Enroll & Learn Courses", "Ability to enroll in and learn courses", "Learning & Enrollment", "LEARNER", "TRAINER,COURSE_MANAGER");
        Permission attemptQuiz = createPermissionIfNotFound("ATTEMPT_QUIZ_AND_EXAM", "Attempt Quiz & Exam", "Ability to attempt quizzes and exams", "Learning & Enrollment", "LEARNER", "TRAINER,COURSE_MANAGER");
        Permission rateAndComment = createPermissionIfNotFound("RATE_AND_COMMENT", "Rate Courses & Comment", "Ability to rate courses and comment", "Learning & Enrollment", "", "");
        Permission aiAssistant = createPermissionIfNotFound("AI_LEARNING_ASSISTANT", "AI Learning Assistant", "Access to AI learning assistant", "Learning & Enrollment", "", "");

        Permission manageOwnCourses = createPermissionIfNotFound("MANAGE_OWN_COURSES", "Create & Manage Own Courses", "Create and manage own courses", "Course Management", "TRAINER", "LEARNER");
        Permission manageQuestionBank = createPermissionIfNotFound("MANAGE_QUESTION_BANK", "Manage Question Bank", "Manage own question bank", "Course Management", "TRAINER", "LEARNER");
        Permission createExamsTrainer = createPermissionIfNotFound("CREATE_EXAMS_TRAINER", "Create Exams", "Create exams as a trainer", "Course Management", "TRAINER", "LEARNER");
        Permission viewOwnRevenue = createPermissionIfNotFound("VIEW_OWN_REVENUE", "View Own Revenue", "View own revenue statistics", "Analytics", "TRAINER", "LEARNER");

        Permission viewPlatformDashboard = createPermissionIfNotFound("VIEW_PLATFORM_DASHBOARD", "View Platform Dashboard", "View platform dashboard", "Platform", "COURSE_MANAGER,ADMINISTRATOR", "LEARNER,TRAINER");
        Permission createManageExamsCm = createPermissionIfNotFound("CREATE_AND_MANAGE_EXAMS_CM", "Create & Manage Exams", "Create and manage exams as a course manager", "Course Management", "COURSE_MANAGER", "LEARNER");
        Permission viewRatingNotifications = createPermissionIfNotFound("VIEW_RATING_NOTIFICATIONS", "View Rating Notifications", "View low rating notifications", "Platform", "", "LEARNER");

        Permission manageAccountsRoles = createPermissionIfNotFound("MANAGE_ACCOUNTS_ROLES", "Manage Accounts & Roles", "Manage user accounts and roles", "System Settings", "ADMINISTRATOR", "LEARNER,TRAINER,COURSE_MANAGER");
        Permission moderateComments = createPermissionIfNotFound("MODERATE_COMMENTS", "Moderate Comments", "Moderate comments on the platform", "Platform", "ADMINISTRATOR", "LEARNER");
        Permission reviewTrainerApplications = createPermissionIfNotFound("REVIEW_TRAINER_APPLICATIONS", "Review Trainer Applications", "Review trainer applications", "System Settings", "ADMINISTRATOR", "LEARNER,TRAINER");
        Permission auditLogAiUsage = createPermissionIfNotFound("AUDIT_LOG_AI_USAGE", "Audit Log & AI Usage", "View audit log and AI usage stats", "System Settings", "ADMINISTRATOR", "LEARNER,TRAINER");

        // Assign to Roles if they don't have permissions yet
        assignPermissionsToRole("LEARNER", Set.of(learnCourses, attemptQuiz, rateAndComment, aiAssistant));
        assignPermissionsToRole("TRAINER", Set.of(manageOwnCourses, manageQuestionBank, createExamsTrainer, viewOwnRevenue));
        assignPermissionsToRole("COURSE_MANAGER", Set.of(viewPlatformDashboard, createManageExamsCm, viewRatingNotifications));
        assignPermissionsToRole("ADMINISTRATOR", Set.of(manageAccountsRoles, moderateComments, reviewTrainerApplications, auditLogAiUsage));
    }

    private Permission createPermissionIfNotFound(String code, String name, String description, String module, String coreForRoles, String restrictedForRoles) {
        Optional<Permission> pOpt = permissionRepository.findByCode(code);
        if (pOpt.isPresent()) {
            Permission p = pOpt.get();
            boolean changed = false;
            if (p.getModule() == null || !p.getModule().equals(module)) {
                p.setModule(module);
                changed = true;
            }
            if (p.getCoreForRoles() == null || !p.getCoreForRoles().equals(coreForRoles)) {
                p.setCoreForRoles(coreForRoles);
                changed = true;
            }
            if (p.getRestrictedForRoles() == null || !p.getRestrictedForRoles().equals(restrictedForRoles)) {
                p.setRestrictedForRoles(restrictedForRoles);
                changed = true;
            }
            if (changed) {
                return permissionRepository.save(p);
            }
            return p;
        }
        Permission permission = Permission.builder()
                .code(code)
                .name(name)
                .description(description)
                .module(module)
                .coreForRoles(coreForRoles)
                .restrictedForRoles(restrictedForRoles)
                .build();
        return permissionRepository.save(permission);
    }

    private void assignPermissionsToRole(String roleName, Set<Permission> defaultPermissions) {
        Optional<Role> roleOpt = roleRepository.findByRoleName(roleName);
        if (roleOpt.isPresent()) {
            Role role = roleOpt.get();
            if (role.getPermissions() == null || role.getPermissions().isEmpty()) {
                role.setPermissions(new HashSet<>(defaultPermissions));
                roleRepository.save(role);
            }
        }
    }
}
