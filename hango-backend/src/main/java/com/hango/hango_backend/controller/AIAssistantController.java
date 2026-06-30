package com.hango.hango_backend.controller;

import com.hango.hango_backend.dto.AiHealthResponse;
import com.hango.hango_backend.dto.SendMessageRequest;
import com.hango.hango_backend.dto.SendMessageResponse;
import com.hango.hango_backend.entity.AIConversation;
import com.hango.hango_backend.sercurity.SecurityUtil;
import com.hango.hango_backend.service.AIAssistantService;
import com.hango.hango_backend.service.GeminiClientService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.web.bind.annotation.*;
import lombok.extern.slf4j.Slf4j;
import com.hango.hango_backend.repository.UserRepository;
import com.hango.hango_backend.entity.User;

import java.util.List;

@Slf4j
@RestController
@RequestMapping("/api/v1/ai-assistant")
@RequiredArgsConstructor
@CrossOrigin(origins = "http://localhost:3000", allowCredentials = "true") // ✨ THÊM DÒNG NÀY ĐỂ FIX LỖI CORS CHO
                                                                           // FLUTTER WEB
public class AIAssistantController {

    private final AIAssistantService aiAssistantService;
    private final GeminiClientService geminiClientService;
    private final UserRepository userRepository;

    /**
     * UC-31: gửi câu hỏi tới AI Assistant, giới hạn trong phạm vi 1 bài học cụ thể.
     */
    @PostMapping("/messages")
    public ResponseEntity<SendMessageResponse> sendMessage(@Valid @RequestBody SendMessageRequest request) {
        Long learnerId = getSafeUserId();
        return ResponseEntity.ok(aiAssistantService.sendMessage(learnerId, request));
    }

    /** Xem lại lịch sử các cuộc hội thoại với AI Assistant. */
    @GetMapping("/conversations")
    public ResponseEntity<List<AIConversation>> getConversations() {
        Long learnerId = getSafeUserId();
        return ResponseEntity.ok(aiAssistantService.getConversationHistory(learnerId));
    }

    @GetMapping("/status")
    public ResponseEntity<AiHealthResponse> getStatus() {
        return ResponseEntity.ok(geminiClientService.checkAvailability());
    }

    /**
     * Hàm helper lấy UserId từ Security Context một cách an toàn, tránh
     * ClassCastException
     */
    private Long getSafeUserId() {
        try {
            var authentication = SecurityContextHolder.getContext().getAuthentication();
            if (authentication == null || !authentication.isAuthenticated()) {
                return null;
            }

            Object principal = authentication.getPrincipal();
            if (principal == null) {
                return null;
            }

            // 1. Trường hợp principal là Object User của hệ thống
            if (principal instanceof com.hango.hango_backend.entity.User) {
                return ((com.hango.hango_backend.entity.User) principal).getId();
            }

            // 2. Trường hợp principal là Long thuần túy
            if (principal instanceof Long) {
                return (Long) principal;
            }

            // 3. Trường hợp principal là String (Có thể là ID chuỗi hoặc Email/Username)
            if (principal instanceof String) {
                String principalStr = (String) principal;
                if ("anonymousUser".equals(principalStr)) {
                    return null;
                }
                try {
                    // Thử parse xem có phải chuỗi ID số hay không
                    return Long.parseLong(principalStr);
                } catch (NumberFormatException e) {
                    // ✨ MẤU CHỐT: Nếu là Email/Username, tiến hành truy vấn DB để lấy ID chuẩn
                    return userRepository.findByEmail(principalStr)
                            .map(User::getId)
                            .orElse(null);
                }
            }

            // 4. Nếu principal là UserDetails custom của dự án, lấy trực tiếp id
            if (principal instanceof com.hango.hango_backend.sercurity.UserDetailsImpl) {
                return ((com.hango.hango_backend.sercurity.UserDetailsImpl) principal).getId();
            }

            // 5. Kiểm tra qua SecurityUtil
            Long fallbackId = SecurityUtil.getCurrentUserId();
            if (fallbackId != null) {
                return fallbackId;
            }

            // 6. Cứu cánh cuối cùng: Nếu principal là object lạ (UserDetails mặc định của
            // Spring), thử lấy username/email
            if (principal instanceof org.springframework.security.core.userdetails.UserDetails) {
                String email = ((org.springframework.security.core.userdetails.UserDetails) principal).getUsername();
                return userRepository.findByEmail(email).map(User::getId).orElse(null);
            }

        } catch (Exception e) {
            log.error("Không thể trích xuất Learner ID từ Security Context", e);
        }
        return null;
    }
}