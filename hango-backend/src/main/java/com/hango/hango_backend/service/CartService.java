package com.hango.hango_backend.service;

import com.hango.hango_backend.dto.CourseSummaryDTO;

import java.util.List;

public interface CartService {
    List<CourseSummaryDTO> getCartItems(Long userId);

    void addItemToCart(Long userId, Long courseId);

    void removeItemFromCart(Long userId, Long courseId);

    void clearCart(Long userId);

    void syncCart(Long userId, List<Long> courseIds);
}
