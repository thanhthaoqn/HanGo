package com.hango.hango_backend.security;

import com.fasterxml.jackson.annotation.JsonIgnore;
import com.hango.hango_backend.entity.User;
import org.springframework.security.core.GrantedAuthority;
import org.springframework.security.core.authority.SimpleGrantedAuthority;
import org.springframework.security.core.userdetails.UserDetails;

import java.util.Collection;
import java.util.List;
import java.util.Objects;
import java.util.stream.Collectors;

public class UserDetailsImpl implements UserDetails {
    private static final long serialVersionUID = 1L;

    private Long id;
    private String email;
    private String fullName;

    @JsonIgnore
    private String password;

    private Collection<? extends GrantedAuthority> authorities;

    public UserDetailsImpl(Long id, String email, String fullName, String password,
                           Collection<? extends GrantedAuthority> authorities) {
        this.id = id;
        this.email = email;
        this.fullName = fullName;
        this.password = password;
        this.authorities = authorities;
    }

    // Day la noi CHUYEN DOI tu du lieu Role/Permission trong DB sang danh sach
    // GrantedAuthority ma Spring Security hieu duoc. Ham nay duoc goi lai o MOI
    // request (trong JwtAuthFilter/UserDetailsServiceImpl) nen luon phan anh
    // dung quyen moi nhat cua user, khong bi "cu" theo token.
    public static UserDetailsImpl build(User user) {
        List<GrantedAuthority> authoritiesList = new java.util.ArrayList<>();
        if (user.getRoles() != null) {
            user.getRoles().forEach(role -> {
                String r = role.getRoleName() != null ? role.getRoleName().trim() : "";
                if (!r.isEmpty()) {
                    // Them CA 2 dang: "ADMINISTRATOR" (dung cho hasAuthority)
                    // va "ROLE_ADMINISTRATOR" (dung cho hasRole - Spring tu them tiep dau ROLE_)
                    String cleanRole = r.startsWith("ROLE_") ? r.substring(5) : r;
                    authoritiesList.add(new SimpleGrantedAuthority(cleanRole));
                    authoritiesList.add(new SimpleGrantedAuthority("ROLE_" + cleanRole));
                }
                // Cac permission le (vd: MANAGE_OWN_COURSES, MANAGE_ACCOUNTS_ROLES...)
                // gan cho Role trong bang role_permissions cung duoc coi la authority
                // -> day chinh la co che RBAC dong: doi permission cua 1 Role trong
                // AdminController.updateRolePermissions() se anh huong ngay lan
                // dang nhap/refresh token tiep theo cua moi user co role do.
                if (role.getPermissions() != null) {
                    role.getPermissions().forEach(permission -> {
                        if (permission.getCode() != null && !permission.getCode().isEmpty()) {
                            authoritiesList.add(new SimpleGrantedAuthority(permission.getCode()));
                        }
                    });
                }
            });
        }
        List<GrantedAuthority> authorities = authoritiesList.stream().distinct().collect(Collectors.toList());

        return new UserDetailsImpl(
                user.getId(),
                user.getEmail(),
                user.getFullName(),
                user.getPasswordHash(),
                authorities);
    }


    @Override
    public Collection<? extends GrantedAuthority> getAuthorities() {
        return authorities;
    }

    public Long getId() {
        return id;
    }

    public String getFullName() {
        return fullName;
    }

    @Override
    public String getPassword() {
        return password;
    }

    @Override
    public String getUsername() {
        return email;
    }

    @Override
    public boolean isAccountNonExpired() {
        return true;
    }

    @Override
    public boolean isAccountNonLocked() {
        return true;
    }

    @Override
    public boolean isCredentialsNonExpired() {
        return true;
    }

    @Override
    public boolean isEnabled() {
        return true;
    }

    @Override
    public boolean equals(Object o) {
        if (this == o)
            return true;
        if (o == null || getClass() != o.getClass())
            return false;
        UserDetailsImpl user = (UserDetailsImpl) o;
        return Objects.equals(id, user.id);
    }
}
