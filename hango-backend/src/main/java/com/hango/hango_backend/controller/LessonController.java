package com.hango.hango_backend.controller;

import com.hango.hango_backend.dto.LessonDetailDTO;
import com.hango.hango_backend.dto.LessonDetailDTO;
import com.hango.hango_backend.dto.LessonQuizAttemptRequestDTO;
import com.hango.hango_backend.service.LessonService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import com.hango.hango_backend.security.UserDetailsImpl;
import com.hango.hango_backend.security.UserDetailsImpl;

@RestController
@RequestMapping("/api/v1/lessons")
@RequiredArgsConstructor
public class LessonController {

    private final LessonService lessonService;



    // Load noi dung 1 bai hoc (video/text/quiz) de hien thi tren trang hoc.
    // Endpoint nay KHONG bat buoc dang nhap (xem SecurityConfig: GET
    // /api/v1/lessons/** la permitAll) - neu currentUser null (khach chua login)
    // van tra ve noi dung, chi rieng "isCompleted" se luon la false.
    @GetMapping("/{id}")
    public ResponseEntity<LessonDetailDTO> getLessonDetail(
            @PathVariable Long id,
            @AuthenticationPrincipal UserDetailsImpl currentUser) {
        Long currentUserId = currentUser != null ? currentUser.getId() : null;
        return ResponseEntity.ok(lessonService.getLessonDetail(id, currentUserId));
    }

    // Danh dau bai hoc (khong phai quiz) la da hoc xong. Dung cho bai video/text -
    // hoc vien bam nut "Mark as completed" o cuoi bai. Voi bai quiz, viec nay
    // duoc lam TU DONG boi saveQuizAttempt() ben duoi khi nop bai dat diem.
    @PutMapping("/{id}/complete")
    public ResponseEntity<?> completeLesson(
            @PathVariable Long id,
            @AuthenticationPrincipal UserDetailsImpl currentUser,
            @RequestParam(required = false, defaultValue = "true") boolean completed) {
        if (currentUser == null) {
            return ResponseEntity.status(401).body("{\"error\": \"Unauthorized\"}");
        }
        lessonService.completeLesson(id, currentUser.getId(), completed);
        return ResponseEntity.ok().body("{\"message\": \"Lesson progress updated successfully\"}");
    }

    // Lay lich su cac lan lam quiz cua CHINH user dang dang nhap cho 1 bai hoc
    // (de hien thi lai ket qua cac lan lam truoc, hoac xem lai dap an da chon).
    @GetMapping("/{id}/quiz-attempts")
    public ResponseEntity<?> getQuizAttempts(
            @PathVariable Long id,
            @AuthenticationPrincipal UserDetailsImpl currentUser) {
        if (currentUser == null) {
            return ResponseEntity.status(401).body("{\"error\": \"Unauthorized\"}");
        }
        return ResponseEntity.ok(lessonService.getQuizAttempts(id, currentUser.getId()));
    }

    // Nop bai quiz. request.score la diem Frontend tu tinh de hien thi ngay
    // (UX), nhung Backend KHONG tin diem nay - LessonServiceImpl.saveQuizAttempt
    // se CHAM LAI tu dap an dung trong DB (computeServerSideScore) roi moi luu,
    // chi fallback ve diem Frontend gui khi khong tim thay du lieu de cham lai.
    @PostMapping("/{id}/quiz-attempts")
    public ResponseEntity<?> saveQuizAttempt(
            @PathVariable Long id,
            @AuthenticationPrincipal UserDetailsImpl currentUser,
            @RequestBody LessonQuizAttemptRequestDTO request) {
        if (currentUser == null) {
            return ResponseEntity.status(401).body("{\"error\": \"Unauthorized\"}");
        }
        return ResponseEntity.ok(lessonService.saveQuizAttempt(id, currentUser.getId(), request));
    }
}
