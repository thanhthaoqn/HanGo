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
        Permission learnCourses = createPermissionIfNotFound("ENROLL_AND_LEARN_COURSES", "Enroll & Learn Courses", "Ability to enroll in and learn courses");
        Permission attemptQuiz = createPermissionIfNotFound("ATTEMPT_QUIZ_AND_EXAM", "Attempt Quiz & Exam", "Ability to attempt quizzes and exams");
        Permission rateAndComment = createPermissionIfNotFound("RATE_AND_COMMENT", "Rate Courses & Comment", "Ability to rate courses and comment");
        Permission aiAssistant = createPermissionIfNotFound("AI_LEARNING_ASSISTANT", "AI Learning Assistant", "Access to AI learning assistant");

        Permission manageOwnCourses = createPermissionIfNotFound("MANAGE_OWN_COURSES", "Create & Manage Own Courses", "Create and manage own courses");
        Permission manageQuestionBank = createPermissionIfNotFound("MANAGE_QUESTION_BANK", "Manage Question Bank", "Manage own question bank");
        Permission createExamsTrainer = createPermissionIfNotFound("CREATE_EXAMS_TRAINER", "Create Exams", "Create exams as a trainer");
        Permission viewOwnRevenue = createPermissionIfNotFound("VIEW_OWN_REVENUE", "View Own Revenue", "View own revenue statistics");

        Permission viewPlatformDashboard = createPermissionIfNotFound("VIEW_PLATFORM_DASHBOARD", "View Platform Dashboard", "View platform dashboard");
        Permission createManageExamsCm = createPermissionIfNotFound("CREATE_AND_MANAGE_EXAMS_CM", "Create & Manage Exams", "Create and manage exams as a course manager");
        Permission viewRatingNotifications = createPermissionIfNotFound("VIEW_RATING_NOTIFICATIONS", "View Rating Notifications", "View low rating notifications");

        Permission manageAccountsRoles = createPermissionIfNotFound("MANAGE_ACCOUNTS_ROLES", "Manage Accounts & Roles", "Manage user accounts and roles");
        Permission moderateComments = createPermissionIfNotFound("MODERATE_COMMENTS", "Moderate Comments", "Moderate comments on the platform");
        Permission reviewTrainerApplications = createPermissionIfNotFound("REVIEW_TRAINER_APPLICATIONS", "Review Trainer Applications", "Review trainer applications");
        Permission auditLogAiUsage = createPermissionIfNotFound("AUDIT_LOG_AI_USAGE", "Audit Log & AI Usage", "View audit log and AI usage stats");

        // Assign to Roles if they don't have permissions yet
        assignPermissionsToRole("LEARNER", Set.of(learnCourses, attemptQuiz, rateAndComment, aiAssistant));
        assignPermissionsToRole("TRAINER", Set.of(manageOwnCourses, manageQuestionBank, createExamsTrainer, viewOwnRevenue));
        assignPermissionsToRole("COURSE_MANAGER", Set.of(viewPlatformDashboard, createManageExamsCm, viewRatingNotifications));
        assignPermissionsToRole("ADMINISTRATOR", Set.of(manageAccountsRoles, moderateComments, reviewTrainerApplications, auditLogAiUsage));
    }

    private Permission createPermissionIfNotFound(String code, String name, String description) {
        Optional<Permission> pOpt = permissionRepository.findByCode(code);
        if (pOpt.isPresent()) {
            return pOpt.get();
        }
        Permission permission = Permission.builder()
                .code(code)
                .name(name)
                .description(description)
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
