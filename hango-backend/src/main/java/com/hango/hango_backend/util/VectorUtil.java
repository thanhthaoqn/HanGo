package com.hango.hango_backend.util;

import com.fasterxml.jackson.core.type.TypeReference;
import com.fasterxml.jackson.databind.ObjectMapper;

import java.util.List;
import java.util.stream.Collectors;

/**
 * Tiện ích xử lý vector embedding.
 *
 * Vì MySQL (bản chuẩn) không có kiểu vector + hàm cosine similarity native,
 * ta lưu embedding dưới dạng JSON text (mảng float) trong cột TEXT/LONGTEXT,
 * và tính cosine similarity ở tầng Java khi cần so sánh (xem ScopeGuardrailService).
 *
 * Với quy mô vài trăm-vài nghìn lesson, việc tính ở application layer là đủ nhanh
 * (mỗi vector ~768 chiều, phép tính dot-product chỉ tốn micro-giây).
 */
public class VectorUtil {

    private static final ObjectMapper MAPPER = new ObjectMapper();

    private VectorUtil() {}

    public static String toJson(List<Double> vector) {
        try {
            return MAPPER.writeValueAsString(vector);
        } catch (Exception e) {
            throw new RuntimeException("Không thể serialize embedding vector", e);
        }
    }

    public static List<Double> fromJson(String json) {
        try {
            return MAPPER.readValue(json, new TypeReference<List<Double>>() {});
        } catch (Exception e) {
            throw new RuntimeException("Không thể parse embedding vector từ DB", e);
        }
    }

    /**
     * Tính cosine similarity giữa 2 vector, trả về giá trị trong khoảng [-1, 1].
     * Giá trị càng gần 1 nghĩa là 2 đoạn văn bản càng liên quan về ngữ nghĩa.
     */
    public static double cosineSimilarity(List<Double> a, List<Double> b) {
        if (a.size() != b.size()) {
            throw new IllegalArgumentException("Hai vector phải cùng số chiều để so sánh");
        }

        double dotProduct = 0.0;
        double normA = 0.0;
        double normB = 0.0;

        for (int i = 0; i < a.size(); i++) {
            dotProduct += a.get(i) * b.get(i);
            normA += a.get(i) * a.get(i);
            normB += b.get(i) * b.get(i);
        }

        if (normA == 0 || normB == 0) return 0.0;

        return dotProduct / (Math.sqrt(normA) * Math.sqrt(normB));
    }
}