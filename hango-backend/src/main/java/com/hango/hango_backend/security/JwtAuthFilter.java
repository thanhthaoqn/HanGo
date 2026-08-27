package com.hango.hango_backend.security;

import com.hango.hango_backend.util.JwtUtils;
import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.security.web.authentication.WebAuthenticationDetailsSource;
import org.springframework.util.StringUtils;
import org.springframework.web.filter.OncePerRequestFilter;

import java.io.IOException;

public class JwtAuthFilter extends OncePerRequestFilter {
    private static final Logger logger = LoggerFactory.getLogger(JwtAuthFilter.class);

    @Autowired
    private JwtUtils jwtUtils;

    @Autowired
    private UserDetailsServiceImpl userDetailsService;

    // Filter nay chay 1 lan cho MOI request (OncePerRequestFilter), duoc dang ky
    // truoc UsernamePasswordAuthenticationFilter trong SecurityConfig.filterChain().
    // Day la noi DUY NHAT giai ma JWT va dua user hien tai vao SecurityContext,
    // de @PreAuthorize/@AuthenticationPrincipal o cac Controller phia sau dung duoc.
    @Override
    protected void doFilterInternal(HttpServletRequest request, HttpServletResponse response, FilterChain filterChain)
            throws ServletException, IOException {
        try {
            // B1: Lay chuoi token tu header "Authorization: Bearer <token>"
            String jwt = parseJwt(request);
            if (jwt != null && jwtUtils.validateJwtToken(jwt)) {
                // B2: Token hop le -> lay email (subject) da ky trong token
                String username = jwtUtils.getUserNameFromJwtToken(jwt);

                // B3: Query lai User tu DB de lay Role/Permission MOI NHAT (khong tin
                // tuong role cu trong token cu, vi Admin co the da doi quyen)
                UserDetails userDetails = userDetailsService.loadUserByUsername(username);
                UsernamePasswordAuthenticationToken authentication = new UsernamePasswordAuthenticationToken(
                        userDetails, null, userDetails.getAuthorities());
                authentication.setDetails(new WebAuthenticationDetailsSource().buildDetails(request));

                // B4: Ghi authentication vao SecurityContext cua request nay
                // -> tu day @PreAuthorize("hasRole(...)") va SecurityUtil.getCurrentUserId()
                // moi hoat dong duoc cho request hien tai.
                SecurityContextHolder.getContext().setAuthentication(authentication);
            }
            // Neu jwt null hoac khong hop le: KHONG throw loi o day, chi bo qua.
            // Request se di tiep xuong duoi voi trang thai "chua dang nhap" (anonymous).
            // Viec chan 401/403 duoc quyet dinh sau, boi SecurityConfig.authorizeHttpRequests
            // va @PreAuthorize tren tung endpoint.
        } catch (Exception e) {
            logger.error("Cannot set user authentication: {}", e);
        }

        filterChain.doFilter(request, response);
    }

    // Chi chap nhan dung 1 dinh dang: header "Authorization: Bearer <jwt>"
    private String parseJwt(HttpServletRequest request) {
        String headerAuth = request.getHeader("Authorization");

        if (StringUtils.hasText(headerAuth) && headerAuth.startsWith("Bearer ")) {
            return headerAuth.substring(7);
        }

        return null;
    }
}
