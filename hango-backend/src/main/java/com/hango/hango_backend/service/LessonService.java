package com.hango.hango_backend.service;

import com.hango.hango_backend.dto.LessonDetailDTO;

import com.hango.hango_backend.dto.LessonQuizAttemptDTO;
import com.hango.hango_backend.dto.LessonQuizAttemptRequestDTO;
import java.util.List;

public interface LessonService {
    LessonDetailDTO getLessonDetail(Long lessonId, Long userId);
    List<LessonQuizAttemptDTO> getQuizAttempts(Long lessonId, Long userId);
    LessonQuizAttemptDTO saveQuizAttempt(Long lessonId, Long userId, LessonQuizAttemptRequestDTO request);
    void completeLesson(Long lessonId, Long userId, boolean isCompleted);
}
