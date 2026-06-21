package com.hango.hango_backend.service;

import com.hango.hango_backend.dto.LessonDetailDTO;

public interface LessonService {
    LessonDetailDTO getLessonDetail(Long lessonId);
}
