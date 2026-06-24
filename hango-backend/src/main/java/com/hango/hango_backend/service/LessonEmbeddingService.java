package com.hango.hango_backend.service;

import com.hango.hango_backend.entity.Lesson;
import com.hango.hango_backend.repository.LessonRepository;
import com.hango.hango_backend.util.VectorUtil;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;

import java.util.List;

/**
 * Quản lý embedding vector của Lesson.contentText.
 *
 * Chiến lược cache: embedding được tính 1 LẦN khi bài học được tạo/sửa nội dung,
 * rồi lưu vào cột Lesson.contentEmbedding (JSON text). Khi learner chat, ta KHÔNG
 * tính lại embedding của bài học mỗi lần - chỉ tính embedding của câu hỏi learner gửi,
 * rồi so sánh với embedding đã cache. Điều này giảm đáng kể số lần gọi Gemini API.
 */
@Service
@RequiredArgsConstructor
public class LessonEmbeddingService {

    private final LessonRepository lessonRepository;
    private final GeminiClientService geminiClientService;

    /**
     * Đảm bảo Lesson đã có embedding hợp lệ. Nếu chưa có (bài học mới hoặc chưa từng tính)
     * thì gọi Gemini để tính và lưu lại. Trả về vector để dùng ngay.
     */
    public List<Double> getOrComputeEmbedding(Lesson lesson) {
        if (lesson.getContentEmbedding() != null && !lesson.getContentEmbedding().isBlank()) {
            return VectorUtil.fromJson(lesson.getContentEmbedding());
        }
        return recomputeEmbedding(lesson);
    }

    /** Gọi khi nội dung bài học (contentText) được tạo mới hoặc cập nhật. */
    public List<Double> recomputeEmbedding(Lesson lesson) {
        List<Double> vector = geminiClientService.generateEmbedding(lesson.getContentText());
        lesson.setContentEmbedding(VectorUtil.toJson(vector));
        lessonRepository.save(lesson);
        return vector;
    }
}