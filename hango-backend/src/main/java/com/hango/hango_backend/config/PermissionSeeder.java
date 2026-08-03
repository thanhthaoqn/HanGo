package com.hango.hango_backend.config;

import com.hango.hango_backend.entity.Permission;
import com.hango.hango_backend.entity.Role;
import com.hango.hango_backend.repository.PermissionRepository;
import com.hango.hango_backend.repository.RoleRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.boot.CommandLineRunner;
import org.springframework.stereotype.Component;

import java.util.Optional;

@Component
@RequiredArgsConstructor
@Slf4j
public class PermissionSeeder implements CommandLineRunner {

    private final PermissionRepository permissionRepository;
    private final RoleRepository roleRepository;

    @Override
    public void run(String... args) throws Exception {
        log.info("Checking and seeding required permissions...");
        
        seedPermission("USE_AI_ASSISTANT", "Sử dụng AI Assistant", "AI", "LEARNER");
        seedPermission("REVIEW_COURSE", "Đánh giá khóa học", "Course Management", "LEARNER");
        
        log.info("Permission check completed.");
    }

    private void seedPermission(String code, String name, String module, String roles) {
        Optional<Permission> existing = permissionRepository.findByCode(code);
        if (existing.isEmpty()) {
            Permission permission = Permission.builder()
                    .code(code)
                    .name(name)
                    .module(module)
                    .coreForRoles(roles)
                    .description("Auto-generated permission for " + name)
                    .build();
            permissionRepository.save(permission);
            log.info("Created missing permission: {}", code);
            
            roleRepository.findByRoleName("LEARNER").ifPresent(role -> {
                // ĐỂ TEST LỖI 403: Tạm thời chúng ta sẽ KHÔNG cấp quyền này cho LEARNER
                // Nếu muốn hệ thống chạy bình thường, hãy uncomment dòng dưới:
                // role.getPermissions().add(permission);
                // roleRepository.save(role);
                log.info("Test mode: Skipping assignment of {} to LEARNER role to test 403 Forbidden", code);
            });
        } else {
            // NẾU QUYỀN ĐÃ TỒN TẠI TRONG DB: Ta sẽ xóa nó khỏi LEARNER để test
            roleRepository.findByRoleName("LEARNER").ifPresent(role -> {
                boolean removed = role.getPermissions().removeIf(p -> p.getCode().equals(code));
                if (removed) {
                    roleRepository.save(role);
                    log.info("Test mode: REMOVED permission {} from LEARNER role to test 403 Forbidden", code);
                }
            });
        }
    }
}
