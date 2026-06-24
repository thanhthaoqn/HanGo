package com.hango.hango_backend.sercurity;

import org.springframework.security.core.context.SecurityContextHolder;
import lombok.extern.slf4j.Slf4j;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.userdetails.UserDetails;


@Slf4j
public class SecurityUtil {

    private SecurityUtil() {}

    /**
     * Lấy userId của người dùng hiện tại từ JWT đã được JwtAuthFilter xác thực.
     * Hỗ trợ ép kiểu từ Long, String, Custom User Entity và Spring Security UserDetails.
     */
    public static Long getCurrentUserId() {
        Authentication authentication = SecurityContextHolder.getContext().getAuthentication();
        if (authentication == null || !authentication.isAuthenticated()) {
            return null;
        }

        Object principal = authentication.getPrincipal();
        if (principal == null) {
            return null;
        }
        
        // 1. Trường hợp 1: Nếu principal chính là Object User Entity của bạn
        if (principal instanceof com.hango.hango_backend.entity.User) {
            return ((com.hango.hango_backend.entity.User) principal).getId();
        }

        // 2. Trường hợp 2: Nếu principal là một Custom UserDetails (Ví dụ bạn đặt tên là UserPrincipal)
        // Bạn hãy kiểm tra xem class UserDetails của bạn có hàm getId() hoặc tương tự không nhé
        // if (principal instanceof UserPrincipal) {
        //     return ((UserPrincipal) principal).getId();
        // }
        
        // 3. Trường hợp 3: Nếu principal đã là kiểu Long sẵn
        if (principal instanceof Long) {
            return (Long) principal;
        } 
        
        // 4. Trường hợp 4: Nếu principal là String (ID chuỗi hoặc Username)
        if (principal instanceof String) {
            String principalStr = (String) principal;
            if ("anonymousUser".equals(principalStr)) {
                return null;
            }
            try {
                return Long.valueOf(principalStr);
            } catch (NumberFormatException e) {
                return null; 
            }
        }
        
        return null;
    }
}