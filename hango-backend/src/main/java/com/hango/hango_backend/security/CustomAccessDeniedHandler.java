package com.hango.hango_backend.security;

import com.fasterxml.jackson.databind.ObjectMapper;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import org.springframework.http.HttpStatus;
import org.springframework.security.access.AccessDeniedException;
import org.springframework.security.web.access.AccessDeniedHandler;
import org.springframework.stereotype.Component;

import java.io.IOException;
import java.time.LocalDateTime;

@Component
public class CustomAccessDeniedHandler implements AccessDeniedHandler {

    @Override
    public void handle(HttpServletRequest request, HttpServletResponse response, AccessDeniedException accessDeniedException) throws IOException, ServletException {
        response.setContentType("application/json;charset=UTF-8");
        response.setStatus(HttpServletResponse.SC_FORBIDDEN);

        java.util.Map<String, Object> responseData = new java.util.HashMap<>();
        responseData.put("timestamp", LocalDateTime.now().toString());
        responseData.put("status", HttpStatus.FORBIDDEN.value());
        responseData.put("error", HttpStatus.FORBIDDEN.getReasonPhrase());
        responseData.put("message", "Access denied. You do not have permission to use this function or it has been deactivated by an administrator.");
        responseData.put("path", request.getRequestURI());

        ObjectMapper mapper = new ObjectMapper();
        response.getWriter().write(mapper.writeValueAsString(responseData));
    }
}
