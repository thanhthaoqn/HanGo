package com.hango.hango_backend.service;

import com.hango.hango_backend.dto.CourseSummaryDTO;
import com.hango.hango_backend.entity.CartItem;
import com.hango.hango_backend.entity.Course;
import com.hango.hango_backend.entity.SystemParameter;
import com.hango.hango_backend.entity.User;
import com.hango.hango_backend.repository.CartItemRepository;
import com.hango.hango_backend.repository.CourseRepository;
import com.hango.hango_backend.repository.EnrollmentRepository;
import com.hango.hango_backend.repository.UserRepository;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.math.BigDecimal;
import java.util.List;
import java.util.Optional;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class CartServiceImplTest {

    @Mock
    private CartItemRepository cartItemRepository;
    @Mock
    private CourseRepository courseRepository;
    @Mock
    private UserRepository userRepository;
    @Mock
    private EnrollmentRepository enrollmentRepository;

    @InjectMocks
    private CartServiceImpl cartService;

    private User user(Long id) {
        return User.builder().id(id).fullName("User " + id).build();
    }

    private Course course(Long id, String title) {
        return Course.builder().id(id).title(title).price(new BigDecimal("100000")).build();
    }

    // =================================================================
    // getCartItems
    // =================================================================

    @Test
    void getCartItemsShouldMapCartItemsToCourseSummaries() {
        CartItem item = CartItem.builder().course(course(1L, "Course A")).build();
        when(cartItemRepository.findByUserIdOrderByCreatedAtDesc(10L)).thenReturn(List.of(item));
        when(enrollmentRepository.findEnrolledCourseIds(10L, List.of(1L))).thenReturn(List.of());

        List<CourseSummaryDTO> result = cartService.getCartItems(10L);

        assertEquals(1, result.size());
        assertEquals("Course A", result.get(0).getTitle());
    }

    @Test
    void getCartItemsShouldSkipCoursesTheUserIsAlreadyEnrolledIn() {
        CartItem item = CartItem.builder().course(course(1L, "Course A")).build();
        when(cartItemRepository.findByUserIdOrderByCreatedAtDesc(10L)).thenReturn(List.of(item));
        when(enrollmentRepository.findEnrolledCourseIds(10L, List.of(1L))).thenReturn(List.of(1L));

        List<CourseSummaryDTO> result = cartService.getCartItems(10L);

        assertEquals(0, result.size());
    }

    @Test
    void getCartItemsShouldSkipCartItemsWithNoCourse() {
        CartItem item = CartItem.builder().course(null).build();
        when(cartItemRepository.findByUserIdOrderByCreatedAtDesc(10L)).thenReturn(List.of(item));

        List<CourseSummaryDTO> result = cartService.getCartItems(10L);

        assertEquals(0, result.size());
    }

    @Test
    void getCartItemsShouldPopulateCreatorNameAndDifficultyNameWhenPresent() {
        User creator = user(99L);
        Course course = Course.builder().id(1L).title("Course A").price(new BigDecimal("100000"))
                .creator(creator)
                .difficulty(SystemParameter.builder().paramValue("Beginner").build())
                .build();
        CartItem item = CartItem.builder().course(course).build();
        when(cartItemRepository.findByUserIdOrderByCreatedAtDesc(10L)).thenReturn(List.of(item));
        when(enrollmentRepository.findEnrolledCourseIds(10L, List.of(1L))).thenReturn(List.of());

        List<CourseSummaryDTO> result = cartService.getCartItems(10L);

        assertEquals("User 99", result.get(0).getCreatorName());
        assertEquals("Beginner", result.get(0).getDifficultyName());
    }

    // =================================================================
    // addItemToCart
    // =================================================================

    @Test
    void addItemToCartShouldThrowWhenUserNotFound() {
        when(userRepository.findById(10L)).thenReturn(Optional.empty());

        assertThrows(RuntimeException.class, () -> cartService.addItemToCart(10L, 1L));
    }

    @Test
    void addItemToCartShouldThrowWhenCourseNotFound() {
        when(userRepository.findById(10L)).thenReturn(Optional.of(user(10L)));
        when(courseRepository.findById(1L)).thenReturn(Optional.empty());

        assertThrows(RuntimeException.class, () -> cartService.addItemToCart(10L, 1L));
    }

    @Test
    void addItemToCartShouldThrowWhenUserAlreadyOwnsCourse() {
        when(userRepository.findById(10L)).thenReturn(Optional.of(user(10L)));
        when(courseRepository.findById(1L)).thenReturn(Optional.of(course(1L, "Course A")));
        when(enrollmentRepository.existsByUserIdAndCourseId(10L, 1L)).thenReturn(true);

        assertThrows(RuntimeException.class, () -> cartService.addItemToCart(10L, 1L));
        verify(cartItemRepository, never()).save(any());
    }

    @Test
    void addItemToCartShouldSaveWhenNotAlreadyInCart() {
        when(userRepository.findById(10L)).thenReturn(Optional.of(user(10L)));
        when(courseRepository.findById(1L)).thenReturn(Optional.of(course(1L, "Course A")));
        when(enrollmentRepository.existsByUserIdAndCourseId(10L, 1L)).thenReturn(false);
        when(cartItemRepository.existsByUserIdAndCourseId(10L, 1L)).thenReturn(false);

        cartService.addItemToCart(10L, 1L);

        verify(cartItemRepository).save(any(CartItem.class));
    }

    @Test
    void addItemToCartShouldNotDuplicateWhenAlreadyInCart() {
        when(userRepository.findById(10L)).thenReturn(Optional.of(user(10L)));
        when(courseRepository.findById(1L)).thenReturn(Optional.of(course(1L, "Course A")));
        when(enrollmentRepository.existsByUserIdAndCourseId(10L, 1L)).thenReturn(false);
        when(cartItemRepository.existsByUserIdAndCourseId(10L, 1L)).thenReturn(true);

        cartService.addItemToCart(10L, 1L);

        verify(cartItemRepository, never()).save(any());
    }

    // =================================================================
    // removeItemFromCart / clearCart
    // =================================================================

    @Test
    void removeItemFromCartShouldDelegateToRepository() {
        cartService.removeItemFromCart(10L, 1L);

        verify(cartItemRepository).deleteByUserIdAndCourseId(10L, 1L);
    }

    @Test
    void clearCartShouldDelegateToRepository() {
        cartService.clearCart(10L);

        verify(cartItemRepository).deleteByUserId(10L);
    }

    // =================================================================
    // syncCart
    // =================================================================

    @Test
    void syncCartShouldDoNothingWhenCourseIdsIsNullOrEmpty() {
        cartService.syncCart(10L, null);
        cartService.syncCart(10L, List.of());

        verify(userRepository, never()).findById(any());
    }

    @Test
    void syncCartShouldThrowWhenUserNotFound() {
        when(userRepository.findById(10L)).thenReturn(Optional.empty());

        assertThrows(RuntimeException.class, () -> cartService.syncCart(10L, List.of(1L)));
    }

    @Test
    void syncCartShouldAddCoursesNotYetEnrolledOrInCart() {
        when(userRepository.findById(10L)).thenReturn(Optional.of(user(10L)));
        when(enrollmentRepository.existsByUserIdAndCourseId(10L, 1L)).thenReturn(false);
        when(cartItemRepository.existsByUserIdAndCourseId(10L, 1L)).thenReturn(false);
        when(courseRepository.findById(1L)).thenReturn(Optional.of(course(1L, "Course A")));

        cartService.syncCart(10L, List.of(1L));

        verify(cartItemRepository).save(any(CartItem.class));
    }

    @Test
    void syncCartShouldSkipCoursesAlreadyEnrolled() {
        when(userRepository.findById(10L)).thenReturn(Optional.of(user(10L)));
        when(enrollmentRepository.existsByUserIdAndCourseId(10L, 1L)).thenReturn(true);

        cartService.syncCart(10L, List.of(1L));

        verify(cartItemRepository, never()).save(any());
    }

    @Test
    void syncCartShouldSkipCoursesAlreadyInCart() {
        when(userRepository.findById(10L)).thenReturn(Optional.of(user(10L)));
        when(enrollmentRepository.existsByUserIdAndCourseId(10L, 1L)).thenReturn(false);
        when(cartItemRepository.existsByUserIdAndCourseId(10L, 1L)).thenReturn(true);

        cartService.syncCart(10L, List.of(1L));

        verify(cartItemRepository, never()).save(any());
    }
}
