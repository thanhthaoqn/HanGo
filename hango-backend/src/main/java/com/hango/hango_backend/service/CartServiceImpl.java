package com.hango.hango_backend.service;

import com.hango.hango_backend.dto.CourseSummaryDTO;
import com.hango.hango_backend.entity.CartItem;
import com.hango.hango_backend.entity.Course;
import com.hango.hango_backend.entity.User;
import com.hango.hango_backend.repository.CartItemRepository;
import com.hango.hango_backend.repository.CourseRepository;
import com.hango.hango_backend.repository.EnrollmentRepository;
import com.hango.hango_backend.repository.UserRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.ArrayList;
import java.util.HashSet;
import java.util.List;
import java.util.Set;
import java.util.stream.Collectors;

@Slf4j
@Service
@RequiredArgsConstructor
public class CartServiceImpl implements CartService {

    private final CartItemRepository cartItemRepository;
    private final CourseRepository courseRepository;
    private final UserRepository userRepository;
    private final EnrollmentRepository enrollmentRepository;

    @Override
    @Transactional(readOnly = true)
    public List<CourseSummaryDTO> getCartItems(Long userId) {
        List<CartItem> cartItems = cartItemRepository.findByUserIdOrderByCreatedAtDesc(userId);
        List<Long> courseIds = cartItems.stream()
                .map(CartItem::getCourse)
                .filter(course -> course != null && course.getId() != null)
                .map(Course::getId)
                .collect(Collectors.toList());
        List<Long> enrolledIds = courseIds.isEmpty()
                ? List.of()
                : enrollmentRepository.findEnrolledCourseIds(userId, courseIds);
        Set<Long> enrolledCourseIds = enrolledIds == null ? Set.of() : new HashSet<>(enrolledIds);
        List<CourseSummaryDTO> dtoList = new ArrayList<>();

        for (CartItem item : cartItems) {
            Course course = item.getCourse();
            if (course == null) continue;

            // Remove automatically from cart if user is already enrolled
            if (enrolledCourseIds.contains(course.getId())) {
                log.info("Skipping enrolled courseId={} for userId={} cart response", course.getId(), userId);
                continue;
            }

            String creatorName = "Unknown Trainer";
            try {
                if (course.getCreator() != null) {
                    creatorName = course.getCreator().getFullName();
                }
            } catch (Exception ignored) {}

            String difficultyName = "ALL";
            try {
                if (course.getDifficulty() != null) {
                    difficultyName = course.getDifficulty().getParamValue();
                }
            } catch (Exception ignored) {}

            CourseSummaryDTO dto = CourseSummaryDTO.builder()
                    .id(course.getId())
                    .title(course.getTitle())
                    .creatorName(creatorName)
                    .thumbnailUrl(course.getThumbnailUrl())
                    .price(course.getPrice())
                    .difficultyName(difficultyName)
                    .build();

            dtoList.add(dto);
        }

        return dtoList;
    }

    @Override
    @Transactional
    public void addItemToCart(Long userId, Long courseId) {
        User user = userRepository.findById(userId)
                .orElseThrow(() -> new RuntimeException("User not found"));

        Course course = courseRepository.findById(courseId)
                .orElseThrow(() -> new RuntimeException("Course not found"));

        boolean isEnrolled = enrollmentRepository.existsByUserIdAndCourseId(userId, courseId);
        if (isEnrolled) {
            throw new RuntimeException("Bạn đã sở hữu khóa học này.");
        }

        boolean existsInCart = cartItemRepository.existsByUserIdAndCourseId(userId, courseId);
        if (!existsInCart) {
            CartItem cartItem = CartItem.builder()
                    .user(user)
                    .course(course)
                    .build();
            cartItemRepository.save(cartItem);
            log.info("Added courseId={} to userId={} cart", courseId, userId);
        }
    }

    @Override
    @Transactional
    public void removeItemFromCart(Long userId, Long courseId) {
        cartItemRepository.deleteByUserIdAndCourseId(userId, courseId);
        log.info("Removed courseId={} from userId={} cart", courseId, userId);
    }

    @Override
    @Transactional
    public void clearCart(Long userId) {
        cartItemRepository.deleteByUserId(userId);
        log.info("Cleared cart for userId={}", userId);
    }

    @Override
    @Transactional
    public void syncCart(Long userId, List<Long> courseIds) {
        if (courseIds == null || courseIds.isEmpty()) return;

        User user = userRepository.findById(userId)
                .orElseThrow(() -> new RuntimeException("User not found"));

        for (Long cId : courseIds) {
            boolean isEnrolled = enrollmentRepository.existsByUserIdAndCourseId(userId, cId);
            boolean existsInCart = cartItemRepository.existsByUserIdAndCourseId(userId, cId);
            if (!isEnrolled && !existsInCart) {
                courseRepository.findById(cId).ifPresent(course -> {
                    CartItem cartItem = CartItem.builder()
                            .user(user)
                            .course(course)
                            .build();
                    cartItemRepository.save(cartItem);
                });
            }
        }
        log.info("Synced {} guest cart items to userId={} cart", courseIds.size(), userId);
    }
}
