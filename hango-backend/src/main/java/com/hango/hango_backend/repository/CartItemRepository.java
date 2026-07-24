package com.hango.hango_backend.repository;

import com.hango.hango_backend.entity.CartItem;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.stereotype.Repository;

import java.util.List;

@Repository
public interface CartItemRepository extends JpaRepository<CartItem, Long> {

    List<CartItem> findByUserIdOrderByCreatedAtDesc(Long userId);

    boolean existsByUserIdAndCourseId(Long userId, Long courseId);

    @Modifying
    void deleteByUserIdAndCourseId(Long userId, Long courseId);

    @Modifying
    void deleteByUserId(Long userId);
}
